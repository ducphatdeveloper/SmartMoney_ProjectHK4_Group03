package fpt.aptech.server.dto.ai;

import lombok.Builder;

import java.util.List;
import java.util.Map;

/**
 * [1] AiChatResponse — DTO chứa thông tin phản hồi từ AI trả về cho ứng dụng Flutter.
 * <p>
 * Lưu trữ nội dung trả lời, ID tin nhắn, danh sách hành động...
 */
@Builder
public record AiChatResponse(
        Integer conversationId,       // ID tin nhắn lưu dưới DB của AI
        String reply,                 // Văn bản AI trả lời cho người dùng
        Integer intent,              // Ý định của người dùng (1=add_transaction | 2=report_query | 3=set_budget | 4=general_chat | 5=remind_task)
        Long createdTransactionId,    // (Optional) Nếu AI tạo thành công Giao dịch
        Integer receiptId,            // (Optional) Nếu người dùng gửi kèm Hóa đơn để OCR
        AiAction action               // (Optional) Nếu AI cần chờ xác nhận thực thi
) {
    /**
     * [2] AiAction — DTO chứa dữ liệu hành động chờ xác nhận.
     */
    @Builder
    public record AiAction(
            String type,                   // "create_transaction" (Tạo giao dịch)
            Boolean executed,              // Trạng thái thực thi
            Map<String, Object> params,    // Thông tin chi tiết để gửi lại Server
            List<String> suggestions       // (Tùy chọn) Nút bấm gợi ý ["Có", "Không"]
    ) {}
}
