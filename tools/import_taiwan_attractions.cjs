const fs = require('node:fs/promises');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { normalizeAttractions, firestoreFields, interestCatalog } = require('./taiwan_dataset.cjs');

const PROJECT = 'travel---taiwan';
const BASE = `projects/${PROJECT}/databases/(default)/documents`;

async function main() {
  const args = process.argv.slice(2);
  const sourceIndex = args.indexOf('--source');
  if (sourceIndex < 0 || !args[sourceIndex + 1]) throw new Error('Use --source <JSON file> [--apply].');
  const bytes = await fs.readFile(args[sourceIndex + 1]);
  const sourceSha256 = createHash('sha256').update(bytes).digest('hex');
  const records = normalizeAttractions(JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/, '')), sourceSha256);
  const report = {
    project: PROJECT, records: records.length, sourceSha256,
    cities: new Set(records.map(row => row.province)).size,
    images: records.reduce((count, row) => count + row.images.length, 0),
    missingActivities: records.filter(row => !row.activities.length).length,
    maximumDocumentBytes: Math.max(...records.map(row => Buffer.byteLength(JSON.stringify(firestoreFields(row))))),
  };
  if (report.maximumDocumentBytes > 900000) throw new Error('Document is too large.');
  await fs.mkdir(path.join(__dirname, '..', 'outputs'), { recursive: true });
  await fs.writeFile(path.join(__dirname, '..', 'outputs', 'taiwan-import-audit.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
  if (!args.includes('--apply')) { console.log('Dry run only; no cloud writes.'); return; }

  // Reuse the signed-in Firebase CLI session, never export keys or print tokens.
  const cliRoot = process.env.FIREBASE_TOOLS_DIR || path.join(process.env.APPDATA || '', 'npm', 'node_modules', 'firebase-tools');
  const auth = require(path.join(cliRoot, 'lib', 'auth.js'));
  const { requireAuth } = require(path.join(cliRoot, 'lib', 'requireAuth.js'));
  const { Client } = require(path.join(cliRoot, 'lib', 'apiv2.js'));
  const account = auth.getProjectDefaultAccount(process.cwd());
  if (!account) throw new Error('Run firebase login first.');
  await requireAuth({ ...account, project: PROJECT, nonInteractive: true });
  const client = new Client({ urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1' });
  async function publishMetadata() {
    const metadata = interestCatalog(records, sourceSha256);
    await client.post(`${BASE}:commit`, { writes: [{ update: {
      name: `${BASE}/catalog_metadata/attractions`, fields: firestoreFields(metadata),
    } }] });
    const readback = await client.get(`${BASE}/catalog_metadata/attractions`);
    if (readback.body.fields?.sourceSha256?.stringValue !== sourceSha256) throw new Error('Metadata verification failed.');
    console.log(`Interest metadata published and read back: ${Buffer.byteLength(JSON.stringify(metadata))} bytes; ${metadata.categories.length}/${metadata.types.length}/${metadata.activities.length} choices.`);
  }
  if (args.includes('--metadata-only')) { await publishMetadata(); return; }
  const existing = new Map();
  let pageToken;
  do {
    const response = await client.get(`${BASE}/attractions`, {
      queryParams: { pageSize: 1000, 'mask.fieldPaths': 'importChecksum', ...(pageToken ? { pageToken } : {}) },
    });
    for (const doc of response.body.documents ?? []) {
      existing.set(doc.name.split('/').pop(), doc.fields?.importChecksum?.stringValue ?? '');
    }
    pageToken = response.body.nextPageToken;
  } while (pageToken);
  // Check all conflicts before the first write; never overwrite manually edited data.
  for (const row of records) {
    if (existing.has(row.id) && existing.get(row.id) !== row.importChecksum) {
      throw new Error(`Existing document differs: ${row.id}. No overwrite is allowed.`);
    }
  }
  const pending = records.filter(row => !existing.has(row.id));
  for (let offset = 0; offset < pending.length; offset += 200) {
    const batch = pending.slice(offset, offset + 200);
    await client.post(`${BASE}:commit`, {
      writes: batch.map(row => ({
        update: { name: `${BASE}/attractions/${row.id}`, fields: firestoreFields(row) },
        currentDocument: { exists: false },
      })),
    });
    console.log(`Created ${Math.min(offset + 200, pending.length)}/${pending.length}; skipped ${records.length - pending.length}.`);
  }
  await publishMetadata();
  const verification = await client.post(`${BASE}:runAggregationQuery`, {
    structuredAggregationQuery: { structuredQuery: { from: [{ collectionId: 'attractions' }] }, aggregations: [{ alias: 'total', count: {} }] },
  });
  const cloudCount = Number(verification.body[0]?.result?.aggregateFields?.total?.integerValue);
  for (const row of [records[0], records[Math.floor(records.length / 2)], records.at(-1)]) {
    const response = await client.get(`${BASE}/attractions/${row.id}`);
    if (response.body.fields?.nameZhTw?.stringValue !== row.nameZhTw ||
        response.body.fields?.importChecksum?.stringValue !== row.importChecksum) {
      throw new Error(`Readback failed: ${row.id}`);
    }
  }
  report.created = pending.length;
  report.skipped = records.length - pending.length;
  report.cloudCount = cloudCount;
  report.verifiedSamples = 3;
  report.completedAt = new Date().toISOString();
  await fs.writeFile(path.join(__dirname, '..', 'outputs', 'taiwan-import-result.json'), JSON.stringify(report, null, 2));
  console.log(`Verified cloud count: ${cloudCount}; Chinese names/checksums read back successfully.`);
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
