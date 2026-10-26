# Start inference only. Training must remain on Google Colab.
$ErrorActionPreference='Stop'
$appRoot=Split-Path $PSScriptRoot -Parent
$modelFile=Join-Path $appRoot '..\Intern - Taiwan\research\taiwan_attractions_2026-10-15\KNN_InterestV2_3_Demographics_Ratings1352_2026-10-26\outputs\taiwan_knn_v2_3_bundle.pkl'
if(-not (Test-Path -LiteralPath $modelFile)){throw 'The verified V2.3 export is missing. Read PROJECT_HANDOFF_TH.txt.'}
$env:TAIWAN_MODEL_PATH=(Resolve-Path -LiteralPath $modelFile).Path
$env:TAIWAN_MODEL_SHA256='d403b9bc7a093cd6163f68cc318339695fd77da5a89e424468977494ccb37c12'
$env:TAIWAN_API_HOST='0.0.0.0'
$env:TAIWAN_API_PORT='8010'
Set-Location $appRoot
& (Join-Path $PSScriptRoot '.venv\Scripts\python.exe') (Join-Path $PSScriptRoot 'main.py')
