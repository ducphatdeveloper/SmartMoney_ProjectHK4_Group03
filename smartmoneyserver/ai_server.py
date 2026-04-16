"""
SmartMoney AI Server - FastAPI
Cung cấp OCR và KYC services cho Spring Boot backend
"""

import os
import re
import io
import base64
from typing import List, Optional
from datetime import datetime

# Tối ưu cho CPU đời 4 trên M4800
os.environ['FLAGS_use_onednn'] = '1'
os.environ['KMP_DUPLICATE_LIB_OK'] = 'True'
os.environ['OMP_NUM_THREADS'] = '4'  # Giới hạn thread để tránh lag

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from paddleocr import PaddleOCR
import uvicorn

# Khởi tạo FastAPI app
app = FastAPI(
    title="SmartMoney AI Server",
    description="OCR và KYC services cho ứng dụng quản lý tài chính",
    version="1.0.0"
)

# CORS cho phép Spring Boot gọi
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Trong production nên giới hạn origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Khởi tạo PaddleOCR một lần (singleton)
print("⏳ Đang khởi tạo PaddleOCR (lần đầu hơi lâu)...")
ocr_engine = PaddleOCR(
    use_angle_cls=True,
    lang='vi',
    use_gpu=False,
    ocr_version='PP-OCRv4',
    show_log=False  # Tắt log debug để console sạch
)
print("✅ PaddleOCR đã sẵn sàng!")


# ============ DATA MODELS ============

class OCRNumberDetail(BaseModel):
    raw: str
    clean: int
    conf: float


class OCRResponse(BaseModel):
    success: bool
    message: str
    full_text: str
    numbers_meta: List[OCRNumberDetail]
    dates: List[str]
    total_estimate: int
    confidence_avg: float
    processing_time_ms: int


class ErrorResponse(BaseModel):
    success: bool
    message: str
    error_detail: Optional[str] = None


# ============ OCR LOGIC ============

def extract_receipt_data(ocr_result) -> dict:
    """Trích xuất dữ liệu từ OCR raw text"""
    full_text_list = []
    all_numbers_detail = []
    dates = []
    confidences = []
    
    if not ocr_result or not ocr_result[0]:
        return None

    for line in ocr_result[0]:
        text_line = line[1][0]
        confidence = line[1][1]
        full_text_list.append(text_line)
        confidences.append(confidence)

        # Nhặt ngày tháng
        date_matches = re.findall(r'\d{1,2}/\d{1,2}/\d{4}', text_line)
        dates.extend(date_matches)

        # Nhặt số (>= 4 chữ số)
        num_matches = re.findall(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?', text_line)
        for num in num_matches:
            clean_val = re.sub(r'[.,]', '', num)
            if len(clean_val) >= 4 and clean_val.isdigit():
                all_numbers_detail.append({
                    "raw": num,
                    "clean": int(clean_val),
                    "conf": round(confidence, 2)
                })

    # Tính confidence trung bình
    avg_conf = round(sum(confidences) / len(confidences), 2) if confidences else 0
    
    # Lấy số lớn nhất làm tổng tiền dự kiến
    temp_amounts = [n["clean"] for n in all_numbers_detail]
    total = max(temp_amounts) if temp_amounts else 0
    
    return {
        "full_text": "\n".join(full_text_list),
        "numbers_meta": all_numbers_detail,
        "dates": list(set(dates)),
        "total_estimate": total,
        "confidence_avg": avg_conf
    }


# ============ API ENDPOINTS ============

@app.get("/")
def root():
    """Health check endpoint"""
    return {
        "service": "SmartMoney AI Server",
        "version": "1.0.0",
        "status": "running",
        "ocr_ready": True
    }


@app.get("/health")
def health_check():
    """Health check cho Spring Boot"""
    return {"status": "UP", "timestamp": datetime.now().isoformat()}


@app.post("/ocr", response_model=OCRResponse)
async def ocr_endpoint(image: UploadFile = File(...)):
    """
    Endpoint nhận ảnh hóa đơn, trả về dữ liệu OCR đã trích xuất
    
    - **image**: File ảnh (jpg, png, jpeg)
    - Returns: Full text, số tiền, ngày tháng, confidence
    """
    import time
    start_time = time.time()
    
    # Validate file type
    allowed_types = ['image/jpeg', 'image/png', 'image/jpg', 'image/webp']
    if image.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Chỉ chấp nhận file ảnh: {allowed_types}"
        )
    
    try:
        # Đọc file ảnh
        contents = await image.read()
        
        if len(contents) > 10 * 1024 * 1024:  # Giới hạn 10MB
            raise HTTPException(status_code=400, detail="Ảnh quá lớn (tối đa 10MB)")
        
        # Lưu tạm vào memory để OCR xử lý
        img_bytes = io.BytesIO(contents)
        
        # Chạy OCR
        import numpy as np
        from PIL import Image
        
        img = Image.open(img_bytes)
        # Convert sang RGB nếu là RGBA hoặc mode khác
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        # Lưu tạm để PaddleOCR đọc (Windows temp)
        import tempfile
        temp_path = os.path.join(tempfile.gettempdir(), f"ocr_temp_{datetime.now().strftime('%Y%m%d%H%M%S')}.jpg")
        img.save(temp_path, quality=85)
        
        # OCR
        result = ocr_engine.ocr(temp_path, cls=True)
        
        # Xóa file tạm
        if os.path.exists(temp_path):
            os.remove(temp_path)
        
        # Trích xuất dữ liệu
        data = extract_receipt_data(result)
        
        if not data:
            return OCRResponse(
                success=False,
                message="Không tìm thấy chữ trong ảnh",
                full_text="",
                numbers_meta=[],
                dates=[],
                total_estimate=0,
                confidence_avg=0,
                processing_time_ms=int((time.time() - start_time) * 1000)
            )
        
        processing_time = int((time.time() - start_time) * 1000)
        
        return OCRResponse(
            success=True,
            message="OCR thành công",
            full_text=data["full_text"],
            numbers_meta=[OCRNumberDetail(**n) for n in data["numbers_meta"]],
            dates=data["dates"],
            total_estimate=data["total_estimate"],
            confidence_avg=data["confidence_avg"],
            processing_time_ms=processing_time
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi OCR: {str(e)}")


@app.post("/ocr/base64", response_model=OCRResponse)
async def ocr_base64_endpoint(image_base64: str):
    """
    Endpoint nhận ảnh dạng base64 (dùng cho Flutter app)
    
    - **image_base64**: Chuỗi base64 của ảnh
    """
    import time
    start_time = time.time()
    
    try:
        # Decode base64
        image_data = base64.b64decode(image_base64)
        
        # Lưu tạm (Windows temp)
        import tempfile
        temp_path = os.path.join(tempfile.gettempdir(), f"ocr_base64_{datetime.now().strftime('%Y%m%d%H%M%S')}.jpg")
        with open(temp_path, 'wb') as f:
            f.write(image_data)
        
        # OCR
        result = ocr_engine.ocr(temp_path, cls=True)
        
        # Xóa file tạm
        if os.path.exists(temp_path):
            os.remove(temp_path)
        
        data = extract_receipt_data(result)
        processing_time = int((time.time() - start_time) * 1000)
        
        if not data:
            return OCRResponse(
                success=False,
                message="Không tìm thấy chữ trong ảnh",
                full_text="",
                numbers_meta=[],
                dates=[],
                total_estimate=0,
                confidence_avg=0,
                processing_time_ms=processing_time
            )
        
        return OCRResponse(
            success=True,
            message="OCR thành công",
            full_text=data["full_text"],
            numbers_meta=[OCRNumberDetail(**n) for n in data["numbers_meta"]],
            dates=data["dates"],
            total_estimate=data["total_estimate"],
            confidence_avg=data["confidence_avg"],
            processing_time_ms=processing_time
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi xử lý base64: {str(e)}")


# ============ MAIN ============

if __name__ == "__main__":
    print("🚀 Khởi động SmartMoney AI Server...")
    print("📍 URL: http://localhost:8000")
    print("📚 Docs: http://localhost:8000/docs")
    print("🔍 Health: http://localhost:8000/health")
    print("-" * 50)
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
