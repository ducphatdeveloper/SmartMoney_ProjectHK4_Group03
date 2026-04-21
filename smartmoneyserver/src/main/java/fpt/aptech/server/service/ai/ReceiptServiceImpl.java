package fpt.aptech.server.service.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fpt.aptech.server.dto.ai.AiChatResponse;
import fpt.aptech.server.entity.AIConversation;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Receipt;
import fpt.aptech.server.enums.ai.AiIntent;
import fpt.aptech.server.repos.AIConversationRepository;
import fpt.aptech.server.repos.CategoryRepository;
import fpt.aptech.server.repos.ReceiptRepository;
import fpt.aptech.server.service.ai.CategoryMappingService;
import fpt.aptech.server.service.cloudinary.CloudinaryService;
import fpt.aptech.server.service.transaction.TransactionService;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * [1] ReceiptServiceImpl — Xử lý việc nhận diện và trích xuất dữ liệu từ hóa đơn (OCR).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ReceiptServiceImpl implements ReceiptService {

    private final CloudinaryService cloudinaryService;         // Dịch vụ lưu trữ ảnh
    private final OllamaService ollamaService;                 // Dịch vụ AI cục bộ
    private final AIConversationRepository aiRepo;             // Repository cuộc trò chuyện
    private final ReceiptRepository receiptRepo;               // Repository hóa đơn
    private final CategoryRepository categoryRepo;             // Repository danh mục
    private final TransactionService transactionService;       // Dịch vụ giao dịch
    private final ObjectMapper objectMapper;                   // Trình phân tích JSON
    private final EntityManager entityManager;                 // EntityManager cho native query
    private final CategoryMappingService categoryMappingService; // Service map category
    private final ReceiptDbService receiptDbService;         // Service xử lý DB riêng

    // Prompt gửi cho mô hình Vision để đọc thông tin hóa đơn
    private static final String VISION_PROMPT = """
            Đây là ảnh hóa đơn mua hàng.
            Hãy đọc và phân tích ảnh này.
            TRẢ VỀ ĐÚNG 1 JSON THEO ĐỊNH DẠNG DƯỚI ĐÂY (Tuyệt đối không giải thích thêm, chỉ output JSON):
            {
               "store": "Tên cửa hàng",
               "amount": "Tổng số tiền (viết liền không dấu chấm phẩy, ví dụ: 500000)",
               "category": "Tên nhóm chi tiêu cụ thể bằng tiếng Việt (chỉ 1 từ: Ăn uống, Di chuyển, Mua sắm, Giải trí, Học phí, Sức khỏe, Bảo hiểm, Đầu tư, Gia đình, Quà tặng, Chuyển tiền, Trả lãi, Cho vay, Vay tiền, Thu nợ, Trả nợ, Bảo dưỡng xe, Dịch vụ nhà, Sửa nhà, Thú cưng, Dịch vụ online, Du lịch, Hóa đơn nước, Hóa đơn điện, Khác)",
               "note": "Ghi chú (tóm tắt các mặt hàng đã mua)"
            }
            Nếu không đọc được, trả về JSON:
            {
               "error": "Không đọc được ảnh hóa đơn."
            }
            """;

    // =================================================================================
    // 1. XỬ LÝ HÓA ĐƠN
    // =================================================================================

    /**
     * [1.1] Phân tích hóa đơn từ ảnh người dùng tải lên.
     * Bước 1: Upload ảnh hóa đơn lên Cloudinary.
     * Bước 2: Lưu trạng thái chờ vào Database (pending).
     * Bước 3: Chuyển đổi ảnh sang Base64 và gửi tới Ollama Vision.
     * Bước 4: Nhận kết quả và tạo lệnh xác nhận cho người dùng.
     */
    @Override
    public AiChatResponse processReceipt(Account account, MultipartFile imageFile, Integer walletId) {
        log.info("[OCR] Bắt đầu phân tích hóa đơn từ user id = {}", account.getId());

        // Bước 1: Upload ảnh Cloudinary
        String imageUrl;
        try {
            log.info("[OCR] Bắt đầu upload ảnh lên Cloudinary");
            imageUrl = cloudinaryService.uploadImage(imageFile, "smartmoney/receipts");
            log.info("[OCR] Upload ảnh thành công: {}", imageUrl);
        } catch (Exception e) {
            log.error("[OCR] Lỗi upload ảnh: ", e);
            throw new RuntimeException("Lỗi tải ảnh lên hệ thống.", e);
        }

        // Bước 2: Lưu DB trạng thái chờ (dùng ReceiptDbService với @Transactional riêng)
        log.info("[OCR] Bắt đầu lưu DB trạng thái chờ");
        Receipt receipt = receiptDbService.createInitialReceipt(account, imageUrl);
        log.info("[OCR] Lưu DB trạng thái chờ thành công, receipt id = {}", receipt.getId());

        try {
            // Bước 3: Chuyển ảnh sang Base64 (không nằm trong @Transactional)
            byte[] imageBytes = imageFile.getBytes();
            String base64Image = Base64.getEncoder().encodeToString(imageBytes);
            log.info("[OCR] Kích thước ảnh gốc: {} bytes, Base64: {} chars", imageBytes.length, base64Image.length());

            // Gọi Vision API (không nằm trong @Transactional)
            String rawOcrResponse = ollamaService.analyzeReceiptImage(base64Image, VISION_PROMPT);
            log.info("[OCR] Phản hồi từ Vision: {}", rawOcrResponse);

            // Bước 4: Parse Json
            JsonNode parsedJson = AiJsonParserHelper.parseJson(rawOcrResponse, objectMapper);

            // Nếu AI báo lỗi không đọc được
            if (parsedJson.has("error")) {
                receiptDbService.updateReceiptError(receipt.getId(), "Không đọc được ảnh hóa đơn.");
                AIConversation aiError = createAiReply(account, "Tôi không đọc được hóa đơn này. Xin hãy chụp lại.");
                return new AiChatResponse(aiError.getId(), aiError.getMessageContent(), AiIntent.ADD_TRANSACTION.getValue(), null, receipt.getId(), null);
            }

            // Ghi nhận thành công (dùng ReceiptDbService với @Transactional riêng)
            receiptDbService.updateReceiptSuccess(receipt.getId(), rawOcrResponse, parsedJson.toString());

            // Lấy thông tin từ JSON
            BigDecimal amount = new BigDecimal(parsedJson.path("amount").asText("0"));
            String catName = parsedJson.path("category").asText("Khác");
            String note = parsedJson.path("note").asText("Hóa đơn: " + parsedJson.path("store").asText(""));

            // Map category từ text sang categoryId dùng CategoryMappingService
            int categoryId = categoryMappingService.mapCategoryFromText(catName + " " + note);

            Map<String, Object> params = new HashMap<>();
            params.put("amount", amount);
            params.put("categoryId", categoryId);
            params.put("note", note);
            params.put("isIncome", false);
            params.put("walletId", walletId); // Truyền walletId để chat xử lý
            params.put("receiptId", receipt.getId()); // Truyền receiptId để set source_type = 4

            // OCR chỉ gửi text, chat sẽ xử lý intent 1 để tạo transaction với source_type = 4
            String reply = String.format("Tôi đọc được hóa đơn này: %,.0f đ (Mục: %s). Bạn muốn lưu giao dịch không?", amount.doubleValue(), catName);

            AiChatResponse.AiAction action = new AiChatResponse.AiAction("create_transaction", false, params, List.of("Lưu giao dịch", "Hủy"));
            AIConversation aiAsk = createAiReply(account, reply);

            return new AiChatResponse(aiAsk.getId(), reply, AiIntent.ADD_TRANSACTION.getValue(), null, receipt.getId(), action);

        } catch (Exception e) {
            log.error("[OCR] Lỗi toàn trình xử lý hóa đơn: ", e);
            receiptDbService.updateReceiptError(receipt.getId(), e.getMessage());
            AIConversation aiError = createAiReply(account, "Đã xảy ra lỗi khi phân tích hóa đơn của bạn.");
            return new AiChatResponse(aiError.getId(), aiError.getMessageContent(), AiIntent.ADD_TRANSACTION.getValue(), null, receipt.getId(), null);
        }
    }

    // =================================================================================
    // PRIVATE HELPERS
    // =================================================================================

    /**
     * [HELPER] Tạo phản hồi của AI lưu vào CSDL (Mặc định Intent = ADD_TRANSACTION).
     */
    private AIConversation createAiReply(Account account, String message) {
        AIConversation aiMsg = AIConversation.builder()
                .account(account)
                .messageContent(message)
                .senderType(true)
                .intent(AiIntent.ADD_TRANSACTION.getValue())
                .build();
        return aiRepo.save(aiMsg);
    }
}
