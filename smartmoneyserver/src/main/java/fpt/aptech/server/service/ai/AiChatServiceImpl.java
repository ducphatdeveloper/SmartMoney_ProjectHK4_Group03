package fpt.aptech.server.service.ai;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import fpt.aptech.server.dto.ai.AiChatRequest;
import fpt.aptech.server.dto.ai.AiChatResponse;
import fpt.aptech.server.dto.ai.AiExecuteRequest;
import fpt.aptech.server.dto.ai.ChatHistoryItem;
import fpt.aptech.server.dto.transaction.request.TransactionRequest;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.AIConversation;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Wallet;
import fpt.aptech.server.repos.AIConversationRepository;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.WalletRepository;
import fpt.aptech.server.service.transaction.TransactionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Triển khai module AI Chat — xử lý hội thoại với Gemini Flash Lite.
 *
 * Phương thức:
 * 1. chat()               — Nhận tin nhắn → gọi Gemini → lưu hội thoại → trả kết quả
 * 2. execute()            — Xác nhận hành động AI gợi ý → gọi TransactionService tạo giao dịch
 * 3. getHistory()         — Lấy lịch sử chat sắp xếp cũ → mới
 *
 * Phương thức phụ:
 * 4. buildSystemPrompt()  — Tạo system prompt chứa ví + danh mục của user
 * 5. buildConversationHistory() — Chuyển đổi entity → format Gemini
 * 6. parseGeminiResponse()      — Parse JSON phản hồi từ Gemini
 * 7. saveUserMessage()    — Lưu tin nhắn người dùng vào DB
 * 8. saveAiMessage()      — Lưu tin nhắn AI vào DB
 * 9. buildTransactionRequest()  — Map params → TransactionRequest
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AiChatServiceImpl implements AiChatService {

    private final GeminiService              geminiService;
    private final AIConversationRepository   aiConversationRepository;
    private final AccountRepository          accountRepository;
    private final WalletRepository           walletRepository;
    private final TransactionService         transactionService;
    private final ObjectMapper               objectMapper;

    // Số tin nhắn gần nhất lấy làm context cho Gemini (giữ nhỏ để tăng tốc)
    private static final int CONTEXT_MESSAGE_LIMIT = 4;

    // =================================================================================
    // 1. CHAT — Gửi tin nhắn → Gemini phân tích → Trả kết quả
    // =================================================================================

    /**
     * [1.1] Xử lý tin nhắn chat từ người dùng.
     * Bước 1 — Lấy thông tin User.
     * Bước 2 — Lưu tin nhắn người dùng vào DB.
     * Bước 3 — Xây dựng system prompt (chứa ví + danh mục).
     * Bước 4 — Lấy lịch sử hội thoại gần nhất.
     * Bước 5 — Gọi Gemini API.
     * Bước 6 — Parse phản hồi JSON.
     * Bước 7 — Lưu tin nhắn AI vào DB.
     * Bước 8 — Trả về AiChatResponse cho client.
     */
    @Override
    @Transactional
    public AiChatResponse chat(AiChatRequest request, Integer accountId) {
        // Bước 1: Lấy thông tin User
        Account currentUser = accountRepository.findById(accountId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại."));

        // Bước 2: Lưu tin nhắn người dùng vào DB (auto-commit)
        AIConversation userMessage = saveUserMessage(currentUser, request);

        // Bước 3: Xây dựng system prompt
        String systemPrompt = buildSystemPrompt(accountId);

        // Bước 4: Lấy lịch sử hội thoại gần nhất (bao gồm tin nhắn vừa lưu)
        List<Map<String, String>> conversationHistory = buildConversationHistory(accountId);

        // Bước 5: Gọi Gemini API
        String geminiRawResponse = geminiService.chat(systemPrompt, conversationHistory);
        log.info("Gemini raw response: {}", geminiRawResponse);

        // Bước 6: Parse phản hồi JSON từ Gemini
        Map<String, Object> parsedResponse = parseGeminiResponse(geminiRawResponse);

        // Bước 7: Lưu tin nhắn AI vào DB (auto-commit)
        String aiReplyText = (String) parsedResponse.getOrDefault("reply", "Tôi không hiểu yêu cầu của bạn.");
        Integer intent = parsedResponse.get("intent") != null
                ? ((Number) parsedResponse.get("intent")).intValue() : 4;

        AIConversation aiMessage = saveAiMessage(currentUser, aiReplyText, intent);

        // Bước 8: Nếu intent=1 (tạo giao dịch) + có action → TỰ ĐỘNG tạo giao dịch luôn
        AiChatResponse.AiAction action = null;
        if (parsedResponse.containsKey("action") && parsedResponse.get("action") != null) {
            @SuppressWarnings("unchecked")
            Map<String, Object> actionMap = (Map<String, Object>) parsedResponse.get("action");
            String actionType = (String) actionMap.get("type");

            @SuppressWarnings("unchecked")
            Map<String, Object> params = actionMap.get("params") instanceof Map
                    ? (Map<String, Object>) actionMap.get("params") : new HashMap<>();

            // 8.1 Lấy suggestions nếu có từ AI
            @SuppressWarnings("unchecked")
            List<String> suggestions = actionMap.containsKey("suggestions") 
                    ? (List<String>) actionMap.get("suggestions") : null;

            // Gắn aiChatId = ID tin nhắn AI
            params.put("aiChatId", aiMessage.getId());

            Boolean executed = false;
            String transactionError = null;
            
            // 8.2 Nếu là tạo giao dịch → thực thi ngay (Auto-commit)
            if ("create_transaction".equals(actionType) && intent != null && intent == 1) {
                try {
                    TransactionRequest txRequest = buildTransactionRequest(params);
                    TransactionResponse txResponse = transactionService.createTransaction(txRequest, accountId);

                    if (txResponse != null) {
                        log.info("AI tự động tạo giao dịch thành công: id={}", txResponse.id());
                        params.put("transactionId", txResponse.id());
                        executed = true;
                    }
                } catch (Exception e) {
                    log.error("AI tự động tạo giao dịch thất bại: {}", e.getMessage());
                    executed = false;
                    transactionError = e.getMessage();
                    params.put("error", transactionError);

                    // Cập nhật lại câu trả lời của AI với thông báo lỗi
                    aiReplyText = "⚠️ " + transactionError;
                    // Cập nhật lại tin nhắn AI đã lưu trong DB
                    aiMessage.setMessageContent(aiReplyText);
                    aiConversationRepository.save(aiMessage);
                }
            }

            action = AiChatResponse.AiAction.builder()
                    .type(actionType)
                    .executed(executed)
                    .params(params)
                    .suggestions(suggestions)
                    .build();
        }

        return AiChatResponse.builder()
                .conversationId(aiMessage.getId())
                .reply(aiReplyText)
                .intent(intent)
                .action(action)
                .build();
    }

    // =================================================================================
    // 2. EXECUTE — Xác nhận thực thi hành động AI gợi ý
    // =================================================================================

    /**
     * [2.1] Thực thi hành động sau khi user xác nhận.
     * Bước 1 — Kiểm tra actionType.
     * Bước 2 — Map params → TransactionRequest.
     * Bước 3 — Gọi TransactionService.createTransaction().
     */
    @Override
    @Transactional
    public Object execute(AiExecuteRequest request, Integer accountId) {
        // Bước 1: Kiểm tra loại hành động
        if (!"create_transaction".equals(request.actionType())) {
            throw new IllegalArgumentException(
                    "Hành động không được hỗ trợ: " + request.actionType()
                    + ". Hiện tại chỉ hỗ trợ: create_transaction");
        }

        // Bước 2: Map params → TransactionRequest
        TransactionRequest transactionRequest = buildTransactionRequest(request.params());

        // Bước 3: Gọi TransactionService để tạo giao dịch
        TransactionResponse response = transactionService.createTransaction(transactionRequest, accountId);

        return response;
    }

    // =================================================================================
    // 3. LỊCH SỬ CHAT
    // =================================================================================

    /**
     * [3.1] Lấy toàn bộ lịch sử chat của user, sắp xếp từ cũ → mới.
     */
    @Override
    @Transactional(readOnly = true)
    public List<ChatHistoryItem> getHistory(Integer accountId) {
        // 1. Lấy danh sách từ DB (đã sắp xếp DESC)
        List<AIConversation> conversations = aiConversationRepository
                .findByAccount_IdOrderByCreatedAtDesc(accountId);

        // 2. Đảo ngược → cũ trước, mới sau (hiển thị chat tự nhiên)
        List<AIConversation> reversed = new ArrayList<>(conversations);
        Collections.reverse(reversed);

        // 3. Map sang DTO
        return reversed.stream()
                .map(conv -> ChatHistoryItem.builder()
                        .id(conv.getId())
                        .messageContent(conv.getMessageContent())
                        .senderType(conv.getSenderType())
                        .intent(conv.getIntent())
                        .attachmentUrl(conv.getAttachmentUrl())
                        .attachmentType(conv.getAttachmentType())
                        .createdAt(conv.getCreatedAt())
                        .build())
                .collect(Collectors.toList());
    }

    // =================================================================================
    // 4. PHƯƠNG THỨC PHỤ — XÂY DỰNG PROMPT
    // =================================================================================

    /**
     * [4.1] Xây dựng system prompt cho Gemini.
     * Bao gồm: vai trò AI, danh sách ví + số dư, danh sách danh mục, format JSON phản hồi.
     */
    private String buildSystemPrompt(Integer accountId) {
        // 1. Lấy danh sách ví của user (chỉ tên + số dư, không chi tiết thừa)
        List<Wallet> wallets = walletRepository.findByAccountId(accountId);
        StringBuilder walletInfo = new StringBuilder();
        for (Wallet w : wallets) {
            walletInfo.append(String.format("  id:%d \"%s\" %s đ\n",
                    w.getId(), w.getWalletName(), w.getBalance().toPlainString()));
        }

        // 2. Lấy ngày hiện tại
        String today = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss"));

        return """
                Trợ lý tài chính SmartMoney. Giờ: %s
                
                VÍ CỦA BẠN (Tự chọn ví đầu tiên nếu người dùng không nói tên ví cụ thể):
                %s
                CATEGORY MAP (từ khóa → id):
                cafe, cà phê, trà, ăn sáng, ăn trưa, ăn tối, nhà hàng, cơm, bún, phở, trà sữa, bia, rượu, nước, quán ăn, trà đá → 1
                bảo hiểm → 2 | đầu tư, chứng khoán, cổ phiếu, vàng → 4
                xăng, đổ xăng, xe, taxi, grab, bus, tàu, máy bay, vé xe, gửi xe → 5 | gia đình → 6
                phim, rạp, game, du lịch, karaoke, giải trí, đi chơi, đá bóng, concert → 7 | học, sách, khóa học, học phí, bút, vở → 8
                điện, nước, gas, internet, điện thoại, wifi → 9 | mua, quần áo, giày, túi, shopping, cửa hàng, siêu thị, mall → 10
                quà, tặng, quyên góp, từ thiện, lì xì → 11 | bác sĩ, thuốc, khám, gym, thể dục, yoga, tây y, đông y → 12
                chuyển tiền → 13 | trả lãi → 14
                lương, thưởng → 15 | thu lãi → 16 | thu nhập khác → 17 | tiền chuyển đến → 18
                cho vay → 19 | đi vay → 20 | thu nợ → 21 | trả nợ → 22
                không rõ → 3
                
                LUẬT QUAN TRỌNG:
                1. Trả JSON hợp lệ, KHÔNG text ngoài JSON.
                2. TỰ ĐỘNG chọn categoryId theo từ khóa. KHÔNG HIỂN THỊ ID cho người dùng.
                3. Note: Chỉ lấy nội dung hành động chính (VD: "ăn sáng", "mua cafe"). KHÔNG tự thêm từ lạ (như "shopee").
                4. Tiền: nhận diện "k" hoặc "nghìn" là x1000, "tr" hoặc "triệu" là x1,000,000.
                5. reply: NGẮN GỌN, TRỰC TIẾP.
                   - Nếu tạo giao dịch: "Đã ghi nhận [Số tiền] vào [Tên danh mục] từ [Tên ví]".
                   - Nếu chat chung: Trả lời kiến thức tài chính ngắn gọn. KHÔNG GỢI Ý các tính năng chưa có (như Budget, Saving Goal).
                6. Nếu user hỏi dữ liệu lớn (1 năm, 100 giao dịch): Trả lời PHÂN TÍCH TÓM TẮT (tổng tiền, top danh mục, xu hướng) + hướng dẫn "Để xem chi tiết từng giao dịch, vui lòng xem phần Nhật ký trong ứng dụng".
                7. suggestions: Nếu người dùng chat quá chung chung (VD: "Tôi vừa tiêu tiền"), hãy gợi ý 3 mẫu thử để người dùng chọn: "Ăn sáng 30k", "Đổ xăng 50k", "Mua cafe 25k".
                8. intent: 1=giao dịch, 4=chat chung.
                
                TẠO GIAO DỊCH (Ví dụ):
                {"reply":"Đã ghi nhận 90,000đ vào Ăn uống từ Ví Tiền mặt","intent":1,"action":{"type":"create_transaction","params":{"categoryId":1,"walletId":1,"amount":90000,"note":"cafe","transDate":"%s","reportable":true},"suggestions":null}}
                
                GỢI Ý LỰA CHỌN (Ví dụ khi người dùng nói chung chung "Tôi vừa xài tiền"):
                {"reply":"Bạn đã chi tiêu vào việc gì thế?","intent":4,"action":{"type":"suggestion","params":null,"suggestions":["Ăn sáng 30k","Đổ xăng 50k","Mua cafe 25k"]},"action":null}
                
                CHAT CHUNG (Ví dụ):
                {"reply":"Để tiết kiệm, bạn nên ưu tiên quy tắc 50/30/20.","intent":4,"action":null}
                """.formatted(today, walletInfo.toString(), today);
    }

    /**
     * [4.2] Chuyển đổi lịch sử hội thoại từ DB sang format Gemini.
     * Gemini dùng role "user" và "model".
     */
    private List<Map<String, String>> buildConversationHistory(Integer accountId) {
        // 1. Lấy N tin nhắn gần nhất (DESC)
        List<AIConversation> recent = aiConversationRepository
                .findRecentByAccountId(accountId, CONTEXT_MESSAGE_LIMIT);

        // 2. Đảo ngược → cũ trước, mới sau
        List<AIConversation> chronological = new ArrayList<>(recent);
        Collections.reverse(chronological);

        // 3. Map sang format Gemini
        List<Map<String, String>> history = new ArrayList<>();
        for (AIConversation conv : chronological) {
            Map<String, String> msg = new HashMap<>();
            // senderType: false=User → "user", true=AI → "model"
            msg.put("role", Boolean.TRUE.equals(conv.getSenderType()) ? "model" : "user");
            msg.put("text", conv.getMessageContent());
            history.add(msg);
        }

        return history;
    }

    // =================================================================================
    // 5. PHƯƠNG THỨC PHỤ — PARSE & MAP
    // =================================================================================

    /**
     * [5.1] Parse JSON phản hồi từ Gemini.
     * Nếu parse thất bại → trả về response mặc định (general_chat).
     */
    private Map<String, Object> parseGeminiResponse(String rawResponse) {
        try {
            // 1. Thử parse trực tiếp
            return objectMapper.readValue(rawResponse, new TypeReference<Map<String, Object>>() {});
        } catch (Exception e) {
            log.warn("Không thể parse JSON từ Gemini, thử trích xuất JSON từ text...");

            // 2. Thử tìm JSON trong text (Gemini đôi khi wrap trong ```json ... ```)
            try {
                String cleaned = rawResponse;
                if (cleaned.contains("```json")) {
                    cleaned = cleaned.substring(cleaned.indexOf("```json") + 7);
                    cleaned = cleaned.substring(0, cleaned.indexOf("```"));
                } else if (cleaned.contains("{")) {
                    cleaned = cleaned.substring(cleaned.indexOf("{"));
                    cleaned = cleaned.substring(0, cleaned.lastIndexOf("}") + 1);
                }
                return objectMapper.readValue(cleaned.trim(), new TypeReference<Map<String, Object>>() {});
            } catch (Exception e2) {
                log.error("Parse Gemini response thất bại hoàn toàn: {}", rawResponse, e2);
                // 3. Trả về response mặc định
                Map<String, Object> fallback = new HashMap<>();
                fallback.put("reply", rawResponse); // Trả nguyên text cho user xem
                fallback.put("intent", 4);
                fallback.put("action", null);
                return fallback;
            }
        }
    }

    /**
     * [5.2] Map params từ AI → TransactionRequest.
     * Đọc từ Map<String, Object> → build record TransactionRequest.
     */
    private TransactionRequest buildTransactionRequest(Map<String, Object> params) {
        // 1. Đọc các field cơ bản
        Integer categoryId = getIntParam(params, "categoryId");
        Integer walletId = getIntParam(params, "walletId");
        Integer goalId = getIntParam(params, "goalId");
        BigDecimal amount = params.get("amount") != null
                ? new BigDecimal(params.get("amount").toString()) : null;
        String note = (String) params.get("note");
        Boolean reportable = params.get("reportable") != null
                ? Boolean.valueOf(params.get("reportable").toString()) : true;
        Integer eventId = getIntParam(params, "eventId");

        // 2. Đọc transDate (mặc định = now nếu null)
        LocalDateTime transDate = LocalDateTime.now();
        if (params.get("transDate") != null) {
            try {
                transDate = LocalDateTime.parse(params.get("transDate").toString());
            } catch (Exception e) {
                log.warn("Không thể parse transDate: {}, dùng thời gian hiện tại", params.get("transDate"));
            }
        }

        // 3. Đọc sourceType (mặc định = 2 CHAT)
        Integer sourceType = getIntParam(params, "sourceType");
        if (sourceType == null) sourceType = 2;

        // 4. Đọc aiChatId
        Integer aiChatId = getIntParam(params, "aiChatId");

        // 5. Đọc các field cho module nợ (nếu có)
        String personName = (String) params.get("personName");
        Integer debtId = getIntParam(params, "debtId");
        LocalDateTime dueDate = null;
        if (params.get("dueDate") != null) {
            try {
                dueDate = LocalDateTime.parse(params.get("dueDate").toString());
            } catch (Exception e) {
                log.warn("Không thể parse dueDate: {}", params.get("dueDate"));
            }
        }

        // 6. Build TransactionRequest
        return TransactionRequest.builder()
                .walletId(walletId)
                .goalId(goalId)
                .amount(amount)
                .categoryId(categoryId)
                .note(note)
                .transDate(transDate)
                .reportable(reportable)
                .eventId(eventId)
                .reminderDate(null)
                .withPerson(personName)
                .personName(personName)
                .debtId(debtId)
                .dueDate(dueDate)
                .sourceType(sourceType)
                .aiChatId(aiChatId)
                .build();
    }

    // =================================================================================
    // 6. PHƯƠNG THỨC PHỤ — LƯU TIN NHẮN
    // =================================================================================

    /**
     * [6.1] Lưu tin nhắn của người dùng vào DB.
     */
    private AIConversation saveUserMessage(Account account, AiChatRequest request) {
        AIConversation userMsg = AIConversation.builder()
                .account(account)
                .messageContent(request.message())
                .senderType(false)  // false = User gửi
                .intent(null)       // Chưa biết intent, để AI phân loại
                .attachmentType(request.attachmentType())
                .attachmentUrl(null)
                .build();
        return aiConversationRepository.save(userMsg);
    }

    /**
     * [6.2] Lưu tin nhắn phản hồi của AI vào DB.
     */
    private AIConversation saveAiMessage(Account account, String replyText, Integer intent) {
        AIConversation aiMsg = AIConversation.builder()
                .account(account)
                .messageContent(replyText)
                .senderType(true)   // true = AI phản hồi
                .intent(intent)
                .attachmentType(null)
                .attachmentUrl(null)
                .build();
        return aiConversationRepository.save(aiMsg);
    }

    // =================================================================================
    // 7. UTILITY
    // =================================================================================

    /**
     * [7.1] Đọc Integer an toàn từ Map (tránh ClassCastException).
     */
    private Integer getIntParam(Map<String, Object> params, String key) {
        Object value = params.get(key);
        if (value == null) return null;
        if (value instanceof Number) return ((Number) value).intValue();
        try {
            return Integer.parseInt(value.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }

}

