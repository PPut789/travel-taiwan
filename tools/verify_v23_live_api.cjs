// Inference-only HTTP verification. Never fits or deserializes a model here.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { normalizeAttractions } = require('./taiwan_dataset.cjs');

const exportDir = 'C:/flutter/Intern - Taiwan/research/taiwan_attractions_2026-10-15/KNN_InterestV2_3_Demographics_Ratings1352_2026-10-26/outputs';
const baseUrl = 'http://127.0.0.1:8010';
const read = name => JSON.parse(fs.readFileSync(path.join(exportDir, name), 'utf8'));
const receipt = read('run_receipt.json');
const fixtures = read('runtime_parity_fixtures.json');
const output = path.resolve('outputs/today-2026-10-26');
fs.mkdirSync(output, { recursive: true });

async function post(body, expectedStatus = 200) {
  const response = await fetch(baseUrl + '/recommend', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body), signal: AbortSignal.timeout(30000),
  });
  const result = await response.json();
  if (response.status !== expectedStatus) throw Error(`HTTP ${response.status}: ${JSON.stringify(result)}`);
  return result;
}

(async () => {
  const health = await (await fetch(baseUrl + '/health')).json();
  if (!health.ok || health.featureDimensions !== 60 || health.modelSha256 !== receipt.model_sha256) {
    throw Error('Wrong live model');
  }
  let passed = 0;
  for (const fixture of fixtures) {
    const result = await post({ ...fixture.profile, limit: 10 });
    const ids = result.results.map(r => r.attractionId);
    const probs = result.results.map(r => r.knnRuleProbability);
    if (JSON.stringify(ids) !== JSON.stringify(fixture.AttractionIDs) ||
        JSON.stringify(probs) !== JSON.stringify(fixture.knn_prob) ||
        result.eligiblePool !== fixture.eligible_pool) throw Error(`Fixture ${passed} mismatch`);
    passed++;
  }
  const profile = {
    preferred_cities_en: ['Taipei City'],
    preferred_categories_en: ['Nature and ecology'],
    preferred_types_en: ['Natural scenery'],
    preferred_activities_en: ['Photography', 'Scenic viewing'],
    age: 26, gender: 'Female', limit: 10,
  };
  const demo = await post(profile);
  const second = await post(profile);
  if (JSON.stringify(demo) !== JSON.stringify(second)) throw Error('Repeated identical search changed');
  const allCities = await post({ ...profile, preferred_cities_en: [] });
  const outOfRange = await post({ ...profile, age: 66 });
  if (!outOfRange.warnings.includes('age_out_of_training_range')) throw Error('OOD warning missing');
  await post({ ...profile, age: true }, 422);
  await post({ ...profile, gender: 'Unknown' }, 422);
  await post({ ...profile, preferred_types_en: ['Invented'] }, 400);

  const sourceBytes = fs.readFileSync('dataset/source/attractions.json');
  const sourceHash = crypto.createHash('sha256').update(sourceBytes).digest('hex');
  const records = JSON.parse(sourceBytes);
  const catalog = normalizeAttractions(records, sourceHash);
  const byId = new Map(catalog.map(p => [p.id, p]));
  const places = demo.results.map(r => {
    const place = byId.get(r.attractionId);
    if (!place || place.province !== 'Taipei City') throw Error('Canonical demo mapping failed');
    return place;
  });
  fs.writeFileSync(path.join(output, 'model-demo-api-response.json'), JSON.stringify(demo, null, 2));
  fs.writeFileSync('outputs/model-demo-results.json', JSON.stringify({
    preferences: { provinces: profile.preferred_cities_en, categories: profile.preferred_categories_en,
      types: profile.preferred_types_en, activities: profile.preferred_activities_en,
      age: profile.age, gender: profile.gender },
    places, model_provenance: { ...health, apiUrl: baseUrl, sourceDatasetSha256: sourceHash,
      kind: 'Actual HTTP inference using the fresh verified Colab model; synthetic demonstration profile' },
  }, null, 2));
  const verification = {
    status: 'PASSED', model: health, fixtureProfiles: passed,
    exactOrderedIdsProbabilitiesAndEligiblePoolsMatch: passed,
    repeatedRequestIdentical: true, optionalAllCitiesResults: allCities.total,
    optionalAllCitiesPool: allCities.eligiblePool, ageOutOfRangeFlagVerified: true,
    strictInputAndUnknownVocabularyVerified: true, demoResults: places.length,
    demoEligiblePool: demo.eligiblePool, demoAttractionIds: places.map(p => p.id),
    localFit: false, freshTrustedArtifactLoadedByBackendForInference: true,
    legacyPickleLoaded: false, finalReservedLoaded: false,
    actualAndroidDeviceTested: false,
  };
  fs.writeFileSync(path.join(output, 'live-api-verification.json'), JSON.stringify(verification, null, 2));
  console.log(JSON.stringify(verification, null, 2));
})().catch(error => { console.error(error); process.exitCode = 1; });
