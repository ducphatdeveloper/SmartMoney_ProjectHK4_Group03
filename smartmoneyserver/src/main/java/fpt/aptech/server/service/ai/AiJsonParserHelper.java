package fpt.aptech.server.service.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.extern.slf4j.Slf4j;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Lớp tiện ích hỗ trợ Parse JSON trả về từ Model AI (thường bị dư block markdown).
 */
@Slf4j
public class AiJsonParserHelper {

    /**
     * [HELPER] Làm sạch markdown và parse chuỗi văn bản AI thành JsonNode.
     * Sử dụng cho cả phản hồi của Text Model và Vision Model.
     */
    public static JsonNode parseJson(String rawResponse, ObjectMapper objectMapper) {
        try {
            String cleaned = rawResponse.trim();
            // Nếu AI trả về trong định dạng block code Markdown (```json ... ```)
            if (cleaned.startsWith("```")) {
                cleaned = cleaned.replaceAll("^```[a-z]*\\n?", "").replaceAll("```$", "").trim();
            }

            // Tìm khoảng bao bọc bởi ngoặc nhọn
            int start = cleaned.indexOf('{');
            int end = cleaned.lastIndexOf('}');
            if (start != -1 && end != -1) {
                cleaned = cleaned.substring(start, end + 1);

                // Bước 1: Parse JSON gốc trước (newline giữa các field là whitespace hợp lệ)
                try {
                    return objectMapper.readTree(cleaned);
                } catch (Exception firstTry) {
                    // Bước 2: Nếu fail → Ollama có thể trả newline trong string value
                    // Escape newline rồi thử lại
                    log.debug("[AI JsonParser] Parse lần 1 fail, thử escape newline: {}", firstTry.getMessage());
                    try {
                        String escaped = cleaned.replace("\n", "\\n").replace("\r", "\\r");
                        return objectMapper.readTree(escaped);
                    } catch (Exception secondTry) {
                        // Bước 3: Reply chứa dấu " không escape → dùng regex trích fields
                        log.debug("[AI JsonParser] Parse lần 2 fail, thử regex: {}", secondTry.getMessage());
                        return extractByRegex(cleaned, objectMapper);
                    }
                }
            }

            // Nếu không có JSON, trả về raw text trong field "reply"
            log.info("[AI JsonParser] Không tìm thấy JSON, trả về raw text.");
            return objectMapper.createObjectNode()
                    .put("intent", 0)
                    .put("reply", rawResponse);
        } catch (Exception e) {
            log.warn("[AI JsonParser] Không parse được JSON, trả về raw text fallback. Error: {}", e.getMessage());
            return objectMapper.createObjectNode()
                    .put("intent", 0)
                    .put("reply", rawResponse);
        }
    }

    /**
     * [HELPER] Regex fallback - trích intent, amount, categoryId, note, reply từ raw JSON
     * Dùng khi Jackson không parse được do AI trả reply chứa dấu " hoặc ký tự đặc biệt
     */
    private static JsonNode extractByRegex(String jsonStr, ObjectMapper objectMapper) {
        ObjectNode node = objectMapper.createObjectNode();

        // 1. Trích intent
        Matcher intentM = Pattern.compile("\"intent\"\\s*:\\s*(\\d+)").matcher(jsonStr);
        int intent = intentM.find() ? Integer.parseInt(intentM.group(1)) : 0;
        node.put("intent", intent);

        // 2. Trích amount (cho intent=1 ADD_TRANSACTION)
        Matcher amountM = Pattern.compile("\"amount\"\\s*:\\s*([\\d.]+)").matcher(jsonStr);
        if (amountM.find()) node.put("amount", Double.parseDouble(amountM.group(1)));

        // 3. Trích categoryId (cho intent=1)
        Matcher catM = Pattern.compile("\"categoryId\"\\s*:\\s*(\\d+)").matcher(jsonStr);
        if (catM.find()) node.put("categoryId", Integer.parseInt(catM.group(1)));

        // 4. Trích note (cho intent=1) - note ngắn, dùng non-greedy match
        Matcher noteM = Pattern.compile("\"note\"\\s*:\\s*\"([^\"]+)\"").matcher(jsonStr);
        if (noteM.find()) node.put("note", noteM.group(1));

        // 5. Trích reply (cho intent=4 ADVISORY) - reply dài, có thể chứa " và newline
        Matcher replyStart = Pattern.compile("\"reply\"\\s*:\\s*\"").matcher(jsonStr);
        if (replyStart.find()) {
            String replyContent = jsonStr.substring(replyStart.end());
            // Cắt bỏ "} cuối cùng (closing quote + closing brace)
            int lastClose = replyContent.lastIndexOf("\"}");
            if (lastClose > 0) {
                replyContent = replyContent.substring(0, lastClose);
            }
            node.put("reply", replyContent.trim());
        }

        log.info("[AI JsonParser] Regex extraction thành công: intent={}", intent);
        return node;
    }
}
