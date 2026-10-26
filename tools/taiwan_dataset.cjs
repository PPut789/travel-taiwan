const { createHash } = require('node:crypto');

function strings(values) {
  if (!Array.isArray(values)) return [];
  return [...new Set(values.filter(v => typeof v === 'string').map(v => v.trim()).filter(Boolean))];
}

function webUrl(value) {
  if (typeof value !== 'string') return '';
  try {
    const url = new URL(value.trim());
    return ['http:', 'https:'].includes(url.protocol) ? value.trim() : '';
  } catch { return ''; }
}

function normalizeAttractions(records, sourceSha256) {
  if (!Array.isArray(records) || !records.length) throw new Error('Expected a nonempty JSON array.');
  const seen = new Set();
  return records.map((row, index) => {
    const id = row.AttractionID;
    if (typeof id !== 'string' || !/^[A-Za-z0-9_-]+$/.test(id) || seen.has(id)) {
      throw new Error(`Invalid or duplicate AttractionID at row ${index + 1}.`);
    }
    seen.add(id);
    const prepared = row.Prepared ?? {};
    const name = row.AttractionName;
    const city = prepared.city_en;
    const latitude = row.PositionLat;
    const longitude = row.PositionLon;
    if (typeof name !== 'string' || !name.trim() || typeof city !== 'string' || !city.trim()) {
      throw new Error(`Missing name/city: ${id}`);
    }
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
        Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
      throw new Error(`Invalid coordinates: ${id}`);
    }
    const imageMetadata = (row.Images ?? []).filter(image => webUrl(image.URL)).map(image => ({
      url: webUrl(image.URL), name: image.Name ?? '', description: image.Description ?? '',
    }));
    const categories = strings(prepared.interest_categories_en);
    const types = strings(prepared.attraction_types_en);
    const activities = strings(prepared.activities_en);
    const data = {
      id, attractionId: id, sourceRow: index + 1,
      nameZhTw: name, nameEn: '', description: row.Description ?? '',
      province: city, cityZhTw: row.PostalAddress?.City ?? '',
      // Region remains descriptive metadata, never a selectable preference.
      region: prepared.region_en ?? '',
      category: categories.join(' | '), type: types.join(' | '), activity: activities.join(' | '),
      categories, types, activities,
      latitude, longitude, location: `${latitude}, ${longitude}`,
      images: strings(imageMetadata.map(image => image.url)), imageMetadata,
      assetImages: [], youtubeUrl: '', youtubeUrls: [], tiktokUrls: [], videoUrls: [],
      tags: strings([...categories, ...types, ...activities, ...strings(row.Tags)]),
      websiteUrl: webUrl(row.WebsiteURL),
      address: row.PostalAddress ?? {},
      sourceUpdateTime: row.UpdateTime ?? '',
      activityReviews: prepared.activity_reviews ?? [],
      qualityFlags: strings(prepared.quality_flags),
      sourceDatasetSha256: sourceSha256, importSchemaVersion: 'tour-travel-1',
    };
    const importChecksum = createHash('sha256').update(JSON.stringify(data)).digest('hex');
    return { ...data, importChecksum };
  });
}

function firestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (Array.isArray(value)) return { arrayValue: { values: value.map(firestoreValue) } };
  if (value && typeof value === 'object') return { mapValue: { fields: firestoreFields(value) } };
  throw new Error('Unsupported Firestore value.');
}

function firestoreFields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key, firestoreValue(value)]));
}

function interestCatalog(records, sourceSha256) {
  const labels = key => strings(records.flatMap(row => row[key])).filter(value => value !== 'Other').sort();
  return { sourceSha256, recordCount: records.length,
    categories: labels('categories'), types: labels('types'), activities: labels('activities') };
}

module.exports = { normalizeAttractions, firestoreFields, interestCatalog };
