# Tour Travel V2.3 recommendation API

This service adapts the separately trained Google Colab V2.3 bundle. It performs
inference only. The model is an experimental 60-feature binary rule-match KNN;
its probability is not a public star rating or a probability of user satisfaction.
The previous TF-IDF/row-index artifact format is no longer accepted.

## Contract

POST /recommend accepts only:
- preferred_cities_en: optional list; [] searches the available ready catalog.
- preferred_categories_en, preferred_types_en, preferred_activities_en: nonempty
  lists of exact option labels from the model export.
- age: positive integer, and gender: Female, Male or Other.
- limit: integer 1–10 (default 10).

No region, history keywords, row-index exclusions or location expansion is used.
The verified runtime applies the fitted feature transform, hard filters and ranking.
A valid search can return fewer than ten results or none.

Response: modelVersion, methodStatus, total, eligiblePool, limit, warnings and
results in model order. Each result contains canonical attractionId, rank,
knnRuleProbability, hasRealRating, avgRating and reviewCount. Unknown ratings/counts
are null. Flutter maps attractionId to Place.id/documentId, never sourceRow.
Age outside the train range is accepted with an age_out_of_training_range warning.

GET /health returns model_not_configured when no path is configured. POST then
returns 503. Invalid request shapes return 422; unknown option labels return 400.
A configured but unverifiable export fails startup rather than loading another model.

## Trusted export and Python environment

Use only the fresh Colab V2.3 export whose model hash was verified independently.
Keep these three original files in the same export directory:
- taiwan_knn_v2_3_bundle.pkl
- v23_runtime.py
- run_receipt.json

Set both TAIWAN_MODEL_PATH (explicit; there is no automatic model discovery) and
TAIWAN_MODEL_SHA256 (the known model SHA-256 from the verified export).
Before runtime import or pickle load, the service compares model/runtime hashes
against the receipt and the known hash, checks execution_environment=Google Colab,
Python major/minor, and exact NumPy/Pandas/scikit-learn/SciPy/joblib/threadpoolctl
versions against the receipt. Training never runs in this service.

Create an isolated Python 3.13 environment:

    uv venv backend/.venv --python 3.13
    uv pip install --python backend/.venv/Scripts/python.exe -r backend/requirements.txt

NumPy 2.1.3, Pandas 2.2.3 and sklearn 1.6.1 are pinned. Match any additional versions
to the actual new Colab receipt before startup. Python patch versions may differ
within 3.13; the service rejects a different major/minor version.

PowerShell, from the app root, after the new export is verified:

    $env:TAIWAN_MODEL_PATH = '<absolute-path-to-verified-export>\taiwan_knn_v2_3_bundle.pkl'
    $env:TAIWAN_MODEL_SHA256 = '<verified-64-character-model-hash>'
    $env:TAIWAN_API_HOST = '0.0.0.0'
    $env:TAIWAN_API_PORT = '8010'
    & backend/.venv/Scripts/python.exe backend/main.py

Default bind is 127.0.0.1:8010. Do not use the old Thai backend port or its artifact.

## Android device development

Use the computer's reachable Wi-Fi address in the app build flag:

    flutter run -d <android-device-id> --dart-define=RECOMMENDATION_API_URL=http://<computer-lan-ip>:8010

The phone and PC must be on the same reachable LAN. Recheck the PC address when
networks change. The Android debug manifest permits local HTTP; the release
manifest retains platform HTTPS defaults. This task does not deploy a public API
or change Windows firewall rules.

For a USB-connected device, adb reverse tcp:8010 tcp:8010 allows a debug app using
http://127.0.0.1:8010 to reach this PC, without exposing the service over Wi-Fi.

## Verification without model loading

    uv pip install --python backend/.venv/Scripts/python.exe httpx
    backend/.venv/Scripts/python.exe -m unittest discover -s backend -p test_api.py -v
    flutter test --no-pub test/recommendation_repository_test.dart

Backend contract tests use stub inference and deliberately invalid non-pickle bytes
for manifest checks. They never fit or deserialize a model. The Flutter tests
check the actual HTTP request contract, exact canonical ordering, unknown/duplicate
IDs, city restrictions, errors and genuine empty results.
