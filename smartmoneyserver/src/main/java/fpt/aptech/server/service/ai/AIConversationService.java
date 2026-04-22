package fpt.aptech.server.service.ai;

import fpt.aptech.server.dto.ai.AiChatRequest;
import fpt.aptech.server.dto.ai.AiChatResponse;
import fpt.aptech.server.dto.ai.AiExecuteRequest;
import fpt.aptech.server.dto.ai.ChatHistoryItem;
import fpt.aptech.server.entity.Account;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

/**
 * [1] AIConversationService — Interface định nghĩa các phương thức xử lý AI Chat.
 * <p>
 * Chứa các method xử lý chat, upload ảnh, quản lý lịch sử trò chuyện, thực thi hành động.
 */
public interface AIConversationService {

    /**
     * [1.1] Xử lý tin nhắn chat từ người dùng.
     * Phân tích intent, gọi AI, trả về phản hồi phù hợp.
     *
     * @param account Tài khoản người dùng
     * @param request Request chứa tin nhắn và loại đính kèm
     * @return Phản hồi AI kèm thông tin intent, action nếu có
     */
    AiChatResponse chat(Account account, AiChatRequest request);

    /**
     * [1.2] Upload ảnh để AI phân tích (OCR) hoặc lưu ảnh thường.
     * Lưu ảnh lên Cloudinary, gọi Vision AI đọc thông tin.
     * Nếu không phải hóa đơn → chỉ lưu vào tAIConversations.attachment_url
     * Nếu là hóa đơn → lưu vào cả tReceipts.image_url và tAIConversations.attachment_url
     *
     * @param account Tài khoản người dùng
     * @param imageFile File ảnh
     * @param walletId ID ví (tùy chọn) để tạo giao dịch ngay
     * @return Phản hồi AI với thông tin hóa đơn đọc được hoặc thông báo lưu ảnh thành công
     */
    AiChatResponse uploadReceipt(Account account, MultipartFile imageFile, Integer walletId);

    /**
     * [1.3] Lấy lịch sử trò chuyện của người dùng (có phân trang).
     *
     * @param account Tài khoản người dùng
     * @param page Số trang (bắt đầu từ 0)
     * @param size Số lượng item mỗi trang
     * @return Danh sách lịch sử chat
     */
    List<ChatHistoryItem> getChatHistory(Account account, int page, int size);

    /**
     * [1.5] Xóa toàn bộ lịch sử trò chuyện của người dùng.
     *
     * @param account Tài khoản người dùng
     */
    void clearHistory(Account account);

    /**
     * [1.5.1] Xóa một cuộc trò chuyện riêng lẻ theo ID.
     *
     * @param conversationId ID cuộc trò chuyện
     * @param accountId ID tài khoản người dùng (để kiểm tra quyền sở hữu)
     */
    void deleteConversationById(Integer conversationId, Integer accountId);

    /**
     * [1.6] Thực thi hành động mà AI đề xuất (VD: tạo giao dịch).
     *
     * @param account Tài khoản người dùng
     * @param request Request chứa loại hành động và tham số
     * @return Phản hồi sau khi thực thi hành động
     */
    AiChatResponse executeAction(Account account, AiExecuteRequest request);
}
