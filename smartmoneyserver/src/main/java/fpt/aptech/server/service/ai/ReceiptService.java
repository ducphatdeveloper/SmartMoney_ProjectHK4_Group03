package fpt.aptech.server.service.ai;

import fpt.aptech.server.dto.ai.AiChatResponse;
import fpt.aptech.server.entity.Account;
import org.springframework.web.multipart.MultipartFile;

/**
 * [1] ReceiptService — Interface định nghĩa phương thức xử lý hóa đơn (OCR).
 * <p>
 * Chứa method phân tích ảnh hóa đơn để trích xuất thông tin giao dịch.
 */
public interface ReceiptService {

    /**
     * [1.1] Phân tích hóa đơn từ ảnh người dùng tải lên.
     * Upload ảnh lên Cloudinary, gọi Vision AI đọc thông tin, trích xuất số tiền, category, note.
     *
     * @param account Tài khoản người dùng
     * @param imageFile File ảnh hóa đơn
     * @param walletId ID ví (tùy chọn) để tạo giao dịch ngay
     * @return Phản hồi AI với thông tin hóa đơn đọc được và action xác nhận
     */
    AiChatResponse processReceipt(Account account, MultipartFile imageFile, Integer walletId);
}
