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
import fpt.aptech.server.repos.WalletRepository;
import fpt.aptech.server.entity.Wallet;
import fpt.aptech.server.service.ai.CategoryMappingService;
import fpt.aptech.server.service.cloudinary.CloudinaryService;
import fpt.aptech.server.service.transaction.TransactionService;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
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
    private final ObjectMapper objectMapper;                   // Trình phân tích JSON
    private final CategoryMappingService categoryMappingService; // Service map category
    private final ReceiptDbService receiptDbService;         // Service xử lý DB riêng
    private final WalletRepository walletRepo;                 // Repository ví

    // Prompt gửi cho mô hình Vision để đọc thông tin hóa đơn
    private static final String VISION_PROMPT = """
    BỎ QUA TẤT CẢ NGỮ CẢNH CŨ. ĐÂY LÀ MỘT HÓA ĐƠN HOÀN TOÀN MỚI.
    Phân tích ảnh hóa đơn này và trả về DUY NHẤT 1 mã JSON.
    NGHIỆM CẤM:
    - không giải thích, không bịa đặt nội dung không có trên ảnh, không được sử dụng lại dữ liệu từ các ví dụ hoặc lần quét trước.
    
    1. 'amount' (CHỈ SỬ DỤNG DỮ LIỆU TRÊN ẢNH): Đây là mục quan trọng nhất.
        - KIỂU DỮ LIỆU: Số nguyên (Number), không để trong dấu ngoặc kép, phải chính xác tuyệt đối trong ảnh không bịa đặt số tiền.
        - QUY TẮC VÀNG: Nếu hóa đơn có dòng 'Số tiền bằng chữ', BẮT BUỘC phải dùng nó làm căn cứ cuối cùng.
        - TRUY XUẤT Tìm số tiền CUỐI CÙNG phải thanh toán.
        - TRUY XUẤT (ƯU TIÊN 1): Tìm các dòng 'Tổng', 'Tổng tiền', 'Tổng cộng', 'Tổng tiền thanh toán', 'Total', 'Thành tiền'.
        - TRUY XUẤT (ƯU TIÊN 2 - HÓA ĐƠN VIẾT TAY/KHÔNG CÓ CHỮ TỔNG): Tìm con số LỚN NHẤT nằm ở phía cuối danh sách các mặt hàng.
        - LOGIC GIẢM GIÁ/THUẾ: Số tiền phải là giá trị CUỐI CÙNG khách phải trả (ĐÃ CỘNG THUẾ và ĐÃ TRỪ GIẢM GIÁ/VOUCHER).
            + Nếu chữ ghi 'Triệu' -> Kết quả phải có ít nhất 7 chữ số.
            + Nếu chữ ghi 'Nghìn/Ngàn' -> Kết quả phải có ít nhất 4 chữ số.
        - VÍ DỤ: Chữ ghi 'Năm mươi ba triệu...' -> amount KHÔNG THỂ là 5371, phải là 53712360.
        - NGHIÊM CẤM: Không tự ý cắt bỏ các chữ số ở cuối chỉ vì có dấu chấm/phẩy.
    2. 'category': "Tên nhóm chi tiêu cụ thể bằng tiếng Việt (chỉ 1 từ: Ăn uống, Di chuyển, Mua sắm, Giải trí, Học phí, Sức khỏe, Bảo hiểm, Đầu tư, Gia đình, Quà tặng, Chuyển tiền, Trả lãi, Cho vay, Vay tiền, Thu nợ, Trả nợ, Bảo dưỡng xe, Dịch vụ nhà, Sửa nhà, Thú cưng, Dịch vụ online, Du lịch, Hóa đơn nước, Hóa đơn điện, Khác)".
    3. 'note' (Mô tả chi tiết mục đích giao dịch):
        - BẮT BUỘC ghép câu theo công thức: [Hành động] + [Tên mặt hàng/Dịch vụ] + tại [Tên cửa hàng/Đơn vị] + ngày [dd/MM/yyyy].
        - TUYỆT ĐỐI không bịa đặt tên công ty nếu chữ viết tay quá mờ, chỉ ghi hành động.
        - CÁCH ĐIỀN:
          + [Hành động]: Tự động thêm các động từ như 'Mua', 'Xem phim', 'Đóng tiền', 'Thanh toán', 'Ăn uống' sao cho hợp lý với nội dung hóa đơn.
          + [dd/MM/yyyy]: Quét tìm ngày/tháng/năm in trên hóa đơn để ghi vào không bịa đặt ngày phải khớp với hóa đơn quét ra chỉ lấy ngày thanh toán trong hóa đơn. Nếu trên ảnh hoàn toàn không có ngày, có thể bỏ qua cụm từ "ngày...".
        - VÍ DỤ CHUẨN:
          + Hóa đơn điện -> "Đóng tiền điện cho Công ty Điện lực Nghệ An ngày 15/04/2026"
          + Vé xem phim -> "Xem phim Bleeding Steel tại CINEMA 3 ngày 20/12/2025"
          + Hóa đơn thú cưng -> "Mua chó Pug của A. Cường ngày 15/05/2025"
    {
       "amount": number,
       "category": string,
       "note": string,
       "date": "yyyy-MM-dd"
    }
    Nếu ảnh quá mờ hoặc không đọc được amount chính xác tuyệt đối, ảnh không phải hóa đơn, trả về: {"error": "Không đọc được ảnh hóa đơn."}
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
            throw new RuntimeException("Error uploading image to system.", e);
        }

        // Bước 2: Khai báo receipt ở scope rộng để dùng trong catch block
        Receipt receipt = null;

        // Bước 3: Chuyển ảnh sang Base64 và gọi Vision API để check có phải hóa đơn không
        try {
            // Bước 3.1: Chuyển ảnh sang Base64
            byte[] imageBytes = resizeImage(imageFile.getBytes(), 1600);
            String base64Image = Base64.getEncoder().encodeToString(imageBytes);
            log.info("[OCR] Kích thước ảnh gốc: {} bytes, Base64: {} chars", imageBytes.length, base64Image.length());

            // Bước 3.2: Gọi Vision API để check có phải hóa đơn không
            String rawOcrResponse = ollamaService.analyzeReceiptImage(base64Image, VISION_PROMPT);
            log.info("[OCR] Phản hồi từ Vision: {}", rawOcrResponse);

            // Bước 3.3: Parse Json
            JsonNode parsedJson = AiJsonParserHelper.parseJson(rawOcrResponse, objectMapper);

            // Bước 3.4: Nếu AI báo lỗi không đọc được → chỉ lưu vào tAIConversations (không tạo Receipt)
            if (parsedJson.has("error")) {
                log.info("[OCR] AI báo lỗi không đọc được hóa đơn → chỉ lưu vào tAIConversations");
                AIConversation userMsg = AIConversation.builder()
                        .account(account)
                        .messageContent("Tôi muốn lưu ảnh này vào lịch sử chat.")
                        .senderType(false)
                        .intent(null)
                        .attachmentType(1) // Image
                        .attachmentUrl(imageUrl)
                        .build();
                aiRepo.save(userMsg);

                AIConversation aiReply = createAiReply(account, "Tôi không đọc được hóa đơn này. Ảnh đã được lưu vào lịch sử chat.", null);
                return new AiChatResponse(aiReply.getId(), aiReply.getMessageContent(), AiIntent.GENERAL_CHAT.getValue(), null, null, null);
            }

            // Bước 4: Nếu AI đọc được hóa đơn → lưu vào cả tReceipts và tAIConversations (logic hiện tại)
            log.info("[OCR] AI đọc được hóa đơn → lưu vào cả tReceipts và tAIConversations");
            receipt = receiptDbService.createInitialReceipt(account, imageUrl);
            log.info("[OCR] Lưu DB trạng thái chờ thành công, receipt id = {}", receipt.getId());

            // Ghi nhận thành công (dùng ReceiptDbService với @Transactional riêng)
            receiptDbService.updateReceiptSuccess(receipt.getId(), rawOcrResponse, parsedJson.toString());

            // Lấy thông tin từ JSON
            BigDecimal amount = new BigDecimal(parsedJson.path("amount").asText("0"));
            String catName = parsedJson.path("category").asText("Khác");
            String note = parsedJson.path("note").asText("Hóa đơn: " + parsedJson.path("store").asText(""));
            String date = parsedJson.path("date").asText(null); // Parse date từ JSON

            // Map category từ text sang categoryId dùng CategoryMappingService
            int categoryId = categoryMappingService.mapCategoryFromText(catName + " " + note);

            // Validate và select wallet
            if (walletId == null) {
                // Auto-select wallet nếu client không truyền walletId
                List<Wallet> wallets = walletRepo.findByAccountId(account.getId()).stream()
                        .filter(w -> Boolean.FALSE.equals(w.getDeleted()))
                        .toList();

                if (wallets.isEmpty()) {
                    // Nếu user không có ví nào → báo lỗi
                    log.warn("[OCR] User không có ví nào để lưu giao dịch");
                    AIConversation aiError = createAiReply(account, "Bạn chưa có ví nào. Hãy tạo ví trước để lưu giao dịch từ hóa đơn.", null);
                    return new AiChatResponse(aiError.getId(), aiError.getMessageContent(), AiIntent.ADD_TRANSACTION.getValue(), null, receipt.getId(), null);
                }

                // Lọc ví có số dư đủ cho khoản chi (hóa đơn luôn là chi)
                List<Wallet> validWallets = wallets.stream()
                        .filter(w -> w.getBalance().compareTo(amount) >= 0)
                        .toList();

                if (validWallets.isEmpty()) {
                    // Nếu không có ví nào đủ tiền → báo lỗi
                    log.warn("[OCR] Không có ví nào đủ số dư để thanh toán hóa đơn");
                    AIConversation aiError = createAiReply(account, "Số dư trong các ví của bạn không đủ để thanh toán hóa đơn này.", null);
                    return new AiChatResponse(aiError.getId(), aiError.getMessageContent(), AiIntent.ADD_TRANSACTION.getValue(), null, receipt.getId(), null);
                }

                walletId = validWallets.get(0).getId(); // Chọn ví đầu tiên đủ tiền
                log.info("[OCR] Auto-select walletId = {} (balance đủ)", walletId);
            } else {
                // Validate walletId do client truyền
                Wallet wallet = walletRepo.findById(walletId).orElse(null);
                if (wallet == null) {
                    log.warn("[OCR] WalletId {} không tồn tại", walletId);
                    AIConversation aiError = createAiReply(account, "Ví bạn chọn không tồn tại.", null);
                    return new AiChatResponse(aiError.getId(), aiError.getMessageContent(), AiIntent.ADD_TRANSACTION.getValue(), null, receipt.getId(), null);
                }

                if (Boolean.TRUE.equals(wallet.getDeleted())) {
                    log.warn("[OCR] WalletId {} đã bị xóa", walletId);
                    AIConversation aiError = createAiReply(account, "Ví bạn chọn đã bị xóa.", null);
                    return new AiChatResponse(aiError.getId(), aiError.getMessageContent(), AiIntent.ADD_TRANSACTION.getValue(), null, receipt.getId(), null);
                }

                if (!wallet.getAccount().getId().equals(account.getId())) {
                    log.warn("[OCR] WalletId {} không thuộc về user", walletId);
                    AIConversation aiError = createAiReply(account, "Bạn không có quyền truy cập ví này.", null);
                    return new AiChatResponse(aiError.getId(), aiError.getMessageContent(), AiIntent.ADD_TRANSACTION.getValue(), null, receipt.getId(), null);
                }

                if (wallet.getBalance().compareTo(amount) < 0) {
                    log.warn("[OCR] WalletId {} không đủ số dư (balance={}, amount={})", walletId, wallet.getBalance(), amount);
                    AIConversation aiError = createAiReply(account, "Số dư trong ví bạn chọn không đủ để thanh toán hóa đơn này.", null);
                    return new AiChatResponse(aiError.getId(), aiError.getMessageContent(), AiIntent.ADD_TRANSACTION.getValue(), null, receipt.getId(), null);
                }

                log.info("[OCR] Validate walletId = {} thành công", walletId);
            }

            Map<String, Object> params = new HashMap<>();
            params.put("amount", amount);
            params.put("categoryId", categoryId);
            params.put("note", note); // Note từ AI Vision (có thể chưa có date)
            params.put("isIncome", false);
            params.put("walletId", walletId); // Truyền walletId để chat xử lý
            params.put("receiptId", receipt.getId()); // Truyền receiptId để set source_type = 4
            params.put("ocrDate", date); // Truyền date từ OCR để dùng khi thêm vào note

            // OCR chỉ gửi text, chat sẽ xử lý intent 1 để tạo transaction với source_type = 4
            String reply;
            if (walletId != null) {
                Wallet wallet = walletRepo.findById(walletId).orElse(null);
                String walletName = wallet != null ? wallet.getWalletName() : "";
                // Hiển thị note, category name và date
                if (date != null && !date.isEmpty()) {
                    reply = String.format("Tôi đọc được hóa đơn này: %s\nSố tiền: %,.0f đ\nDanh mục: %s\nNgày: %s\nTừ ví: '%s'\nBạn muốn lưu giao dịch không?", note, amount.doubleValue(), catName, date, walletName);
                } else {
                    reply = String.format("Tôi đọc được hóa đơn này: %s\nSố tiền: %,.0f đ\nDanh mục: %s\nTừ ví: '%s'\nBạn muốn lưu giao dịch không?", note, amount.doubleValue(), catName, walletName);
                }
            } else {
                // Hiển thị note, category name và date (không có wallet)
                if (date != null && !date.isEmpty()) {
                    reply = String.format("Tôi đọc được hóa đơn này: %s\nSố tiền: %,.0f đ\nDanh mục: %s\nNgày: %s\nBạn muốn lưu giao dịch không?", note, amount.doubleValue(), catName, date);
                } else {
                    reply = String.format("Tôi đọc được hóa đơn này: %s\nSố tiền: %,.0f đ\nDanh mục: %s\nBạn muốn lưu giao dịch không?", note, amount.doubleValue(), catName);
                }
            }

            AiChatResponse.AiAction action = new AiChatResponse.AiAction("create_transaction", false, params, List.of("Lưu giao dịch", "Hủy"));
            AIConversation aiAsk = createAiReply(account, reply, params);

            return new AiChatResponse(aiAsk.getId(), reply, AiIntent.ADD_TRANSACTION.getValue(), null, receipt.getId(), action);

        } catch (Exception e) {
            log.error("[OCR] Lỗi toàn trình xử lý hóa đơn: ", e);
            // Nếu đã tạo Receipt → update lỗi
            if (receipt != null) {
                receiptDbService.updateReceiptError(receipt.getId(), e.getMessage());
            }
            AIConversation aiError = createAiReply(account, "Đã xảy ra lỗi khi phân tích hóa đơn của bạn.", null);
            return new AiChatResponse(aiError.getId(), aiError.getMessageContent(), AiIntent.GENERAL_CHAT.getValue(), null, receipt != null ? receipt.getId() : null, null);
        }
    }

    // =================================================================================
    // PRIVATE HELPERS
    // =================================================================================

    /**
     * [HELPER] Tạo phản hồi của AI lưu vào CSDL (Mặc định Intent = ADD_TRANSACTION).
     * Lưu messageContent text hiển thị cho user, lưu actionParams riêng để parse lại.
     */
    private AIConversation createAiReply(Account account, String message, Map<String, Object> params) {
        try {
            // Bước 1: Chuẩn hóa ký tự xuống dòng: thay thế \n\n thành \n
            String normalizedMessage = normalizeLineBreaks(message);

            // Bước 2: Chuyển params sang JSON string nếu có params
            String paramsJson = null;
            if (params != null && !params.isEmpty()) {
                paramsJson = objectMapper.writeValueAsString(params);
            }

            // Bước 3: Tạo AI conversation với message text đẹp + params riêng
            AIConversation aiMsg = AIConversation.builder()
                    .account(account)
                    .messageContent(normalizedMessage)
                    .actionParams(paramsJson) // Lưu params riêng
                    .senderType(true)
                    .intent(AiIntent.ADD_TRANSACTION.getValue())
                    .build();
            return aiRepo.save(aiMsg);
        } catch (Exception e) {
            log.error("[OCR] Lỗi khi lưu message AI: ", e);
            // Fallback: lưu message gốc không có params
            AIConversation aiMsg = AIConversation.builder()
                    .account(account)
                    .messageContent(message)
                    .senderType(true)
                    .intent(AiIntent.ADD_TRANSACTION.getValue())
                    .build();
            return aiRepo.save(aiMsg);
        }
    }

    /**
     * [HELPER] Chuẩn hóa ký tự xuống dòng: thay thế \n\n thành \n để đồng nhất format.
     */
    private String normalizeLineBreaks(String message) {
        if (message == null || message.isEmpty()) {
            return message;
        }
        // Thay thế tất cả \n\n thành \n
        return message.replaceAll("\n\n", "\n");
    }

    /**
     * [HELPER] Resize ảnh về maxDim px cạnh dài, xuất JPEG để giảm token Vision model.
     */
    private byte[] resizeImage(byte[] originalBytes, int maxDim) throws Exception {
        BufferedImage img = ImageIO.read(new ByteArrayInputStream(originalBytes));
        if (img == null) return originalBytes; // Fallback nếu không đọc được

        int w = img.getWidth(), h = img.getHeight();
        if (w <= maxDim && h <= maxDim) return originalBytes; // Đã nhỏ, không cần resize

        double scale = Math.min((double) maxDim / w, (double) maxDim / h);
        int nw = (int)(w * scale), nh = (int)(h * scale);

        BufferedImage resized = new BufferedImage(nw, nh, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = resized.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.drawImage(img, 0, 0, nw, nh, null);
        g.dispose();

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        ImageIO.write(resized, "jpg", baos);
        return baos.toByteArray();
    }
}
