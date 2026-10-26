# Taiwan dataset

The owner supplied the full Taiwan catalog on 2026-10-24. The unchanged source
snapshot is source/attractions.json (the original file had no extension).
Original: C:\Users\poomp\Downloads\Data\attractions.
SHA-256: dd2e1f1f31355174cbe7f273745483badd0c206eac5f065c02670a5452e0a120.
The app-facing subset was imported into Firebase project travel---taiwan on 2026-10-24.
Firestore attractions contains 6,023 documents, keyed by the original AttractionID.
Cloud count and three Chinese-name/checksum readback samples were verified.

## Initial source audit

- 6,023 records; 38 top-level fields; 6,023 unique nonempty AttractionID values.
- 22 city/county English keys match the app's city selector.
- Every record contains a Chinese name/description, valid-range coordinates
  and at least one HTTP(S) image URL; 10,501 image entries overall.
  Image links have not been downloaded or checked for availability.
- Prepared contains 11 category labels and 28 type labels, including Other in both.
  Other means unresolved classification; it should not be presented as a meaningful interest.
- 12 activity labels; 1,466 records have no activity annotation.
  Activity review methods: 3,707 direct_source_statement,164 prior_source_review,
  4,944 reasonable_inference. These are label counts, not attraction counts.
- 1,352 attractions have external aggregate ratings. These are not individual
  user preference labels and cannot by themselves measure Precision@10.
- 242 groups share the same exact stripped name and city. These are candidates
  for review, not proof that different AttractionIDs should be merged.
- Source reports ServiceStatus=1 and IsPublicAccess=1 for every record;
  this is not live verification that every attraction is currently open.
- Opening-time text is missing in4,485 records and fee text in5,553.
  Prepared supplements and restriction flags require separate review.
- Prepared.region_en is retained as source metadata only; the Taiwan app has
  city-only location preferences. Prepared.activities_th is not for English UI.

Keep original Chinese names and descriptions. UI labels and preference keys are English.
AttractionID is the canonical string ID for Firestore and future model results. Favorites,
history and videos use the same document ID. sourceRow is only an inherited compatibility
field; it is not a permanent identity and should not be used by the future Taiwan model.

The adapter is tools/taiwan_dataset.cjs; the safe dry-run/apply importer is
tools/import_taiwan_attractions.cjs. Place reads nameZhTw first, with a legacy nameTh
fallback for history compatibility. Choices derive from the imported English feature keys.
The source snapshot is unchanged. Missing activities/YouTube stay empty. Images remain
external URLs with original name/credit metadata, not files copied to Firebase Storage.
This import does not train, deploy or validate a recommendation model.
