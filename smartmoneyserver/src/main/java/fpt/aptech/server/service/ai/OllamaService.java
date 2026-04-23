package fpt.aptech.server.service.ai;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.SystemMessage;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.ollama.OllamaChatModel;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * [1] OllamaService — Dịch vụ tích hợp gọi API tới máy chủ Ollama cục bộ.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class OllamaService {

    private final OllamaChatModel chatModel;  // Mô hình chat text của Spring AI

    // RestTemplate với timeout 5 phút (inject từ RestTemplateConfig)
    private final RestTemplate restTemplate;

    @Value("${spring.ai.ollama.base-url:http://localhost:11434}")
    private String ollamaBaseUrl;

    @Value("${spring.ai.ollama.vision.model:qwen3-vl:4b}")
    private String visionModelName;           // Tên model Vision sử dụng để đọc hóa đơn

    private static final int CONTEXT_MESSAGE_LIMIT = 10; // Giới hạn số lượng tin nhắn lịch sử tối đa

    // =========================================================================
    // 1. TÍCH HỢP CHAT MODEL (TEXT)
    // =========================================================================

    /**
     * [1.1] Xử lý Chat Text qua Spring AI (OllamaChatModel).
     * <p>
     * Bước 1: Khởi tạo danh sách tin nhắn và đưa System Prompt vào trước.<br>
     * Bước 2: Duyệt lịch sử và đưa vào ngữ cảnh (Giới hạn số lượng tin nhắn).<br>
     * Bước 3: Thêm tin nhắn hiện tại của người dùng.<br>
     * Bước 4: Gọi Model và trả kết quả phản hồi.
     */
    public String chat(String systemPrompt, List<Map<String, String>> history, String userMessage) {
        try {
            // Bước 1: Tạo danh sách tin nhắn và đưa System Prompt vào trước
            List<Message> messages = new ArrayList<>();
            messages.add(new SystemMessage(systemPrompt));

            // Bước 2: Giới hạn số lượng tin nhắn lịch sử và đưa vào ngữ cảnh
            int startIdx = Math.max(0, history.size() - CONTEXT_MESSAGE_LIMIT);
            for (int i = startIdx; i < history.size(); i++) {
                Map<String, String> turn = history.get(i);
                String role = turn.getOrDefault("role", "user");
                String content = turn.getOrDefault("content", "");

                if ("assistant".equals(role)) {
                    messages.add(new AssistantMessage(content));
                } else {
                    messages.add(new UserMessage(content));
                }
            }

            // Bước 3: Thêm tin nhắn hiện tại của người dùng
            messages.add(new UserMessage(userMessage));

            // Bước 4: Gọi Model AI và trả kết quả phản hồi
            ChatResponse response = chatModel.call(new Prompt(messages));
            return response.getResult().getOutput().getText();

        } catch (Exception e) {
            log.error("[OllamaService] Lỗi gọi chat model: {}", e.getMessage(), e);
            throw new RuntimeException("Cannot connect to Ollama for chat processing.");
        }
    }

    // =========================================================================
    // 2. TÍCH HỢP VISION MODEL (IMAGE OCR)
    // =========================================================================

    /**
     * [2.1] Xử lý OCR Hóa đơn qua RestTemplate (Ollama API trực tiếp).
     * <p>
     * Do Spring AI (1.1.x) liên tục thay đổi API xử lý hình ảnh,
     * việc dùng HTTP Client gọi thẳng Ollama an toàn và ít lỗi hơn.
     * <p>
     * Bước 1: Xây dựng HttpHeaders và Body chứa ảnh Base64.<br>
     * Bước 2: Gửi Request tới `/api/generate`.<br>
     * Bước 3: Parse và trả về nội dung AI đọc được.
     */
    public String analyzeReceiptImage(String base64Image, String promptText) {
        try {
            // Bước 1: Xây dựng Headers và Body
            String url = ollamaBaseUrl + "/api/generate";

            HttpHeaders headers = new HttpHeaders();
            headers.set("Content-Type", "application/json");

            Map<String, Object> requestBody = Map.of(
                    "model", visionModelName,
                    "prompt", promptText,
                    "images", List.of(base64Image),
                    "stream", false,
                    "options", Map.of("temperature", 0.1) // Nhiệt độ thấp cho OCR chính xác
            );

            HttpEntity<Map<String, Object>> requestEntity = new HttpEntity<>(requestBody, headers);

            log.info("[OllamaService] Đang gọi vision model tại {}", url);

            // Bước 2: Gửi Request bằng RestTemplate
            ParameterizedTypeReference<Map<String, Object>> responseType = new ParameterizedTypeReference<>() {};
            ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                    url,
                    HttpMethod.POST,
                    requestEntity,
                    responseType
            );

            // Bước 3: Đọc phản hồi
            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                Object responseBody = response.getBody().get("response");
                return responseBody != null ? responseBody.toString() : "";
            } else {
                throw new RuntimeException("Error response from Ollama Vision API. Error code: " + response.getStatusCode());
            }

        } catch (Exception e) {
            log.error("[OllamaService] Lỗi gọi vision model: {}", e.getMessage(), e);
            throw new RuntimeException("Cannot analyze receipt image.");
        }
    }
}
