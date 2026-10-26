// Cache the actual attraction URLs for deterministic UI screenshot rendering.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const demo = JSON.parse(fs.readFileSync('outputs/model-demo-results.json', 'utf8'));
const folder = 'outputs/today-2026-10-26/photo-fixtures';
fs.mkdirSync(folder, { recursive: true });
(async () => {
  const results = await Promise.allSettled(demo.places.map(async place => {
    for (const url of place.images ?? []) {
      try {
        const response = await fetch(url, {signal: AbortSignal.timeout(20000)});
        if (!response.ok || !response.headers.get('content-type')?.startsWith('image/')) continue;
        const bytes = Buffer.from(await response.arrayBuffer());
        const filename = `${place.id}.jpg`;
        fs.writeFileSync(path.join(folder, filename), bytes);
        return {attractionId:place.id,url,file:filename,bytes:bytes.length,
          sha256:crypto.createHash('sha256').update(bytes).digest('hex')};
      } catch (_) { /* Another supplied URL can be tried; no unrelated image. */ }
    }
    return {attractionId:place.id,status:'NO_RETRIEVABLE_SOURCE_IMAGE'};
  }));
  const rows = results.map((r,i) => r.status === 'fulfilled' ? r.value :
    {attractionId:demo.places[i].id,status:String(r.reason)});
  fs.writeFileSync(path.join(folder, 'manifest.json'), JSON.stringify(rows, null, 2));
  console.log(JSON.stringify({images:rows.filter(r=>r.file).length, total:rows.length}));
})().catch(error => { console.error(error); process.exitCode=1; });
