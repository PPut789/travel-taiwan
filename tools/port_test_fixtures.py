"""Translate synthetic test fixture content and partial notification assertions."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / 'test'
mapping = {
    'มีคลิปใหม่ในเชียงใหม่': 'New videos in Taipei City',
    'อัปเดตกระบี่': 'Kaohsiung City updated',
    'มีคลิปใหม่': 'New videos', 'มีการอัปเดต': 'updated',
    'เชียงใหม่': 'Taipei City', 'กระบี่': 'Kaohsiung City',
    'ดอยอินทนนท์': '陽明山', 'สถานที่แนะนำ': '推薦景點', 'สถานที่': '景點',
    'นักเดินทางชื่อยาวทดสอบหน้าจอเล็ก': 'Traveler with a long display name',
    'นักเดินทาง': 'Traveler', 'เCloseรายการ': 'Open list', 'เCloseสถานที่': 'Open attraction',
    'เดิม': 'original', 'ข้อมูลใหม่': 'updated content', 'ใหม่': 'new',
    'คลิปแก้ไข': 'edited video', 'คลิปใหม่': 'new video', 'แก้ไข': 'edited',
    'ไม่ได้Choose destinationsนี้': 'Destination not selected',
    'MountainsและNatureที่สวยงาม': '山景與自然風光',
    '景點สำหรับการท่องเที่ยวและRelaxation': '適合旅遊及休閒的景點',
}
for path in root.glob('*.dart'):
    text = path.read_text(encoding='utf-8')
    for before, after in sorted(mapping.items(), key=lambda p: -len(p[0])):
        text = text.replace(before, after)
    path.write_text(text, encoding='utf-8')
