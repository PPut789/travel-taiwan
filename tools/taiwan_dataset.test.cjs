const { test } = require('node:test');
const assert = require('node:assert/strict');
const { normalizeAttractions, firestoreFields, interestCatalog } = require('./taiwan_dataset.cjs');

const row = {
  AttractionID: 'Attraction_example_1', AttractionName: '\u592a\u5e73\u5c71', Description: '\u68ee\u6797',
  PositionLat: 24.5, PositionLon: 121.5,
  Prepared: { city_en: 'Yilan County', interest_categories_en: ['Nature', 'Culture'], attraction_types_en: ['Forest'], activities_en: [] },
  Images: [{ URL: 'https://example.com/a.jpg', Description: 'Photographer credit' }, { URL: 'javascript:alert(1)' }],
};

test('preserves canonical IDs, Chinese and image attribution without invented activities/videos', () => {
  const value = normalizeAttractions([row], 'hash')[0];
  assert.equal(value.id, row.AttractionID);
  assert.equal(value.nameZhTw, row.AttractionName);
  assert.equal(value.province, 'Yilan County');
  assert.equal(value.category, 'Nature | Culture');
  assert.deepEqual(value.activities, []);
  assert.deepEqual(value.youtubeUrls, []);
  assert.deepEqual(value.images, ['https://example.com/a.jpg']);
  assert.equal(value.imageMetadata[0].description, 'Photographer credit');
  assert.equal(firestoreFields(value).latitude.doubleValue, 24.5);
});

test('rejects duplicate IDs, missing city and invalid coordinates', () => {
  assert.throws(() => normalizeAttractions([row, row], 'hash'), /duplicate/);
  assert.throws(() => normalizeAttractions([{ ...row, Prepared: {} }], 'hash'), /city/);
  assert.throws(() => normalizeAttractions([{ ...row, PositionLat: 100 }], 'hash'), /coordinates/);
});

test('checksum is repeatable and changes when source data changes', () => {
  const a = normalizeAttractions([row], 'hash')[0].importChecksum;
  assert.equal(a, normalizeAttractions([row], 'hash')[0].importChecksum);
  assert.notEqual(a, normalizeAttractions([{ ...row, Description: 'updated' }], 'hash')[0].importChecksum);
});

test('compact interest metadata uses the same dataset keys and removes unresolved Other', () => {
  const records = normalizeAttractions([row], 'hash');
  const metadata = interestCatalog([...records, {...records[0], categories: ['Other', 'Nature']}], 'hash');
  assert.deepEqual(metadata.categories, ['Culture', 'Nature']);
  assert.deepEqual(metadata.types, ['Forest']);
  assert.equal(metadata.recordCount, 2);
  assert.equal(metadata.sourceSha256, 'hash');
});
