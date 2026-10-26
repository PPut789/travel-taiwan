"""Mechanical replacement of inherited native application identities."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
for name in ['ios/Runner.xcodeproj/project.pbxproj',
             'macos/Runner.xcodeproj/project.pbxproj',
             'macos/Runner/Configs/AppInfo.xcconfig', 'linux/CMakeLists.txt']:
    path = ROOT / name
    if path.exists():
        text = path.read_text(encoding='utf-8').replace('com.example.project', 'com.traveltaiwan.app')
        if name.endswith('AppInfo.xcconfig'):
            text = text.replace('PRODUCT_NAME = project', 'PRODUCT_NAME = TravelTaiwan')
        path.write_text(text, encoding='utf-8')
