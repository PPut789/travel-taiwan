# รูปการ์ดเมือง

รูปจริง22ไฟล์จาก Dataset ต้นทางของผู้ใช้ ตัดกลางเป็น640x360 JPEG quality82 รวม 1315994 bytes. ชื่อไฟล์ตรงslugเมือง ใช้ใน lib/data/destination_photos.dart.

หากต้องการเปลี่ยนรูป: แทนไฟล์JPGเมืองนั้นด้วยรูปแนวนอนขนาด640x360ชื่อเดิม แล้วรันแอปใหม่. ควรแก้manifest.jsonให้ตรงแหล่งภาพใหม่และเครดิตด้วย. ชื่อเมือง/AttractionID/URL/Name/Descriptionต้นทางและhashรูปย่ออยู่ในmanifest.json. รูปที่ใช้เป็นภาพร่างการออกแบบที่ผู้ใช้อนุญาตให้เลือกก่อน ยังไม่ได้ตรวจสิทธิ์เผยแพร่ต่อทุกรูป.

ภาพรวม22เมือง: outputs/destination-contact-sheet.jpg. ภาพหน้ามือถือที่renderตรวจ: outputs/destination-mobile-preview.png. ไม่ได้แก้Datasetหรือย้ายcatalogรูปทั้งหมดไปStorage.
