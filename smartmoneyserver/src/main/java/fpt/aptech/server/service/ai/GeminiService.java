package fpt.aptech.server.service.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.github.resilience4j.retry.annotation.Retry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.client.WebClientResponseException;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Service gọi Google Gemini Flash Lite API qua WebClient.
 *
 * Phương thức:
 * 1. chat() — Gửi system prompt + lịch sử hội thoại → nhận phản hồi text từ Gemini.
 */
@Service
@Slf4j
public class GeminiService {

    private final WebClient webClient;
    private final List<String> apiKeys;
    private final ObjectMapper objectMapper;
    private int currentKeyIndex = 0;

    // 1. Constructor injection — Nhận vào danh sách Keys từ application.properties
    public GeminiService(WebClient.Builder webClientBuilder,
                         @Value("${gemini.api.keys}") String keysString) {
        this.webClient = webClientBuilder
                .baseUrl("https://generativelanguage.googleapis.com")
                .build();
        
        // Tách chuỗi keys thành List và lọc các khoảng trắng
        this.apiKeys = java.util.Arrays.stream(keysString.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(java.util.stream.Collectors.toList());
                
        this.objectMapper = new ObjectMapper();
        log.info("GeminiService initialized with {} API keys.", apiKeys.size());
    }

    /**
     * [1.0] Lấy API key hiện tại theo cơ chế xoay vòng (Round Robin).
     */
    private synchronized String getNextApiKey() {
        if (apiKeys.isEmpty()) {
            throw new IllegalStateException("Không có API Key nào được cấu hình.");
        }
        String key = apiKeys.get(currentKeyIndex);
        // Xoay chỉ số sang key tiếp theo cho lần gọi sau
        currentKeyIndex = (currentKeyIndex + 1) % apiKeys.size();
        return key;
    }

    // =================================================================================
    // 1. GỌI GEMINI API
    // =================================================================================

    /**
     * [1.1] Gửi tin nhắn đến Gemini và nhận phản hồi.
     * 
     * @param systemPrompt Hướng dẫn hệ thống (chứa danh sách ví, danh mục của user)
     * @param conversationHistory Lịch sử hội thoại [{role, text}]
     * @return Nội dung phản hồi text từ Gemini
     * @throws Exception nếu tất cả retry đều thất bại
     */
    @Retry(name = "gemini-chat", fallbackMethod = "chatFallback")
    public String chat(String systemPrompt, List<Map<String, String>> conversationHistory) {
        // Lấy Key xoay vòng
        String currentApiKey = getNextApiKey();
        
        // Bước 1: Xây dựng request body theo Gemini REST API format
        Map<String, Object> requestBody = buildRequestBody(systemPrompt, conversationHistory);

        try {
            // Bước 2: Gọi API với Key hiện tại
            String responseJson = webClient.post()
                    .uri("/v1beta/models/gemini-flash-lite-latest:generateContent?key=" + currentApiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .bodyValue(requestBody)
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();

            // Bước 3: Trích xuất text từ response
            return extractTextFromResponse(responseJson);
        } catch (WebClientResponseException e) {
            // 4. Re-throw WebClientResponseException để Retry mechanism bắt được
            log.warn("Gemini API HTTP error (Key index {}): {} {}", currentKeyIndex, e.getStatusCode(), e.getStatusText());
            throw e;
        }
    }

    /**
     * [1.2] Fallback method khi retry hết được.
     * Trả về response mặc định để tránh lỗi hoàn toàn.
     */
    private String chatFallback(String systemPrompt, List<Map<String, String>> conversationHistory, Throwable t) {
        log.error("Gemini API fallback triggered after retries. Error: {}", t.getMessage());
        
        // Trả về lỗi chi tiết hơn thay vì câu trả lời chung chung
        if (t instanceof org.springframework.web.reactive.function.client.WebClientResponseException.TooManyRequests) {
            return "{\"reply\":\"Hệ thống AI đang quá tải (Rate Limit). Vui lòng đợi khoảng 1 phút rồi thử lại.\",\"intent\":4}";
        }
        return "{\"reply\":\"Xin lỗi, hiện tại tôi không thể kết nối với trí tuệ nhân tạo. Lỗi: " + t.getMessage() + "\",\"intent\":4}";
    }

    // =================================================================================
    // 2. PHƯƠNG THỨC PHỤ (PRIVATE HELPERS)
    // =================================================================================

    /**
     * [2.1] Xây dựng request body cho Gemini API.
     * Format: { system_instruction: {...}, contents: [{role, parts}], generationConfig: {...} }
     */
    private Map<String, Object> buildRequestBody(String systemPrompt,
                                                  List<Map<String, String>> conversationHistory) {
        Map<String, Object> body = new HashMap<>();

        // 1. System instruction
        Map<String, Object> systemInstruction = new HashMap<>();
        systemInstruction.put("parts", List.of(Map.of("text", systemPrompt)));
        body.put("system_instruction", systemInstruction);

        // 2. Contents (lịch sử hội thoại)
        List<Map<String, Object>> contents = new ArrayList<>();
        for (Map<String, String> msg : conversationHistory) {
            Map<String, Object> content = new HashMap<>();
            content.put("role", msg.get("role")); // "user" hoặc "model"
            content.put("parts", List.of(Map.of("text", msg.get("text"))));
            contents.add(content);
        }
        body.put("contents", contents);

        // 3. Generation config — tối ưu hóa tối đa cho tốc độ và tiết kiệm
        Map<String, Object> genConfig = new HashMap<>();
        genConfig.put("temperature", 0.0);        // 0.0 giúp AI không bay bổng, trả lời ngay
        genConfig.put("topP", 0.1);               // Giới hạn không gian lấy mẫu
        genConfig.put("topK", 1);                 // Chỉ lấy token tốt nhất
        genConfig.put("maxOutputTokens", 512);    // Đủ cho mọi tính năng: CRUD, báo cáo quý, gợi ý chi tiết
        genConfig.put("responseMimeType", "application/json"); 
        body.put("generationConfig", genConfig);

        return body;
    }

    /**
     * [2.2] Trích xuất text từ Gemini API response.
     * Path: candidates[0].content.parts[0].text
     * Nếu response chứa error → log + trả về fallback
     */
    private String extractTextFromResponse(String responseJson) {
        try {
            JsonNode root = objectMapper.readTree(responseJson);

            // 1. Kiểm tra error response từ Gemini
            if (root.has("error")) {
                JsonNode errorNode = root.path("error");
                String errorCode = errorNode.path("code").asText("UNKNOWN");
                String errorMessage = errorNode.path("message").asText("Lỗi không xác định từ Gemini");
                
                if ("429".equals(errorCode) || "TOO_MANY_REQUESTS".equals(errorCode)) {
                    log.warn("Gemini API rate limit 429: {}", errorMessage);
                    throw new WebClientResponseException(429, "Too Many Requests", null, null, null);
                } else if ("500".equals(errorCode) || "503".equals(errorCode)) {
                    log.warn("Gemini API server error {}: {}", errorCode, errorMessage);
                    throw new WebClientResponseException(
                        Integer.parseInt(errorCode), 
                        "Server Error", 
                        null, null, null
                    );
                }
                
                log.error("Gemini API error {}: {}", errorCode, errorMessage);
                return "{\"reply\":\"Xin lỗi, đã xảy ra lỗi: " + errorMessage + "\",\"intent\":4}";
            }

            JsonNode candidates = root.path("candidates");

            // 2. Kiểm tra có candidates không
            if (candidates.isMissingNode() || candidates.isEmpty()) {
                log.error("Gemini API trả về không có candidates: {}", responseJson);
                return "{\"reply\":\"Xin lỗi, tôi không thể xử lý yêu cầu lúc này.\",\"intent\":4}";
            }

            // 3. Lấy text từ candidates[0].content.parts[0].text
            String text = candidates.get(0)
                    .path("content")
                    .path("parts")
                    .get(0)
                    .path("text")
                    .asText();

            // 4. Lọc bỏ các ký tự Markdown nếu Gemini bọc JSON trong ```json ... ```
            if (text.contains("```json")) {
                text = text.substring(text.indexOf("```json") + 7);
                text = text.substring(0, text.indexOf("```"));
            } else if (text.contains("```")) {
                text = text.substring(text.indexOf("```") + 3);
                text = text.substring(0, text.indexOf("```"));
            }

            return text.trim();
        } catch (WebClientResponseException e) {
            // 4. Re-throw WebClientResponseException để Retry mechanism bắt được
            throw e;
        } catch (Exception e) {
            log.error("Lỗi parse Gemini response: {}", e.getMessage(), e);
            return "{\"reply\":\"Xin lỗi, đã xảy ra lỗi khi xử lý phản hồi từ AI.\",\"intent\":4}";
        }
    }
}
