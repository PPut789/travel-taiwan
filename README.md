# Tour Travel

Independent Flutter application forked from TravelThai at commit eea633d (UX / UI).
Repository: https://github.com/PPut789/travel-taiwan
The Taiwan project is maintained independently from the Thai application.

## Latest verified integration

The Android application connects to an inference-only Python backend using a model
trained on Google Colab. Users enter age and gender before selecting interests.
Recommendation results and ordering remain stable during navigation until a new
search is requested. See backend/README.md for the API contract and setup.

The model export, attraction dataset, local configuration, device screenshots and
private handoff notes are not distributed in this repository. Obtain the verified
export and authorized dataset separately. Backend startup requires the model,
runtime and receipt described in backend/README.md. No public API is deployed.
The Flutter web target is the user application; an admin website is not yet built.

## Current state

- English menus, forms, navigation, settings, notifications and errors.
- Original Chinese attraction names/descriptions will be kept when the full dataset is selected.
- Direct selection of one or more cities/counties from all 22 destinations; no regional preference.
- Login, registration, Google sign-in, interests, recommendations, place details/maps,
  favorites, history, profiles, video upload/feed and province notifications retain their source code.
- Web and Android connect to the dedicated Taiwan Firebase project `travel---taiwan`.
- Email/Password and Google providers are enabled. Firestore Standard is in `asia-east1` (Taiwan).
- Firestore rules are deployed: users can access only their own profile/history;
  signed-in clients can read attractions, but cannot modify the attraction catalog.
- Storage bucket travel---taiwan.firebasestorage.app is provisioned after the owner's plan upgrade.
  Storage rules are deployed: profile/video writes are owner-scoped; catalog media is admin-managed.
- No Thai Firebase configuration, dataset, trained model or recommendation endpoint is active.
- The full Taiwan source is in dataset/source/attractions.json (6,023 records, ignored by Git).
  All 6,023 records are imported into Firestore attractions using canonical AttractionID document IDs.
  Model recommendations use the configured Python API; local development setup is required.
- Existing scenic assets/app icons are temporary inherited artwork, not verified Taiwan location photos.
- The start/login/register headers render Tour Travel and English labels rather than Thai text embedded in images.
- The working folder and internal package remain travel-taiwan/travel_taiwan; the public app name is Tour Travel.

## Run

```powershell
cd C:\flutter\travel-taiwan
flutter pub get
flutter run -d chrome --no-pub --web-port 54124
```

Web/Android initialize the Taiwan Firebase app without additional build-time flags.
Actual account creation/sign-in still needs to be tested by the owner; no test account was created.
Interest choices/feed read the imported catalog. Names/descriptions remain Chinese; feature labels
and city selections use English. Blank source activities and missing YouTube links stay blank.
Interest choices use catalog_metadata/attractions (one small document, not a full catalog scan).
Home queries only selected cities and caches successful results per city selection. History is
optional and fetched concurrently; its failure must not prevent Home or Detail from opening.
Catalog requests time out after 15 seconds and failed requests can be retried without restarting.
Videos do not wait for the entire attraction catalog: linked places load by ID. Full catalog reads
remain available on demand for upload/edit search. Selecting all 22 cities can still be expensive.
Unsupported desktop/Apple platforms remain unconfigured; there is no fake sign-in.
On this computer pub get resolves packages but may fail while creating Windows plugin symlinks;
web can still run with --no-pub. Native desktop builds need Windows Developer Mode and C++ tooling.

## Firebase Configuration

Project: travel---taiwan (the owner upgraded billing). Public Google sign-in name: Tour Travel.
Web app: 1:1020915794188:web:82309fbd68f082f99c8929.
Android app: 1:1020915794188:android:bf7623e4eda437329c8929; package com.traveltaiwan.app.
The local debug certificate SHA-1 and SHA-256 are registered. Register production release/upload
certificates separately before distribution. localhost is already in Authorized domains.
Google Support email uses the owner's approved Firebase account email.
The ignored android/app/google-services.json includes the new OAuth clients.
No Apple app is registered. Configure Apple platforms separately when needed.

lib/firebase_options.dart has public platform-specific Firebase client settings. These are not
service-account credentials; Security Rules protect data. Never include admin keys in the app.
Optional config/firebase.example.json is a WEB override template, not an Android configuration.
For a local recommendation API, set RECOMMENDATION_API_URL to its actual URL. Local configs
matching config/*.local.json are ignored by Git. Do not reuse Thai project configuration.

```powershell
flutter run -d chrome --no-pub --web-port 54124 --dart-define-from-file=config/firebase.local.json
```

To redeploy only Firestore rules, use an explicit project:

```powershell
firebase deploy --only firestore:rules --project travel---taiwan
```

Storage rules can be deployed with firebase deploy --only storage --project travel---taiwan.
Image URLs already supplied by the dataset can be used without copying them into Firebase Storage.
The importer did not download/rehost images or videos. External image availability/CORS and native
profile/video uploads still require end-to-end checks with the owner's account/device.
GitHub repository: https://github.com/PPut789/travel-taiwan

## Dataset Import

```powershell
node --test tools/taiwan_dataset.test.cjs
node tools/import_taiwan_attractions.cjs --source dataset/source/attractions.json
node tools/import_taiwan_attractions.cjs --source dataset/source/attractions.json --apply
node tools/import_taiwan_attractions.cjs --source dataset/source/attractions.json --apply --metadata-only
```

Dry run is the default. Apply reuses the locally signed-in Firebase CLI without exporting tokens
or service-account keys. The CLI dependency is resolved from FIREBASE_TOOLS_DIR or the standard
Windows global npm installation. Target project is pinned to travel---taiwan.
Existing matching checksums are skipped; conflicting IDs stop the import, never overwrite.
Imports also publish derived interest metadata with source checksum and record count; metadata-only
updates that generated document without scanning or rewriting the 6,023 attraction documents.
Other is excluded from selectable interests because it denotes unresolved source classification.
Outputs/taiwan-import-result.json records cloud count and readback verification (ignored by Git).
The database stores normalized app fields, source quality/activity evidence and image credits;
the complete original dataset remains local. The compatibility sourceRow is not a permanent ID.
Place reads nameZhTw first and retains nameTh fallback only for inherited history compatibility.
Image URLs are stored, not proof that every image is currently reachable/licensed for redistribution.

## Full dataset/model integration checklist

1. Confirm redistribution rights and new model artifact/API format with the owner.
2. Dataset adapter and canonical Firestore IDs are in place. Adapt the old backend artifact format.
3. Train with the imported category/type/activity English keys; preference choices derive from the catalog.
4. Return canonical IDs from the model; connect history, videos, favorites and notifications consistently.
5. Test real login, profile/video uploads, favorites and history on the target device.
6. Evaluate the new model separately; this clone makes no Precision@10 or model-readiness claim.

## Git

This independent repository uses https://github.com/PPut789/travel-taiwan.git as origin.
The initial upload includes application/backend source and tests. Build outputs,
datasets, model binaries, private configuration and local handoff notes are ignored.
Firebase client configuration is public application metadata, not an admin credential;
Firestore and Storage Security Rules enforce data access.

## Interest icons and external images (2026-10-24)

Choose Interest maps all 49 current selectable catalog labels to relevant icons (10 categories, 27 types, 12 activities; source includes Other: 11/28/12). Attraction images use direct HTTP loading and prefer HTML image elements on Web for external hosts without CORS headers. Source image sizes, broken URLs and browser/host behavior still require live checks; no thumbnail service or rehosting was added. Audit: outputs/interest-image-audit-2026-10-24.json. Latest preview for this change: http://localhost:54128 (54127 is older). Flutter analyze and 54 tests passed.

## Destination photo cards (2026-10-24)

Choose your destination now shows all 22 cities/counties as photo cards (2 columns on mobile, 3–4 on larger screens), with blue selection borders/checks and multi-select. The 22 local JPEG thumbnails total 1,315,994 bytes. See assets/destinations/README_TH.md and manifest.json to replace images and preserve source credits. Original attraction data and cloud records were not changed. Location and visual tests passed (10 tests, widths320/390/1280, text100/200%).
