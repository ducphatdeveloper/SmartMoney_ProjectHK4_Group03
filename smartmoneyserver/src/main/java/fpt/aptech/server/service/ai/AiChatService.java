package fpt.aptech.server.service.ai;

import fpt.aptech.server.dto.ai.AiChatRequest;
import fpt.aptech.server.dto.ai.AiChatResponse;
import fpt.aptech.server.dto.ai.AiExecuteRequest;
import fpt.aptech.server.dto.ai.ChatHistoryItem;

import java.util.List;

/**
 * Interface cho module AI Chat.
 *
 * Phương thức:
 * 1. chat()       — Gửi tin nhắn người dùng → AI phân tích → trả kết quả + gợi ý hành động
 * 2. execute()    — Xác nhận thực thi hành động AI gợi ý (tạo giao dịch, ...)
 * 3. getHistory() — Lấy lịch sử chat của người dùng
 */
public interface AiChatService {

    // 1. Gửi tin nhắn chat → AI phân tích
    AiChatResponse chat(AiChatRequest request, Integer accountId);

    // 2. Xác nhận thực thi hành động
    Object execute(AiExecuteRequest request, Integer accountId);

    // 3. Lấy lịch sử chat
    List<ChatHistoryItem> getHistory(Integer accountId);
}

