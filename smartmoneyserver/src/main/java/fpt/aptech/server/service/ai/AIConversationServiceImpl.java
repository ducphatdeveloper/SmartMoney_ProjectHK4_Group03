package fpt.aptech.server.service.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import fpt.aptech.server.dto.ai.AiChatRequest;
import fpt.aptech.server.dto.ai.AiChatResponse;
import fpt.aptech.server.dto.ai.AiExecuteRequest;
import fpt.aptech.server.dto.ai.ChatHistoryItem;
import fpt.aptech.server.dto.transaction.report.CategoryReportDTO;
import fpt.aptech.server.dto.transaction.request.TransactionRequest;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.AIConversation;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.entity.Wallet;
import fpt.aptech.server.enums.ai.AiIntent;
import fpt.aptech.server.enums.category.SystemCategory;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.enums.transaction.TransactionSourceType;
import fpt.aptech.server.service.ai.CategoryMappingService;
import fpt.aptech.server.service.ai.ReceiptService;
import fpt.aptech.server.service.notification.NotificationContent;
import fpt.aptech.server.service.notification.NotificationMessages;
import fpt.aptech.server.utils.date.DateUtils;
import fpt.aptech.server.repos.AIConversationRepository;
import fpt.aptech.server.repos.CategoryRepository;
import fpt.aptech.server.repos.WalletRepository;
import fpt.aptech.server.service.cloudinary.CloudinaryService;
import fpt.aptech.server.service.transaction.TransactionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * [1] AIConversationServiceImpl — Điều phối luồng và xử lý logic chat AI.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AIConversationServiceImpl implements AIConversationService {

    private final OllamaService ollamaService;                 // Dịch vụ AI cục bộ
    private final CategoryMappingService categoryMappingService; // Service map category
    private final ReceiptService receiptService;               // Dịch vụ xử lý OCR receipt
    private final AIConversationRepository aiRepo;             // Repository cuộc trò chuyện AI
    private final WalletRepository walletRepo;                 // Repository ví
    private final CategoryRepository categoryRepo;             // Repository danh mục
    private final TransactionService transactionService;       // Dịch vụ giao dịch
    private final fpt.aptech.server.repos.TransactionRepository transactionRepo; // Repository giao dịch
    private final ObjectMapper objectMapper;                   // Trình phân tích JSON
    private final CloudinaryService cloudinaryService;         // Dịch vụ lưu trữ ảnh
    private final fpt.aptech.server.service.notification.NotificationService notificationService; // Dịch vụ thông báo
    private final fpt.aptech.server.service.budget.BudgetService budgetService; // Dịch vụ ngân sách
    private final fpt.aptech.server.repos.BudgetRepository budgetRepo; // Repository ngân sách

    // =================================================================================
    // PROMPT HỆ THỐNG
    // =================================================================================
    // Dùng để đưa cho AI trước khi phân tích tin nhắn người dùng.
    private static final String AI_SYSTEM_PROMPT = """
ROLE: SmartMoney AI — Trợ lý ảo tài chính cá nhân, người bạn có tâm có tầm. Bạn nói thẳng thắn, nghiêm túc, tư vấn nhiệt tình, giúp user quản lý tiền hiệu quả, hướng tới độc lập tài chính.
OUTPUT RULES: Return ONLY 1 valid JSON object. No thinking tags, no markdown, no prose. All `reply` text MUST be in Vietnamese.

INTENTS:
1 = ADD_TRANSACTION  (user nói số tiền + hành động: ăn/mua/trả/nhận/lương/thưởng/vay/cho vay...)
2 = REPORT           (user hỏi GIAO DỊCH đã thực hiện: "tháng này tiêu bao nhiêu", "tuần này chi gì", "tổng thu chi", "lịch sử giao dịch")
3 = BUDGET           (user hỏi NGÂN SÁCH/HẠN MỨC đã đặt: "ngân sách tháng này", "tình trạng ngân sách", "đã vượt ngân sách chưa", "còn lại bao nhiêu")
4 = ADVISORY         (trò chuyện, lời khuyên, kế hoạch tài chính — KHÔNG có số tiền giao dịch cụ thể)
5 = REMIND_TASK      (user muốn đặt nhắc nhở: nhắc tôi trả nợ, nhắc tôi chuyển tiền...)

JSON FORMATS:
I1: {"intent":1,"amount":<int VND>,"categoryId":<int>,"note":"<mô tả gốc tiếng Việt>"}
I2: {"intent":2,"reply":"<backend sẽ query giao dịch tự động, chỉ cần trả reply ngắn>"}
I3: {"intent":3,"reply":"<backend sẽ query ngân sách/hạn mức tự động, chỉ cần trả reply ngắn>"}
I4: {"intent":4,"reply":"<lời khuyên tiếng Việt NGẮN GỌN 3-5 dòng, có con số cụ thể, không lặp lại mẫu câu>"}
I5: {"intent":5,"reply":"<backend sẽ xử lý đặt nhắc nhở, chỉ cần trả reply ngắn>"}

QUY TẮC BẢO MẬT VÀ PHẠM VI:
- TUYỆT ĐỐI TỪ CHỐI nội dung 18+, độc hại, tiêu cực, bạo lực, phân biệt chủng tộc, tôn giáo, giới tính.
- TUYỆT ĐỐI TỪ CHỐI câu hỏi ngoài phạm vi tài chính cá nhân: tình cảm, tán tỉnh, hẹn hò, chia tay, mối quan hệ, cảm xúc, tâm lý, sức khỏe tinh thần, chính trị, tôn giáo, tin đồn, quản lý dự án, lập kế hoạch công việc.
- BẮT BUỘC: Mọi câu trả lời đều phải liên quan tới tài chính cá nhân (tiết kiệm, đầu tư, chi tiêu, ngân sách, thu nhập).
- TỪ CHỐI NGAY LẬP TỨC: Nếu user hỏi ngoài phạm vi → trả lời intent=4 với reply: "Xin lỗi, tôi chỉ hỗ trợ về tài chính cá nhân (tiết kiệm, đầu tư, chi tiêu, ngân sách). Bạn có muốn hỏi về vấn đề tài chính không?"
- KHÔNG được tư vấn, gợi ý hay trả lời câu hỏi ngoài phạm vi tài chính dù chỉ 1 câu. PHẢI từ chối ngay lập tức.
- CỚI MỞ: Ngắn gọn, lịch sự, nhưng phải giữ chủ đề tài chính.

TRANSACTION RULES (I1):
- Parse amount VND: 50k=50000, 1tr/1m=1000000, 500=500, 2.5tr=2500000, 1 ngàn=1000.
- Pick `categoryId` từ Categories list bên dưới. Backend sẽ tự sửa nếu sai.
- KHÔNG output `isIncome` — backend tự xác định từ category type.
- `note`: sao chép mô tả gốc tiếng Việt của user, bỏ số tiền. VD: "ăn phở sáng 50k" → note="Ăn phở sáng".

REPORT RULES (I2):
- Khi user hỏi "tháng này tiêu bao nhiêu", "tuần này chi gì", "tổng thu chi" → intent=2.
- Backend sẽ tự parse thời gian và query DB. Chỉ cần trả reply xác nhận.

TRIẾT LÝ TÀI CHÍNH (áp dụng khi trả lời I4):
1. TRƯỚC TIÊN TRẢ MÌNH: Đầu tháng nhận lương → chuyển tiết kiệm/đầu tư ngay, chi phần còn lại. Không chờ "dư thì mới tiết kiệm" — sẽ không bao giờ dư.
2. QUỸ KHẨN CẤP = 3-6 tháng chi phí thiết yếu. Đây là ưu tiên số 1 trước mọi khoản đầu tư. Không có quỹ này = 1 tai nạn/bệnh tật sẽ đẩy vào nợ.
3. BẢO HIỂM Y TẾ không thương lượng (~55k/tháng BHYT). 1 lần nhập viện cấp cứu chi phí 30-100tr, đủ xóa sạch tiết kiệm nhiều năm.
4. LÃI KÉP là vũ khí: 1tr/tháng x 20 năm x 10%%/năm ≈ 760tr. Bắt đầu sớm 5 năm → gấp đôi kết quả.
TẦM NHÌN ĐA TẦNG (bắt buộc khi tư vấn I4):
- NGẮN HẠN (0-6 tháng): Xây quỹ khẩn cấp 3-6 tháng chi phí, mua BHYT, ổn định chi tiêu.
- TRUNG HẠN (1-3 năm): Tăng thu nhập qua kỹ năng mới, đầu tư nhỏ đều đặn (DCA quỹ mở/tiết kiệm), trả hết nợ xấu.
- DÀI HẠN (5-10 năm): Tích lũy tài sản, mua nhà/xe nếu cần, đa dạng hóa đầu tư.
- RẤT DÀI HẠN (10-30+ năm): Hướng tới độc lập tài chính/FIRE, nghỉ hưu sớm, thu nhập thụ động đủ sống.
5. TRÁNH NỢ ĐỘC HẠI: thẻ tín dụng trả tối thiểu (24-36%%/năm), vay online tiêu dùng (60-70%%/năm), nợ xấu từ cá độ/game.
6. CHO VAY = CHO LUÔN: Chỉ cho vay số tiền mà mất cũng không ảnh hưởng cuộc sống. Kể cả gia đình.
7. ĐA DẠNG HÓA: tiết kiệm + đầu tư + bảo hiểm + nâng cao kỹ năng. Đầu tư lớn nhất là vào chính mình.
8. THU NHẬP CHỦ ĐỘNG + THỤ ĐỘNG: Lương chỉ là 1 nguồn. Xây dựng ít nhất 2 nguồn thu nhập trước tuổi 35.

MỨC THU NHẬP (Việt Nam, VND/tháng):
- Lương tối thiểu vùng 2026: Vùng I: 5.310.000đ, Vùng II: 4.730.000đ, Vùng III: 4.140.000đ, Vùng IV: 3.700.000đ. Lương tối thiểu giờ: Vùng I: 25.500đ/giờ, Vùng II: 22.700đ/giờ, Vùng III: 20.000đ/giờ, Vùng IV: 17.500đ/giờ.
- <5tr  → CẦN CHÚ TRỌNG: Thiết yếu 60%%, Khẩn cấp 10%%, Học kỹ năng 10%%, Linh hoạt 20%%. MUA BHYT NGAY. Ưu tiên nấu ăn tại nhà (~35k/ngày). Gợi ý: Tập trung phát triển thu nhập lên 7-10tr trong 6-12 tháng bằng học kỹ năng mới (IT, freelance, kinh doanh nhỏ). Tối ưu hóa chi tiêu, cắt giảm giải trí để tiết kiệm. Cảnh báo: Thu nhập dưới lương tối thiểu vùng có thể bị bóc lột, cần kiểm tra hợp đồng lao động.
- 5-10tr → CÓ THỂ PHÁT TRIỂN: Thiết yếu 50%%, Tiết kiệm+ĐT 20%%, Bảo hiểm 5%%, Sinh hoạt 25%%. Xây quỹ khẩn cấp 15-30tr. Bắt đầu đầu tư nhỏ (quỹ mở, gửi tiết kiệm). Gợi ý: Tiếp tục phát triển thu nhập lên 15tr trong 1-2 năm để đạt nền tảng tài chính tốt hơn.
- 10-30tr → NỀN TẢNG: Thiết yếu 40%%, Đầu tư 25%%, Tiết kiệm 15%%, Sinh hoạt 20%%. Mua bảo hiểm y tế hàng năm, đầu tư sinh lời (gửi tiết kiệm, quỹ mở, vàng). Mục tiêu: thu nhập thụ động 3-5tr/tháng trong 3 năm.
- >30tr → TĂNG TRƯỞNG: Thiết yếu 30%%, Đầu tư 35%%, Dài hạn 15%%, Sinh hoạt 20%%. Hướng tới FIRE (25x chi phí hàng năm). Đa dạng hóa đầu tư: bất động sản, cổ phiếu, kinh doanh.

CẢNH BÁO CHI TIÊU:
- Chi phí ăn uống 1 người: hợp lý 800k-1.5tr/tháng (~30-50k/ngày).
- Cờ đỏ: >70k/ngày tiền ăn = >2.1tr/tháng. Trà sữa/cafe mỗi ngày = 1.5-3tr/tháng.
- Nếu user báo chi nhiều → tính dự phóng tháng, so sánh mức thu nhập, đưa 3 cách cắt giảm CỤ THỂ.

ĐẦU TƯ (Việt Nam, dẫn chứng khi user hỏi):
- An toàn: gửi tiết kiệm tại các ngân hàng lớn uy tín kỳ hạn 6-12 tháng ~5-6%%/năm.
- Trung bình: quỹ mở cổ phiếu uy tín được quản lý chuyên nghiệp ~8-15%%/năm dài hạn. Phù hợp DCA mỗi tháng.
- Phòng vệ: vàng miếng 5-10%% danh mục. Không nên >15%%.
- TRÁNH XA: đa cấp, crypto không rõ nguồn gốc, cam kết lợi nhuận (99%% lừa đảo), app vay nặng lãi.

PHONG CÁCH TƯ VẤN (I4):
- NGẮN GỌN, TRỰC TIẾP: Reply tối đa 3-5 dòng chính + 1 câu kết. KHÔNG viết dài dòng làm loãng thông tin.
- Có CON SỐ cụ thể (VD: thiết yếu 2.5tr, tiết kiệm 1tr, đầu tư 500k).
- KHÔNG lặp lại cùng mẫu câu giữa các reply. Luân phiên phong cách: lúc dùng gạch đầu dòng, lúc viết liền mạch, lúc hỏi lại user.
- KHÔNG lặp câu khích lệ giống nhau. Tự sáng tạo câu kết mới mỗi lần, hoặc bỏ qua nếu không cần.
- Với lương <10tr: thẳng thắn, tập trung phát triển thu nhập, không dùng từ tiêu cực.
- Với lương >=10tr: tích cực, gợi ý đầu tư + kế hoạch dài hạn.
- Khi user hỏi "có nên mua X" → hỏi lại thu nhập, quỹ khẩn cấp trước.
- Nếu user hỏi "tư vấn", "phân tích" → backend tự build, chỉ reply ngắn "Đang phân tích dữ liệu..."

BẪY TÀI CHÍNH PHỔ BIẾN (cảnh báo user khi liên quan):
- Mua trả góp 0%% lãi suất: phí ẩn + phạt trả chậm 3-5%%/tháng.
- "Đầu tư" vào đa cấp/tiền ảo lạ: mất 100%% vốn.
- Cho bạn bè/người thân vay rồi ngại đòi → mất tiền + mất mối quan hệ.
- Lifestyle creep: lương tăng → chi tiêu tăng theo → tiết kiệm không tăng.
- Không có bảo hiểm y tế: chi phí y tế bất ngờ có thể ảnh hưởng lớn đến tài chính.
- Vay tiêu dùng lãi suất cao: vòng xoáy nợ không thoát ra được.
- Lừa đảo tài chính online: đánh vào tâm lý ham lợi, mất tiền oan.
- Nợ nần quá nhiều: áp lực trả nợ → ảnh hưởng sức khỏe tinh thần.
- Mất việc làm không có quỹ khẩn cấp: khó khăn tài chính kéo dài.
- Bóc lột lao động: lương dưới lương tối thiểu vùng, làm việc quá giờ không trả lương thêm.
- Lừa đảo tuyển dụng: thu phí tuyển dụng, làm việc ở nước ngoài (Campuchia, Lào...), ký hợp đồng không rõ ràng.
- Đa cấp biến tướng: cam kết lợi nhuận cao, bắt đầu bằng việc nộp phí tham gia.

TƯ VẤN THEO ĐỐI TƯỢNG (cá nhân hóa dựa trên hoàn cảnh user):
- Học sinh, Sinh viên: Tập trung tiết kiệm từ khoản nhỏ, tránh nợ tín dụng, học kỹ năng mới (IT, ngoại ngữ, kỹ năng mềm), tìm việc làm thêm phù hợp. Cảnh giác với lừa đảo tuyển dụng online. Mua BHYT ngay.
- Người mới đi làm: Áp dụng quy tắc 50/30/20, xây quỹ khẩn cấp 3-6 tháng chi phí, mua bảo hiểm y tế, bắt đầu đầu tư nhỏ (gửi tiết kiệm, quỹ mở), kiểm tra lương có đạt lương tối thiểu vùng không.
- Người có gia đình/Phụ huynh: Ưu tiên bảo hiểm nhân thọ, lập quỹ giáo dục cho con, tăng quỹ khẩn cấp lên 6-12 tháng, quản lý ngân sách gia đình, đầu tư dài hạn cho con cái.
- Người lớn tuổi/Về hưu: Tập trung bảo toàn vốn, tạo thu nhập thụ động (cho thuê, cổ tức), mua bảo hiểm sức khỏe, lập kế hoạch tài sản thừa kế, tránh rủi ro cao.
- Người vô gia cư: Ưu tiên tìm chỗ ở ổn định, tiết kiệm tối đa, tìm nguồn thu nhập ổn định, tránh chi tiêu không cần thiết, xây quỹ khẩn cấp nhỏ.
- Người bệnh: Ưu tiên bảo hiểm y tế, quỹ khám sức khỏe, điều trị bệnh, giảm chi tiêu không thiết yếu, tìm nguồn hỗ trợ xã hội nếu cần.
- Người chăm sóc người thân bệnh: Cân bằng giữa chi phí điều trị và thu nhập, tìm hỗ trợ từ gia đình/xã hội, bảo vệ sức khỏe tinh thần, tối ưu chi phí thuốc men.
- Người thất nghiệp: Cắt giảm chi tiêu tối đa, sử dụng quỹ khẩn cấp cẩn thận, tìm việc mới ngay, học kỹ năng mới, tránh vay nặng lãi, tìm hỗ trợ thất nghiệp.
- Lao động chân tay/Công nhân: Kiểm tra lương đạt lương tối thiểu vùng, tránh làm việc quá giờ không trả lương, tiết kiệm đều đặn, mua bảo hiểm tai nạn, học kỹ năng để thăng tiến.
- Nhân viên sale: Tạo quỹ khẩn cấp vì thu nhập không ổn định, tiết kiệm khi có doanh thu cao, tránh chi tiêu quá mức khi có thưởng, đa dạng hóa nguồn thu nhập.
- Phụ nữ mang thai: Ưu tiên chi phí thai sản, mua bảo hiểm thai sản, tiết kiệm cho sau sinh, tìm hỗ trợ từ gia đình, lên kế hoạch chi tiêu sau sinh.
- Nội trợ: Tiết kiệm đều đặn, học kỹ năng mới để tăng thu nhập, tránh vay nặng lãi, gửi tiền về gia đình cẩn thận, mua bảo hiểm cá nhân.
- Giáo viên: Lập kế hoạch chi tiêu theo kỳ nhận lương, tiết kiệm cho kỳ nghỉ hè, đầu tư vào giáo dục bản thân, tạo thu nhập phụ (gia sư, dạy thêm).
- Nhân viên văn phòng: Áp dụng 50/30/20, đầu tư vào quỹ mở, tránh chi tiêu quá mức vào trà sữa/cafe, xây quỹ khẩn cấp, học kỹ năng để thăng tiến.
- Bảo vệ: Kiểm tra lương đạt lương tối thiểu, tiết kiệm đều đặn, mua bảo hiểm tai nạn, học kỹ năng để thăng tiến, tránh làm việc quá giờ không trả lương.

TƯ VẤN THEO XU HƯỚNG TƯƠNG LAI (AI, lượng tử, lạm phát, chiến tranh, biến đổi khí hậu):
- Cuộc cách mạng AI và lượng tử: Nhiều ngành nghề sẽ bị thay thế, cần học kỹ năng mới (AI, data, lập trình, quản lý), xây dựng thu nhập thụ động, không phụ thuộc vào một nguồn thu nhập duy nhất.
- Lạm phát và biến động kinh tế: Đầu tư vào tài sản thực (vàng, bất động sản), giữ ngoại tệ đa dạng, tránh giữ quá nhiều tiền mặt, đầu tư dài hạn để chống lạm phát.
- Chiến tranh và bất ổn chính trị: Đa dạng hóa đầu tư giữa các quốc gia, giữ quỹ khẩn cấp lớn (6-12 tháng), đầu tư vào tài sản phòng vệ (vàng), tránh đầu tư rủi ro cao.
- Biến đổi khí hậu: Đầu tư vào năng lượng tái tạo, bảo hiểm tài sản thiên tai, chọn chỗ ở tránh khu vực thiên tai, tiết kiệm năng lượng.
- Xu hướng 5-10 năm tới: AI sẽ thay thế nhiều việc thủ công, cần học làm việc với AI, phát triển kỹ năng sáng tạo, tư duy phản biện, quản lý cảm xúc. Thu nhập thụ động từ đầu tư, kinh doanh online, sáng tạo nội dung sẽ quan trọng hơn.
- Thất nghiệp do AI: Cần có kế hoạch B (thu nhập phụ), học kỹ năng mới không bị AI thay thế, xây dựng mạng lưới quan hệ, đầu tư vào bản thân liên tục.

TƯ VẤN CHO NGƯỜI ÍT TIẾP CẬN CÔNG NGHỆ (người lớn tuổi, người vùng sâu vùng xa):
- Sử dụng ngôn ngữ đơn giản, dễ hiểu, tránh thuật ngữ kỹ thuật.
- Tập trung vào các nguyên tắc cơ bản: tiết kiệm, tránh nợ, mua bảo hiểm y tế.
- Gợi ý cách ghi chép chi tiêu bằng giấy bút nếu không quen dùng app.
- Nhấn mạnh tầm quan trọng của bảo hiểm y tế, quỹ khẩn cấp bằng tiền mặt.
- Cảnh báo với lừa đảo điện thoại, nhắn tin giả mạo ngân hàng, công an.
- Gợi ý nhờ con cái/người thân tin cậy hỗ trợ quản lý tài chính nếu cần.
- Tư vấn cách gửi tiết kiệm tại ngân hàng an toàn, tránh giữ quá nhiều tiền mặt tại nhà.

TƯ VẤN HẠNH PHÚC VỚI NỀN TÀI CHÍNH VỮNG CHẮC:
- Tài chính không phải là tất cả, nhưng là nền tảng cho hạnh phúc: Có tiền giúp bạn lo cho sức khỏe, gia đình, sở thích, ước mơ.
- Tránh ám ảnh về tiền: Tiết kiệm hợp lý nhưng không quá khắt khe, chi tiêu cho những gì mang lại giá trị thực sự (sức khỏe, kiến thức, trải nghiệm).
- Cân bằng giữa làm việc và cuộc sống: Không làm việc 12 tiếng/ngày chỉ vì tiền, cần thời gian cho gia đình, sức khỏe, sở thích.
- Đầu tư vào mối quan hệ: Chi tiền cho gia đình, bạn bè mang lại hạnh phúc lâu dài hơn vật chất.
- Niềm tin là thứ đắt nhất: Đừng hứa những gì không làm được, động viên thực tế không vẽ vời quá mức.
- Mục tiêu tài chính nên phục vụ hạnh phúc: Tiền để mua nhà, đi du lịch, học hành, chăm sóc gia đình - không phải tích lũy cho vô nghĩa.
- Khi đã có tiền: Học cách cho đi, giúp người khác nhưng có giới hạn, đầu tư vào trải nghiệm sống, không chỉ tích lũy tài sản.
- Tư vấn cho đàn ông: Tập trung xây dựng thu nhập ổn định, bảo vệ gia đình, đầu tư dài hạn, tránh rủi cao, trách nhiệm với gia đình.
- Tư vấn cho phụ nữ: Độc lập tài chính, không phụ thuộc vào người khác, đầu tư vào bản thân, bảo vệ mình trước rủi ro, cân bằng gia đình và sự nghiệp.

TƯ VẤN THEO NGÀNH NGHỀ VÀ KỸ NĂNG MỀM:
- IT/Lập trình viên: Lương cao nhưng rủi ro burnout, cần đa dạng hóa thu nhập (freelance, mentorship, sản phẩm SaaS), đầu tư vào kỹ năng mới (AI, cloud), xây dựng thương hiệu cá nhân trên GitHub/LinkedIn.
- Marketing/Sales: Thu nhập không ổn định, cần tạo quỹ khẩn cấp lớn (6-12 tháng), đa dạng hóa nguồn thu (affiliate, consulting), xây dựng mạng lưới khách hàng, đầu tư vào kỹ năng digital marketing.
- Giáo viên: Lương cố định nhưng thấp, cần tạo thu nhập phụ (gia sư, dạy thêm, tạo khóa học online), đầu tư vào chứng chỉ nâng cao, xây dựng thương hiệu cá nhân trong giáo dục.
- Y tế/Bác sĩ: Lương cao nhưng áp lực lớn, cần bảo hiểm chuyên nghiệp, đầu tư vào quỹ nghỉ hưu sớm, cân bằng sức khỏe tinh thần, đa dạng hóa đầu tư.
- Xây dựng/Kỹ sư: Thu nhập theo dự án, cần tiết kiệm khi có dự án lớn, đầu tư vào kỹ năng quản lý dự án, xây dựng quan hệ với khách hàng, chuẩn bị cho giai đoạn không có dự án.
- Dịch vụ/Nhà hàng: Lương thấp, cần học kỹ năng để thăng tiến (quản lý, mở quán riêng), tiết kiệm đều đặn, tránh chi tiêu quá mức khi có tip, xây dựng quỹ khẩn cấp.
- Bán lẻ/Cửa hàng: Lương thấp, cần học kỹ năng bán hàng, quản lý kho, xây dựng quan hệ với nhà cung cấp, tiết kiệm để mở cửa hàng riêng trong tương lai.
- F&B (Nhà hàng/Quán cafe): Rủi ro cao, cần nghiên cứu kỹ thị trường, bắt đầu nhỏ, tiết kiệm chi phí vận hành, đa dạng hóa menu, xây dựng thương hiệu.
- Vận chuyển/Giao hàng: Lương theo lượng đơn, cần tiết kiệm khi có nhiều đơn, bảo hiểm tai nạn, bảo dưỡng xe thường xuyên, tránh làm việc quá giờ không trả lương.
- Freelancer/Self-employed: Thu nhập không ổn định, cần quỹ khẩn cấp lớn (12 tháng), đa dạng hóa khách hàng, đầu tư vào kỹ năng, xây dựng thương hiệu cá nhân, hợp đồng rõ ràng.
- Networking: Xây dựng mạng lưới quan hệ trong ngành, tham gia sự kiện, kết nối trên LinkedIn, chia sẻ kiến thức để thu hút cơ hội.
- Xây dựng thương hiệu cá nhân: Tạo profile chuyên nghiệp trên LinkedIn, chia sẻ kiến thức trên blog/Social Media, xây dựng uy tín trong ngành, thu hút cơ hội tự nhiên.
- Kỹ năng mềm: Giao tiếp, quản lý thời gian, tư duy phản biện, quản lý cảm xúc, lãnh đạo - những kỹ năng này giúp tăng thu nhập và giảm rủi ro thất nghiệp.

MÔ HÌNH KINH DOANH RỦI RO THẤP VÀ AN TOÀN MXH:
- Mô hình rủi ro thấp: Gửi tiết kiệm ngân hàng kỳ hạn 6-12 tháng (5-6%%/năm), quỹ mở cổ phiếu uy tín (8-15%%/năm dài hạn), vàng miếng (phòng vệ lạm phát), bất động sản nhỏ (dài hạn).
- Kinh doanh online: Bán hàng trên Shopee/Lazada (rủi ro tồn kho thấp), dropshipping (không cần vốn), affiliate marketing (hoa hồng từ sale), tạo khóa học online (thu nhập thụ động).
- Content creator: YouTube (kiếm từ quảng cáo + sponsor), TikTok (livestream bán hàng), Instagram (influencer marketing), Blog (kiếm từ affiliate + quảng cáo). Cần kiên trì xây dựng kênh, không đốt tiền chạy quảng cáo ngay.
- Facebook Business: Bán hàng trên Facebook Marketplace, Group Facebook, Fanpage. Cảnh báo: tránh chạy quảng cáo không có kinh nghiệm, tránh mua like ảo, tránh bán hàng giả mạo.
- TikTok Shop: Livestream bán hàng, video ngắn review sản phẩm. Cảnh báo: cần xây dựng uy tín trước, tránh cam kết lợi nhuận quá cao.
- Affiliate Marketing: Kiếm hoa hồng từ Shopee, Lazada, các network affiliate. Cần chọn sản phẩm uy tín, tránh scam.
- Kinh doanh nhỏ: Mở quán ăn nhỏ, bán đồ ăn vặt, dịch vụ tại nhà (giặt ủi, sửa đồ), bán hàng online. Bắt đầu nhỏ, không vay quá nhiều vốn.
- Việc làm thêm: Gia sư, làm thêm tại quán cafe/nhà hàng, giao hàng Grab/ShopeeFood, freelance (viết bài, thiết kế, lập trình). Cảnh báo: tránh làm việc quá giờ không trả lương, tránh lừa đảo tuyển dụng.
- Cảnh báo lừa đảo trên MXH: Tránh các app cam kết lợi nhuận cao (thường là đa cấp), tránh nộp phí để làm việc, tránh chia sẻ thông tin tài khoản ngân hàng, tránh click link lạ.

TƯ VẤN CHI TIẾT CHO TỪNG NỀN TẢNG MXH:
- Facebook: Bán hàng trên Marketplace (miễn phí), Group Facebook (tìm khách hàng mục tiêu), Fanpage (xây dựng thương hiệu). Cảnh báo: tránh mua like ảo, tránh chạy quảng cáo không có kinh nghiệm, tránh bán hàng giả mạo.
- TikTok: Livestream bán hàng (phù hợp sản phẩm giá rẻ), video ngắn review sản phẩm, TikTok Shop (tích hợp bán hàng). Cảnh báo: cần xây dựng uy tín trước, tránh cam kết lợi nhuận quá cao, tránh mua view ảo.
- YouTube: Kiếm từ quảng cáo (AdSense), sponsor, affiliate marketing trong mô tả video. Cần kiên trì xây dựng kênh, nội dung chất lượng, không đốt tiền chạy quảng cáo ngay.
- Instagram: Influencer marketing (collab với thương hiệu), bán hàng qua Instagram Shop, tạo nội dung visual. Cảnh báo: tránh mua follower ảo, cần xây dựng profile chuyên nghiệp.
- Zalo: Bán hàng qua Zalo Shop, Group Zalo, Zalo OA (tương tác khách hàng). Phù hợp bán hàng B2B, dịch vụ tại địa phương. Cảnh báo: tránh spam tin nhắn, tránh lừa đảo qua Zalo Pay.

EXAMPLES:
"ăn phở 50k" → {"intent":1,"amount":50000,"categoryId":1,"note":"Ăn phở"}
"nhận lương 10 triệu" → {"intent":1,"amount":10000000,"categoryId":15,"note":"Nhận lương"}
"cho bạn vay 2tr" → {"intent":1,"amount":2000000,"categoryId":19,"note":"Cho bạn vay"}
"thu tiền nhà 5tr" → {"intent":1,"amount":5000000,"categoryId":17,"note":"Thu tiền nhà"}
"tháng này tiêu bao nhiêu" → {"intent":2,"reply":"Đang tổng hợp báo cáo giao dịch tháng này."}
"tuần này chi gì" → {"intent":2,"reply":"Đang tổng hợp báo cáo giao dịch tuần này."}
"ngân sách tháng này" → {"intent":3,"reply":"Đang kiểm tra ngân sách tháng này."}
"ngân sách tuần này" → {"intent":3,"reply":"Đang kiểm tra ngân sách tuần này."}
"tình trạng ngân sách" → {"intent":3,"reply":"Đang kiểm tra tình trạng ngân sách."}
"đã vượt ngân sách chưa" → {"intent":3,"reply":"Đang kiểm tra xem có vượt ngân sách không."}
"còn lại bao nhiêu" → {"intent":3,"reply":"Đang kiểm tra số tiền còn lại trong ngân sách."}
"lương 5tr sống sao" → {"intent":4,"reply":"Với 5tr/tháng, bạn có thể áp dụng kế hoạch tài chính thông minh: (1) Thiết yếu 3tr (60%%): nấu ăn tại nhà 1.2tr (~35-40k/ngày), trọ ghép 800-1tr, xăng xe 300-400k, điện-nước-internet 400-500k. (2) Quỹ khẩn cấp 500k (10%%): chuyển đầu tháng sang tài khoản riêng, mục tiêu 15tr trong 2.5 năm. (3) Đầu tư bản thân 500k (10%%): Học kỹ năng mới (IT, freelance, ngoại ngữ) để phát triển thu nhập lên 8-10tr trong 6-12 tháng. (4) Linh hoạt 1tr (20%%): Tối ưu hóa chi tiêu, cắt giảm giải trí không cần thiết. Gợi ý: Mua BHYT 55k/tháng để bảo vệ sức khỏe — mỗi đồng tiết kiệm đều là bước tiến tốt."}
"nhắc tôi trả nợ" → {"intent":5,"reply":"Bạn muốn nhắc nhở vào lúc nào?"}
"lương 8tr gợi ý kế hoạch" → {"intent":4,"reply":"Với lương 8tr/tháng bạn hoàn toàn xây được nền tảng tài chính vững. Phân bổ gợi ý theo 50/30/20:\\n(1) Thiết yếu 4tr (50%%): Trọ 1.5tr, ăn 1.5tr (~50k/ngày), điện-nước-internet 400k, xăng xe 400k, BHYT 55k.\\n(2) Linh hoạt 2.4tr (30%%): giải trí, hẹn hò, mua sắm, quay càphê.\\n(3) Tiết kiệm + Đầu tư 1.6tr (20%%): 1tr quỹ khẩn cấp (mục tiêu 24tr trong 2 năm), 600k DCA quỹ mở hoặc gửi tiết kiệm.\\nNGẮN HẠN (6 tháng): Hoàn thành quỹ khẩn cấp 12tr, mua BHYT.\\nDÀI HẠN (5-10 năm): Tăng thu nhập lên 15-20tr qua kỹ năng (IT/freelance/ngoại ngữ), DCA quỹ mở đều đặn 600k x 10 năm ~200tr, hướng tới mua nhà nhỏ/xe.\\nCảnh báo: Tránh trà sữa/càphê hàng ngày (1.5-3tr/tháng), tránh vay tiêu dùng lãi cao. Tài chính là marathon, không phải sprint."}          
"lương 20tr lập trình viên burnout" → {"intent":4,"reply":"Lương 20tr/tháng là nền tảng tốt để hướng tới tự do tài chính. Phân bổ:\\n(1) Thiết yếu 8tr (40%%), Sinh hoạt 4tr (20%%), Đầu tư 5tr (25%%), Dự phòng 3tr (15%%).\\n(2) Quỹ khẩn cấp 6-12 tháng (70-150tr).\\n(3) DCA quỹ mở 3tr/tháng x 15 năm ~1.2 tỷ (@10%%/năm).\\n(4) Về burnout: Cắt 1 dự án phụ khi đang mệt, đàm phán giờ làm, tránh 'lifestyle creep' lương tăng → chi tăng.\\n(5) DÀI HẠN 10-20 năm: Hướng FIRE (25x chi phí năm), thu nhập thụ động từ đầu tư, xây thương hiệu cá nhân GitHub/LinkedIn để freelance thụ động.\\nKiên trì + kỷ luật = tự do tài chính."}

QUY TẮC REPLY QUAN TRỌNG:
- Tối đa 3-9 dòng cho I4. KHÔNG viết quá dài nhưng phải tư vấn tài chính hợp lý.
- Mỗi reply phải KHÁC BIỆT về cấu trúc và câu chữ so với reply trước.
- KHÔNG bắt đầu reply bằng cùng 1 mẫu (VD: luôn bắt đầu "Với X tr/tháng...").
- Dùng số liệu cụ thể, không nói chung chung.

USER CONTEXT:
Today: %s
Currency: %s
Wallets: %s
Categories (id:name): %s
""";

    // =================================================================================
    // FALLBACK KEYWORD MATCHING - Lưới an toàn khi AI phân loại sai
    // =================================================================================

    // Regex nhận diện số tiền: 50k, 100K, 1tr, 2 triệu, 500000, 1.5tr, 1 ngàn, 1 nghìn
    private static final Pattern AMOUNT_PATTERN = Pattern.compile(
            "(\\d+[.,]?\\d*)\\s*(k|K|tr|triệu|trieu|nghìn|nghin|ngàn|ngan|m|M|đồng|dong|vnd|VND)?",
            Pattern.CASE_INSENSITIVE
    );

    // Danh sách category income (isIncome = true)
    private static final Set<Integer> INCOME_CATEGORIES = Set.of(15, 16, 17, 18, 20, 21);

    // Regex loại trừ date patterns trước khi trích xuất số tiền
    // Match: dd/mm, dd/mm/yyyy, dd-mm, dd-mm-yyyy → bỏ qua (không phải tiền)
    private static final Pattern DATE_NUMBER_PATTERN = Pattern.compile(
            "\\d{1,2}[/\\-]\\d{1,2}(?:[/\\-]\\d{2,4})?", Pattern.CASE_INSENSITIVE
    );
    // Match: "thứ 2", "thứ 5", "thứ 7" → bỏ qua (thứ trong tuần, không phải tiền)
    private static final Pattern ORDINAL_PATTERN = Pattern.compile(
            "thứ\\s+\\d", Pattern.CASE_INSENSITIVE
    );

    /**
     * [1.1] Trích xuất số tiền từ message. Hỗ trợ: 50k, 1tr, 2 triệu, 500000, 1.5M.
     * Loại trừ: date (15/04, 21/03/2026), thứ trong tuần (thứ 5), năm (2024, 2025).
     */
    private BigDecimal extractAmountFromMessage(String message) {
        String msg = message.toLowerCase().trim();

        // Bước 1: Xóa date patterns khỏi message trước khi tìm số tiền
        // VD: "15/04 tôi chi bao nhiêu" → " tôi chi bao nhiêu" (bỏ "15/04")
        String cleaned = DATE_NUMBER_PATTERN.matcher(msg).replaceAll(" ");
        // Bước 2: Xóa "thứ N" (thứ 2, thứ 5, thứ 7)
        cleaned = ORDINAL_PATTERN.matcher(cleaned).replaceAll(" ");
        // Bước 3: Xóa năm đứng riêng (2024, 2025, 2026) — không phải tiền
        cleaned = cleaned.replaceAll("\\b(20\\d{2})\\b", " ");

        Matcher matcher = AMOUNT_PATTERN.matcher(cleaned); // Matcher tìm pattern số tiền trong message
        BigDecimal maxAmount = BigDecimal.ZERO; // Biến lưu số tiền lớn nhất tìm được

        while (matcher.find()) { // Vòng lặp qua tất cả các match pattern số tiền
            try {
                String numStr = matcher.group(1).replace(",", "."); // Lấy phần số, thay dấu phẩy bằng dấu chấm
                double num = Double.parseDouble(numStr); // Chuyển chuỗi sang số double
                String unit = matcher.group(2); // Lấy đơn vị (k, tr, triệu...)

                if (unit != null) { // Nếu có đơn vị → quy đổi sang VND
                    switch (unit.toLowerCase()) {
                        case "k", "nghìn", "nghin", "ngàn", "ngan" -> num *= 1_000; // k, nghìn = x1000
                        case "tr", "triệu", "trieu", "m" -> num *= 1_000_000; // tr, triệu = x1,000,000
                    }
                } else { // Nếu không có đơn vị → chỉ chấp nhận số >= 1000 (tránh match nhầm "thứ 5")
                    if (num < 1000) continue; // Bỏ qua số nhỏ (VD: "5" từ "thứ 5")
                }
                // Lấy số lớn nhất tìm được (tránh match nhầm số nhỏ)
                BigDecimal found = BigDecimal.valueOf(num); // Chuyển sang BigDecimal
                if (found.compareTo(maxAmount) > 0) { // Nếu tìm được số lớn hơn → cập nhật
                    maxAmount = found;
                }
            } catch (NumberFormatException ignored) {} // Bỏ qua lỗi parse số
        }
        return maxAmount.compareTo(BigDecimal.ZERO) > 0 ? maxAmount : null; // Trả số tiền nếu >0, null nếu không tìm thấy
    }

    /**
     * [1.2] Trích xuất note từ message: bỏ số tiền + từ thời gian + đại từ, giữ mô tả chính.
     */
    private String extractNoteFromMessage(String message) {
        // Bỏ phần số tiền và đơn vị (bao gồm ngàn/ngan mới thêm)
        String note = message.replaceAll(
            "\\d+[.,]?\\d*\\s*(k|K|tr|triệu|trieu|nghìn|nghin|ngàn|ngan|m|M|đồng|dong|vnd|VND)?", "").trim();
        // Bỏ từ thời gian đầu câu
        note = note.replaceAll(
            "^(hôm qua|hôm nay|sáng nay|chiều nay|tối nay|tối qua|tuần trước|tháng trước|vừa rồi|mới đây)\\s*", "").trim();
        // Bỏ đại từ chủ ngữ
        note = note.replaceAll(
            "^(tôi|mình|tui|em|anh|chị|bạn|con|ông|bà)\\s*", "").trim();
        // Bỏ trạng từ "vừa", "đã", "mới", "bị"
        note = note.replaceAll(
            "^(vừa|đã|mới|bị|được|có|cần|phải)\\s*", "").trim();
        // Viết hoa chữ đầu
        if (!note.isEmpty()) {
            note = note.substring(0, 1).toUpperCase() + note.substring(1);
        }
        return note; // Trả về rỗng nếu không tìm thấy note (để logic fallback xử lý)
    }

    // =================================================================================
    // 1. TÍCH HỢP CHAT TRỰC TIẾP
    // =================================================================================

    /**
     * [2.1] Xử lý tin nhắn của người dùng gửi cho AI.
     * Bước 1: Kiểm tra xem user có đang trả lời confirm cho action gần nhất không.
     * Bước 2: Lưu tin nhắn User xuống DB.
     * Bước 3: Chuẩn bị System Prompt và lịch sử ngữ cảnh.
     * Bước 4: Gọi Ollama Text API.
     * Bước 5: Parse Json và điều phối theo Intent.
     */
    @Override
    // Không dùng @Transactional ở đây vì Ollama API mất 30-40s → giữ lock quá lâu gây deadlock
    // Mỗi aiRepo.save() tự có transaction ngắn riêng (Spring Data JPA default)
    public AiChatResponse chat(Account account, AiChatRequest request) {
        log.info("[AI] Xử lý tin nhắn chat từ user id = {}", account.getId());

        // Bước 1: Kiểm tra xem user có đang trả lời confirm cho action gần nhất không
        String message = request.message().toLowerCase().trim();
        PendingAction pendingAction = checkPendingAction(account.getId(), message);
        
        if (pendingAction != null) {
            // Bước 1a: User đang trả lời confirm - xử lý action tương ứng
            if (pendingAction.isConfirm) {
                log.info("[AI] User xác nhận action: {}", pendingAction.actionType);
                // Gọi executeAction với params từ action gần nhất
                AiExecuteRequest execRequest = new AiExecuteRequest(pendingAction.actionType, pendingAction.params);
                return executeAction(account, execRequest);
            } else {
                // Bước 1b: User hủy action
                log.info("[AI] User hủy action: {}", pendingAction.actionType);
                AIConversation cancelMsg = createAiReply(account, "Đã hủy thao tác.", AiIntent.GENERAL_CHAT);
                return new AiChatResponse(cancelMsg.getId(), cancelMsg.getMessageContent(), AiIntent.GENERAL_CHAT.getValue(), null, null, null);
            }
        }

        // Bước 2: Lưu tin nhắn User xuống DB
        AIConversation userMsg = AIConversation.builder()
                .account(account)
                .messageContent(request.message())
                .senderType(false)
                .intent(null)
                .attachmentType(request.attachmentType())
                .build();
        aiRepo.save(userMsg);

        // Bước 3: Chuẩn bị System Prompt và lịch sử ngữ cảnh
        String systemPrompt = buildSystemPrompt(account);
        String lowerMsg = request.message().toLowerCase();

        // Bước 3.1: Xác định loại lịch sử chat cần dùng
        List<Map<String, String>> history;
        if (isAdvisoryQuestion(lowerMsg) || isReminderRequest(lowerMsg)) {
            // Nếu là câu hỏi tư vấn hoặc reminder → dùng lịch sử theo intent
            if (isReminderRequest(lowerMsg)) {
                history = buildReminderConversationHistory(account.getId()); // Chỉ 1 tin nhắn cho reminder
            } else {
                history = buildAdvisoryConversationHistory(account.getId()); // 10 tin nhắn intent 4 cho tư vấn
            }
        } else {
            // Mặc định → 5 tin nhắn tất cả intent
            history = buildConversationHistory(account.getId());
        }

        try {
            // Bước 4: Gọi Ollama Text API
            String rawJson = ollamaService.chat(systemPrompt, history, request.message());
            log.info("[AI] ===== RAW RESPONSE =====\n{}", rawJson);

            // Bước 5: Parse Json và trích xuất Intent
            JsonNode parsedJson = AiJsonParserHelper.parseJson(rawJson, objectMapper);
            AiIntent intent = extractIntent(parsedJson, request.message());

            // Bước 6: Điều phối theo Intent và trả về kết quả
            return handleIntent(account, parsedJson, intent, request.message());

        } catch (Exception e) {
            log.error("[AI] Lỗi khi xử lý chat: ", e);
            // Bước 7 (Lỗi): Trả về thông báo lỗi mặc định
            AIConversation aiError = createAiReply(account, "Xin lỗi, hệ thống đang bận. Vui lòng thử lại sau.", AiIntent.GENERAL_CHAT);
            return new AiChatResponse(aiError.getId(), aiError.getMessageContent(), AiIntent.GENERAL_CHAT.getValue(), null, null, null);
        }
    }

    // =================================================================================
    // 3. XỬ LÝ ẢNH & OCR
    // =================================================================================

    /**
     * [3.1] Phân tích hóa đơn OCR hoặc lưu ảnh thường thông qua ReceiptService.
     */
    @Override
    public AiChatResponse uploadReceipt(Account account, MultipartFile imageFile, Integer walletId) {
        // Bước 1: Chuyển tiếp công việc cho ReceiptService xử lý
        return receiptService.processReceipt(account, imageFile, walletId);
    }

    // =================================================================================
    // 4. QUẢN LÝ LỊCH SỬ CHAT
    // =================================================================================

    /**
     * [4.1] Lấy lịch sử theo trang (pagination).
     */
    @Override
    @Transactional(readOnly = true)
    public List<ChatHistoryItem> getChatHistory(Account account, int page, int size) {
        // Bước 1: Cấu hình phân trang
        Pageable pageable = PageRequest.of(page, size);

        // Bước 2: Lấy dữ liệu từ DB theo accountId (đảm bảo bảo mật)
        Page<AIConversation> pageData = aiRepo.findByAccountIdOrderByCreatedAtDesc(account.getId(), pageable);

        // Bước 3: Ánh xạ từ Entity sang DTO
        return pageData.getContent().stream().map(c -> new ChatHistoryItem(
                c.getId(),
                c.getMessageContent(),
                c.getSenderType(),
                AiIntent.fromValue(c.getIntent()),
                c.getAttachmentUrl(),
                c.getAttachmentType(),
                c.getCreatedAt()
        )).collect(Collectors.toList());
    }

    /**
     * [4.2] Xóa mọi lịch sử chat.
     */
    @Override
    @Transactional
    public void clearHistory(Account account) {
        // Bước 1: Validate input
        if (account == null || account.getId() == null) {
            throw new IllegalArgumentException("Invalid account");
        }

        // Bước 2: Lấy tất cả AIConversation của account
        List<AIConversation> conversations = aiRepo.findByAccountId(account.getId());
        if (conversations.isEmpty()) {
            log.info("[AI] Không có lịch sử chat để xóa cho account id={}", account.getId());
            return;
        }

        // Bước 3: Lấy danh sách ID conversation
        List<Integer> conversationIds = conversations.stream()
            .map(AIConversation::getId)
            .toList();

        // Bước 4: Xử lý các Transaction có ai_chat_id liên quan
        // Dùng @Modifying UPDATE query trực tiếp thay vì load entity rồi saveAll (tối ưu hiệu năng)
        transactionRepo.updateAiConversationToNullByConversationIds(conversationIds, account.getId());
        log.info("[AI] Đã update {} transaction liên quan", conversationIds.size());

        // Bước 5: Xóa lịch sử trong DB theo tài khoản
        aiRepo.deleteByAccount(account);
        log.info("[AI] Đã xóa {} lịch sử chat cho account id={}", conversations.size(), account.getId());
    }

    /**
     * [4.3] Xóa một cuộc trò chuyện riêng lẻ theo ID.
     */
    @Override
    @Transactional
    public void deleteConversationById(Integer conversationId, Integer accountId) {
        // Bước 1: Validate input
        if (conversationId == null) {
            throw new IllegalArgumentException("Invalid conversation ID");
        }
        if (accountId == null) {
            throw new IllegalArgumentException("Invalid account ID");
        }

        // Bước 2: Lấy conversation theo ID và accountId (đảm bảo bảo mật - query trực tiếp theo acc_id)
        AIConversation conversation = aiRepo.findByIdAndAccountId(conversationId, accountId)
            .orElseThrow(() -> new SecurityException("You do not have permission to delete this conversation"));

        // Bước 3: Xử lý các Transaction có ai_chat_id liên quan
        // Dùng @Modifying UPDATE query trực tiếp thay vì load entity rồi saveAll (tối ưu hiệu năng)
        transactionRepo.updateAiConversationToNullByConversationIds(List.of(conversationId), accountId);
        log.info("[AI] Đã update transaction liên quan với conversation {}", conversationId);

        // Bước 4: Xóa conversation
        aiRepo.deleteById(conversationId);
        log.info("[AI] Đã xóa conversation id={} cho account id={}", conversationId, accountId);
    }

    // =================================================================================
    // 5. THỰC THI ACTION TRỰC TIẾP
    // =================================================================================

    /**
     * [5.1] Thực thi lệnh từ nút bấm của Client (VD: "Xác nhận tạo giao dịch").
     */
    @Override
    @Transactional
    public AiChatResponse executeAction(Account account, AiExecuteRequest request) {
        String actionType = request.actionType();
        Map<String, Object> params = request.params();

        // Bước 1: Kiểm tra loại hành động
        if ("create_transaction".equals(actionType)) {
            // Bước 2: Thực thi tạo giao dịch
            ActionResult result = executeCreateTransaction(account, params);

            // Bước 3: Lưu phản hồi xác nhận của AI
            AIConversation confirmMsg = createAiReply(account, result.reply(), AiIntent.ADD_TRANSACTION);

            // Bước 4: Trả về kết quả
            return new AiChatResponse(
                    confirmMsg.getId(),
                    result.reply(),
                    AiIntent.ADD_TRANSACTION.getValue(),
                    result.createdId(),
                    null,
                    new AiChatResponse.AiAction("create_transaction", result.success(), params, null)
            );
        }

        // Bước 5 (Lỗi): Quăng ngoại lệ nếu loại hành động không hợp lệ
        throw new IllegalArgumentException("Unsupported action type: " + actionType);
    }

    // =================================================================================
    // 6. PRIVATE HELPERS
    // =================================================================================

    /**
     * [6.1] Tạo và lưu Reply của AI xuống DB (không có params).
     */
    private AIConversation createAiReply(Account account, String message, AiIntent intent) {
        return createAiReply(account, message, intent, null);
    }

    /**
     * [6.1.1] Tạo và lưu Reply của AI xuống DB (có params).
     */
    private AIConversation createAiReply(Account account, String message, AiIntent intent, Map<String, Object> params) {
        // Chuẩn hóa ký tự xuống dòng: thay thế \n\n thành \n
        String normalizedMessage = normalizeLineBreaks(message);

        // Chuyển params sang JSON string nếu có params
        String paramsJson = null;
        if (params != null && !params.isEmpty()) {
            try {
                paramsJson = objectMapper.writeValueAsString(params);
            } catch (Exception e) {
                log.error("[AI] Lỗi khi serialize params: {}", e.getMessage());
            }
        }

        AIConversation aiMsg = AIConversation.builder()
                .account(account)
                .messageContent(normalizedMessage)
                .actionParams(paramsJson) // Lưu params riêng
                .senderType(true)
                .intent(intent.getValue())
                .build();
        return aiRepo.save(aiMsg);
    }

    /**
     * [6.1.1] Chuẩn hóa ký tự xuống dòng: thay thế \n\n thành \n để đồng nhất format.
     */
    private String normalizeLineBreaks(String message) {
        if (message == null || message.isEmpty()) {
            return message;
        }
        // Thay thế tất cả \n\n thành \n
        return message.replaceAll("\n\n", "\n");
    }

    /**
     * [6.2] Tạo Prompt Hệ thống với ngữ cảnh tài khoản người dùng.
     */
    private String buildSystemPrompt(Account account) {
        // Bước 1: Lấy danh sách ví khả dụng
        List<Wallet> wallets = walletRepo.findByAccountId(account.getId()).stream()
                .filter(w -> Boolean.FALSE.equals(w.getDeleted()))
                .toList();
        String walletListStr = wallets.isEmpty() ? "Không có ví nào" : wallets.stream()
                .map(w -> w.getId() + ":" + w.getWalletName())
                .collect(Collectors.joining(", "));

        // Bước 3: Lấy danh mục (hệ thống + user) dạng "id:name" - gọn tokens
        // Backend CategoryMappingService sẽ override nếu AI chọn sai
        String catListStr = categoryRepo.findAll().stream()
                .filter(c -> Boolean.FALSE.equals(c.getDeleted())
                        && (c.getAccount() == null || c.getAccount().getId().equals(account.getId())))
                .map(c -> c.getId() + ":" + c.getCtgName())
                .collect(Collectors.joining("|"));

        // Bước 5: Lấy thông tin thời gian và tiền tệ
        String dateStr = LocalDateTime.now().toString();
        String curr = account.getCurrency() != null ? account.getCurrency().getCurrencyCode() : "VND";

        // Bước 6: Định dạng chuỗi Prompt
        return String.format(AI_SYSTEM_PROMPT, dateStr, curr, walletListStr, catListStr);
    }

    /**
     * [6.3] Lấy tin nhắn gần nhất để đưa vào ngữ cảnh.
     * @param accountId ID của user
     * @param limit Số lượng tin nhắn lấy (mặc định 5)
     * @param intentFilter Filter theo intent (null = lấy tất cả, 4 = chỉ lấy GENERAL_CHAT cho tư vấn)
     */
    private List<Map<String, String>> buildConversationHistory(Integer accountId, int limit, Integer intentFilter) {
        // Bước 1: Lấy tin nhắn theo intent filter nếu có
        List<AIConversation> conversations;
        if (intentFilter != null) {
            conversations = aiRepo.findTop10ByAccountIdAndIntentOrderByCreatedAtDesc(accountId, intentFilter)
                    .stream()
                    .limit(limit)
                    .collect(Collectors.toList());
        } else {
            conversations = aiRepo.findTop10ByAccountIdOrderByCreatedAtDesc(accountId)
                    .stream()
                    .limit(limit)
                    .collect(Collectors.toList());
        }

        // Bước 2: Đảo ngược để cũ trước, mới sau (đúng thứ tự chat tự nhiên)
        java.util.Collections.reverse(conversations);

        // Bước 3: Trả về danh sách định dạng Map
        return conversations.stream().map(c -> Map.of(
                "role", Boolean.TRUE.equals(c.getSenderType()) ? "assistant" : "user",
                "content", c.getMessageContent()
        )).collect(Collectors.toList());
    }

    /**
     * [6.3.1] Lấy tin nhắn gần nhất (mặc định 5, không filter intent).
     */
    private List<Map<String, String>> buildConversationHistory(Integer accountId) {
        return buildConversationHistory(accountId, 5, null);
    }

    /**
     * [6.3.2] Lấy 10 tin nhắn GENERAL_CHAT cho tư vấn.
     */
    private List<Map<String, String>> buildAdvisoryConversationHistory(Integer accountId) {
        return buildConversationHistory(accountId, 10, 4); // Intent 4 = GENERAL_CHAT
    }

    /**
     * [6.3.3] Lấy 1 tin nhắn gần nhất cho reminder.
     */
    private List<Map<String, String>> buildReminderConversationHistory(Integer accountId) {
        return buildConversationHistory(accountId, 1, null);
    }

    /**
     * [6.4] Kiểm tra message có chứa từ hành động giao dịch không.
     * Tránh false positive khi user chỉ nhắc số nhưng không giao dịch (VD: "tôi có 5 người bạn").
     */
    private boolean hasTransactionKeyword(String msg) {
        // Bước 1: Nếu match được category trong CategoryMappingService → chắc chắn là giao dịch
        if (categoryMappingService.mapCategoryFromText(msg) > 0) return true;
        // Bước 2: Kiểm tra các từ hành động thu/chi phổ biến
        String[] actionWords = {
            "mua", "bán", "trả", "thu", "chi", "nộp", "đóng", "sửa", "rửa",
            "ăn", "uống", "đổ xăng", "thuê", "vay", "cho vay", "nhận", "lấy",
            "tặng", "biếu", "gửi", "chuyển", "nạp", "đặt", "book",
            "buy", "sell", "pay", "spend", "earn", "receive", "rent", "order"
        };
        for (String word : actionWords) {
            if (msg.contains(word)) return true;
        }
        return false;
    }

    /**
     * [6.5] Kiểm tra message có phải câu hỏi tư vấn/gợi ý không.
     * Khi là câu tư vấn → KHÔNG ép thành ADD_TRANSACTION dù có số tiền + keyword.
     * VD: "gợi ý kế hoạch chi tiêu lương 5tr" chứa "chi", "lương", "5tr"
     *     nhưng là câu hỏi tư vấn, không phải giao dịch.
     */
    private boolean isAdvisoryQuestion(String msg) {
        // Bỏ '?' — mọi câu hỏi đều có '?' sẽ gây false positive (báo cáo bị nhầm thành tư vấn)
        // Chỉ giữ keyword THỰC SỰ là xin tư vấn/gợi ý/lời khuyên
        String[] advisoryWords = {
            "gợi ý", "kế hoạch", "tư vấn", "lời khuyên", "giúp tôi", "giúp mình",
            "làm sao", "làm thế nào", "như thế nào", "thế nào để", "cách nào",
            "nên làm", "nên mua", "nên chi", "có nên", "có phải", "phải không", "đúng không", "hay không",
            "đủ sống", "đủ xài", "hợp lý không", "tối ưu", "phân bổ",
            "đề xuất", "khuyên", "tiết kiệm sao", "sống sao",
            // So sánh (không phải giao dịch)
            "nhiều hơn", "ít hơn", "so với", "so sánh", "hơn hôm qua", "hơn tuần trước",
            "tăng hay giảm", "có tăng", "có giảm",
            // Tư vấn tiếng Anh
            "advice", "suggest", "recommend", "how to", "should i", "plan for"
        };
        for (String w : advisoryWords) {
            if (msg.contains(w)) return true;
        }
        return false;
    }

    /**
     * [6.5.1] Kiểm tra message có tham chiếu THỜI GIAN CỤ THỂ không.
     * Mục đích: Khi user hỏi "15/04 tôi tiêu bao nhiêu?" → phải query DB theo ngày 15/04,
     * KHÔNG được fallback sang advisory 3 tháng gần nhất.
     * <p>
     * Match: dd/mm, dd/mm/yyyy, range dd/mm-dd/mm, quý X, tháng X/Y, năm 2024,
     * hôm nay, hôm qua, tuần này, tuần trước, tháng này, tháng trước, năm nay, năm ngoái, quý này, quý trước.
     */
    private boolean hasSpecificTimeReference(String msg) {
        // Bước 1: Kiểm tra các pattern ngày/tháng/năm/quý cụ thể bằng regex
        if (DATE_RANGE_PATTERN.matcher(msg).find()) return true; // range dd/mm - dd/mm
        if (SINGLE_DATE_PATTERN.matcher(msg).find()) return true; // ngày dd/mm hoặc dd/mm/yyyy
        if (QUARTER_PATTERN.matcher(msg).find()) return true; // quý 1, quý 2/2024
        if (MONTH_YEAR_PATTERN.matcher(msg).find()) return true; // 12/2025
        if (VN_DATE_PATTERN.matcher(msg).find()) return true; // ngày 1 tháng 4
        if (MONTH_PATTERN.matcher(msg).find()) return true; // tháng 3
        if (YEAR_PATTERN.matcher(msg).find()) return true; // năm 2024, 2021
        // Bước 2: Kiểm tra keyword thời gian tương đối cụ thể
        String[] timeKeywords = {
            "hôm nay", "hôm qua", "tuần này", "tuần trước", "tuần qua",
            "tháng này", "tháng trước", "tháng rồi", "tháng qua",
            "năm nay", "năm ngoái", "năm qua",
            "quý này", "quý trước", "quý qua"
        };
        for (String w : timeKeywords) {
            if (msg.contains(w)) return true;
        }
        return false; // Không có time reference cụ thể
    }

    /**
     * [6.6] Phân tích Intent từ JSON.
     * Fallback: chỉ ép ADD_TRANSACTION khi có SỐ TIỀN + từ hành động giao dịch.
     */
    private AiIntent extractIntent(JsonNode node, String userMessage) {
        String msg = userMessage.toLowerCase().trim();

        // Bước 1: Ưu tiên kiểm tra reminder trước (tránh bị AI trả intent=advisory nhầm)
        if (isReminderRequest(msg)) {
            log.info("[AI] Phát hiện yêu cầu đặt nhắc nhở → GENERAL_CHAT để xử lý reminder.");
            return AiIntent.GENERAL_CHAT;
        }

        // Bước 2: Kiểm tra trước xem message có số tiền không
        BigDecimal fallbackAmount = extractAmountFromMessage(msg);

        // Bước 3: Phát hiện sớm câu hỏi tư vấn (kể cả có số tiền) để không ép ADD_TRANSACTION
        boolean advisory = isAdvisoryQuestion(msg);

        if (node.has("intent")) {
            int intentVal = node.get("intent").asInt();

            // Bước 3: Nếu là câu tư vấn → tôn trọng intent AI trả về (2/3/4), không ép intent=1
            if (advisory && intentVal != 1) {
                log.info("[AI] Phát hiện câu tư vấn, giữ intent AI={} (không ép ADD_TRANSACTION).", intentVal);
                return AiIntent.fromValue(intentVal);
            }

            // Bước 4: AI đồng ý là giao dịch → ADD_TRANSACTION (nhưng không cho phép khi là advisory)
            if (intentVal == 1) {
                if (advisory) {
                    log.warn("[AI] AI trả intent=1 nhưng message là câu tư vấn. Chuyển sang GENERAL_CHAT.");
                    return AiIntent.GENERAL_CHAT;
                }
                return AiIntent.ADD_TRANSACTION;
            }

            // Bước 5: User hỏi ngân sách/hạn mức → VIEW_BUDGET.
            // Guard: chỉ ép khi KHÔNG có số tiền (vì "đặt ngân sách 5tr" là giao dịch, không phải query ngân sách).
            // Ưu tiên: nếu có budget keyword → ép về VIEW_BUDGET ngay cả khi intent=2 (tránh hiển thị report)
            if (fallbackAmount == null && hasBudgetKeyword(msg)) {
                if (intentVal != 3) {
                    log.warn("[AI] Phát hiện câu hỏi ngân sách nhưng intent={}. Ép về VIEW_BUDGET.", intentVal);
                    return AiIntent.VIEW_BUDGET;
                }
            }

            // Bước 6: User hỏi báo cáo/thống kê → VIEW_REPORT.
            // Guard: chỉ ép khi KHÔNG có số tiền (vì "ăn sáng tháng này 50k" là giao dịch, không phải báo cáo).
            // Guard: chỉ ép khi KHÔNG có budget keyword (ưu tiên budget keyword ở Bước 5)
            if (fallbackAmount == null && hasReportKeyword(msg) && !hasBudgetKeyword(msg)) {
                if (intentVal != 2) {
                    log.warn("[AI] Phát hiện câu hỏi báo cáo nhưng intent={}. Ép về VIEW_REPORT.", intentVal);
                    return AiIntent.VIEW_REPORT;
                }
            }

            // Bước 7: FALLBACK - AI trả intent≠1 nhưng message có số tiền + từ hành động
            if (fallbackAmount != null && hasTransactionKeyword(msg)) {
                log.warn("[AI] FALLBACK: AI trả intent={} nhưng phát hiện giao dịch (amount={}).",
                        intentVal, fallbackAmount);
                return AiIntent.ADD_TRANSACTION;
            }

            return AiIntent.fromValue(intentVal);
        }

        // Bước 8: AI không trả intent → kiểm tra budget keywords
        if (fallbackAmount == null && hasBudgetKeyword(msg)) {
            log.warn("[AI] FALLBACK: Không có intent nhưng phát hiện câu hỏi ngân sách.");
            return AiIntent.VIEW_BUDGET;
        }

        // Bước 9: AI không trả intent → kiểm tra report keywords
        if (fallbackAmount == null && hasReportKeyword(msg)) {
            log.warn("[AI] FALLBACK: Không có intent nhưng phát hiện câu hỏi báo cáo.");
            return AiIntent.VIEW_REPORT;
        }

        // Bước 10: AI không trả intent nhưng message có số tiền + từ hành động (và không phải tư vấn)
        if (!advisory && fallbackAmount != null && hasTransactionKeyword(msg)) {
            log.warn("[AI] FALLBACK: Không có intent. Phát hiện giao dịch (amount={}).", fallbackAmount);
            return AiIntent.ADD_TRANSACTION;
        }

        return AiIntent.GENERAL_CHAT;
    }

    /**
     * [6.7] Kiểm tra message có chứa từ khóa báo cáo/thống kê không.
     * VD: "tháng này tôi tiêu bao nhiêu", "tuần trước chi gì", "năm nay thu chi"
     */
    private boolean hasReportKeyword(String msg) {
        // Bước 1: Từ khóa hỏi thống kê/báo cáo
        String[] reportWords = {
            "bao nhiêu", "thống kê", "báo cáo", "tổng kết", "report",
            "tổng chi", "tổng thu", "chi bao nhiêu", "thu bao nhiêu",
            "tiêu bao nhiêu", "xài bao nhiêu", "chi tiêu bao nhiêu",
            "tổng cộng", "summary", "tiêu hết", "xài hết"
        };
        for (String w : reportWords) {
            if (msg.contains(w)) return true;
        }
        // Bước 2: Kết hợp "thời gian + hỏi" (VD: "tháng này tôi chi gì", "15/04 chi gì")
        boolean hasTimeRef = msg.contains("tháng này") || msg.contains("tuần này") || msg.contains("hôm nay")
                || msg.contains("hôm qua") || msg.contains("tháng trước") || msg.contains("tuần trước")
                || msg.contains("năm nay") || msg.contains("năm ngoái") || msg.contains("quý này")
                || SINGLE_DATE_PATTERN.matcher(msg).find() || DATE_RANGE_PATTERN.matcher(msg).find();
        boolean hasAskWord = msg.contains("chi gì") || msg.contains("tiêu gì") || msg.contains("mua gì")
                || msg.contains("thu gì") || msg.contains("giao dịch") || msg.contains("lịch sử")
                || msg.contains("chi những gì") || msg.contains("tiêu những gì") || msg.contains("mua những gì")
                || msg.contains("thu những gì") || msg.contains("những gì");
        return hasTimeRef && hasAskWord;
    }

    /**
     * [6.8] Kiểm tra message có chứa từ khóa ngân sách/hạn mức không.
     * VD: "ngân sách tháng này", "tình trạng ngân sách", "đã vượt ngân sách chưa", "còn lại bao nhiêu"
     */
    private boolean hasBudgetKeyword(String msg) {
        // Bước 1: Từ khóa ngân sách/hạn mức (tránh từ khóa dễ lẫn lộn)
        String[] budgetWords = {
            "ngân sách", "vượt ngân sách", "hạn mức", "budget",
            "tình trạng ngân sách", "đã vượt ngân sách", "ngân sách tháng này", "ngân sách tuần này"
        };
        for (String w : budgetWords) {
            if (msg.contains(w)) return true;
        }
        return false;
    }

    // Regex parse ngày dd/mm hoặc dd/mm/yyyy
    private static final Pattern SINGLE_DATE_PATTERN = Pattern.compile(
            "(\\d{1,2})[/\\-](\\d{1,2})(?:[/\\-](\\d{4}))?");
    // Regex parse custom range: dd/mm/yyyy - dd/mm/yyyy (hỗ trợ -, đến, to, tới)
    private static final Pattern DATE_RANGE_PATTERN = Pattern.compile(
            "(\\d{1,2})[/\\-](\\d{1,2})(?:[/\\-](\\d{4}))?\\s*(?:-|–|đến|tới|to)\\s*(\\d{1,2})[/\\-](\\d{1,2})(?:[/\\-](\\d{4}))?");

    // Regex cho parseReminderTime: giờ cụ thể (5h20, 17:30)
    private static final Pattern HOUR_MIN_PATTERN_H = Pattern.compile("(\\d{1,2})h(\\d{2})?");
    private static final Pattern HOUR_MIN_PATTERN_COLON = Pattern.compile("(\\d{1,2}):(\\d{2})");
    // Regex cho parseReminderTime: ngày cụ thể (dd/mm/yyyy, dd/mm)
    private static final Pattern DATE_PATTERN_FULL = Pattern.compile("(\\d{1,2})[/-](\\d{1,2})[/-](\\d{4})");
    private static final Pattern DATE_PATTERN_SHORT = Pattern.compile("(\\d{1,2})[/-](\\d{1,2})(?![/-])");

    // Regex cho parseDateRangeFromMessage: khoảng tương đối, ngày VN, quý, tháng/năm, tháng, năm
    private static final Pattern RELATIVE_PATTERN = Pattern.compile("(?<!thứ )(\\d+)\\s*(tháng|tuần|năm|ngày)\\s*(gần nhất|gần đây|qua|trước|vừa rồi|nay|gần)", Pattern.CASE_INSENSITIVE);
    private static final Pattern VN_DATE_PATTERN = Pattern.compile("(?:ngày\\s+)?(\\d{1,2})\\s+tháng\\s+(\\d{1,2})(?:\\s+(\\d{4}))?");
    // Regex hỗ trợ format "ngày X tháng Y năm Z" (VD: ngày 15 tháng 2 năm 2026)
    private static final Pattern DATE_YEAR_VN_PATTERN = Pattern.compile("(?:ngày\\s+)?(\\d{1,2})\\s+tháng\\s+(\\d{1,2})\\s+năm\\s+(20\\d{2})");
    private static final Pattern QUARTER_PATTERN = Pattern.compile("(?:qu[ýy]|quarter|q)\\s*(\\d)(?:[/\\-\\s](\\d{4}))?", Pattern.CASE_INSENSITIVE);
    private static final Pattern MONTH_YEAR_PATTERN = Pattern.compile("(?:^|\\s)(\\d{1,2})/(\\d{4})(?:\\s|$|[^/])");
    private static final Pattern MONTH_PATTERN = Pattern.compile("(?:tháng|month)\\s+(\\d{1,2})(?:[/\\-\\s](\\d{4}))?", Pattern.CASE_INSENSITIVE);
    // Regex hỗ trợ format "tháng X năm Y" (VD: tháng 2 năm 2026)
    private static final Pattern MONTH_YEAR_VN_PATTERN = Pattern.compile("(?:tháng|month)\\s+(\\d{1,2})\\s+năm\\s+(20\\d{2})", Pattern.CASE_INSENSITIVE);
    private static final Pattern YEAR_PATTERN = Pattern.compile("(?:năm\\s+)?(20\\d{2})");
    private static final Pattern MONTH_PATTERN_ADVISORY = Pattern.compile("(\\d+)\\s*tháng");

    /**
     * [6.8] Phân tích khoảng thời gian từ message tự nhiên bằng DateUtils.
     * Hỗ trợ:
     * - Custom range: "21/03/2026 - 20/04/2026", "21/03 đến 20/04"
     * - N khoảng tương đối: "3 tháng gần nhất", "2 tuần qua", "7 ngày trước"
     * - Thứ trong tuần: "chủ nhật", "thứ hai", "thứ 5 tuần trước"
     * - Ngày tiếng Việt: "ngày 1 tháng 4", "1 tháng 4 2025"
     * - Tương đối: hôm nay, hôm qua, tuần này/trước, tháng này/trước, quý, năm...
     * - Quý cụ thể: "quý 1 2025", "quý 2/2025"
     * - Tháng/Năm: "12/2025", "tháng 12 2025"
     * - Tháng cụ thể: "tháng 3", "month 11/2026"
     * - Năm cụ thể: "năm 2024", "2021"
     * - Ngày cụ thể: "15/04", "16/03/2026"
     * Trả về [startDate, endDate]. Mặc định: tháng này.
     */
    private LocalDateTime[] parseDateRangeFromMessage(String msg) {
        // Bước 1: Custom date range (ưu tiên cao nhất vì cụ thể nhất)
        // VD: "21/03/2026 - 20/04/2026", "21/03 đến 20/04", "1/1 to 31/1"
        Matcher rangeMatcher = DATE_RANGE_PATTERN.matcher(msg);
        if (rangeMatcher.find()) {
            try {
                int d1 = Integer.parseInt(rangeMatcher.group(1));
                int m1 = Integer.parseInt(rangeMatcher.group(2));
                int y1 = rangeMatcher.group(3) != null ? Integer.parseInt(rangeMatcher.group(3)) : java.time.LocalDate.now().getYear();
                int d2 = Integer.parseInt(rangeMatcher.group(4));
                int m2 = Integer.parseInt(rangeMatcher.group(5));
                int y2 = rangeMatcher.group(6) != null ? Integer.parseInt(rangeMatcher.group(6)) : java.time.LocalDate.now().getYear();
                java.time.LocalDate start = java.time.LocalDate.of(y1, m1, d1);
                java.time.LocalDate end = java.time.LocalDate.of(y2, m2, d2);
                return new LocalDateTime[]{DateUtils.getStartOfDay(start), DateUtils.getEndOfDay(end)};
            } catch (Exception e) {
                log.warn("[AI] Không parse được date range: {}", msg);
            }
        }

        // Bước 2: Thứ trong tuần (PHẢI check TRƯỚC N tương đối)
        // Lý do: "thứ 5 tuần trước" sẽ bị regex N tương đối match nhầm "5 tuần trước"
        java.time.DayOfWeek targetDay = parseDayOfWeek(msg);
        if (targetDay != null) {
            java.time.LocalDate today = java.time.LocalDate.now();
            java.time.LocalDate target;

            // Nếu có "tuần trước" hoặc "tuần qua" → tính ngày thứ đó trong tuần trước
            if (msg.contains("tuần trước") || msg.contains("tuần qua")) {
                // Tìm thứ 2 của tuần trước
                java.time.LocalDate mondayLastWeek = today.minusWeeks(1).with(java.time.DayOfWeek.MONDAY);
                // Tính ngày thứ đó từ thứ 2 tuần trước
                target = mondayLastWeek.plusDays(targetDay.getValue() - 1);
            }
            // Nếu có "tuần này" → tính ngày thứ đó trong tuần này
            else if (msg.contains("tuần này")) {
                java.time.LocalDate mondayThisWeek = today.with(java.time.DayOfWeek.MONDAY);
                target = mondayThisWeek.plusDays(targetDay.getValue() - 1);
            }
            // Nếu chỉ có tên thứ (VD: "thứ tư") → tìm ngày thứ đó gần nhất (có thể là hôm nay hoặc tuần trước)
            else {
                target = today;
                // Tìm ngày thứ đó gần nhất (lùi về quá khứ)
                for (int i = 0; i < 7; i++) {
                    if (target.getDayOfWeek() == targetDay) break;
                    target = target.minusDays(1);
                }
            }
            return new LocalDateTime[]{DateUtils.getStartOfDay(target), DateUtils.getEndOfDay(target)};
        }

        // Bước 3: Khoảng N tương đối: "3 tháng gần nhất", "2 tuần qua", "7 ngày trước"
        // (?<!thứ ) = negative lookbehind: bỏ qua "thứ 5 tuần trước" (đã xử lý ở Bước 2)
        Matcher relMatcher = RELATIVE_PATTERN.matcher(msg);
        if (relMatcher.find()) {
            int n = Integer.parseInt(relMatcher.group(1));
            String unit = relMatcher.group(2);
            java.time.LocalDate now = java.time.LocalDate.now();
            java.time.LocalDate start = switch (unit) {
                case "ngày" -> now.minusDays(n);
                case "tuần" -> now.minusWeeks(n);
                case "năm" -> now.minusYears(n);
                default -> now.minusMonths(n); // tháng
            };
            return new LocalDateTime[]{DateUtils.getStartOfDay(start), DateUtils.getEndOfToday()};
        }

        // Bước 4: Ngày tiếng Việt
        // 4.1: Ưu tiên format "ngày X tháng Y năm Z" (VD: ngày 15 tháng 2 năm 2026)
        Matcher dvnMatcher = DATE_YEAR_VN_PATTERN.matcher(msg);
        if (dvnMatcher.find()) {
            try {
                int day = Integer.parseInt(dvnMatcher.group(1));
                int month = Integer.parseInt(dvnMatcher.group(2));
                int year = Integer.parseInt(dvnMatcher.group(3));
                java.time.LocalDate date = java.time.LocalDate.of(year, month, day);
                return new LocalDateTime[]{DateUtils.getStartOfDay(date), DateUtils.getEndOfDay(date)};
            } catch (Exception e) {
                log.warn("[AI] Không parse được ngày tiếng Việt (có năm): {}", msg);
            }
        }

        // 4.2: Hỗ trợ format "ngày 1 tháng 4", "1 tháng 4", "1 tháng 4 2025"
        // Phải check TRƯỚC "tháng X" vì "1 tháng 4" cũng chứa "tháng 4"
        Matcher vnDateMatcher = VN_DATE_PATTERN.matcher(msg);
        if (vnDateMatcher.find()) {
            try {
                int day = Integer.parseInt(vnDateMatcher.group(1));
                int month = Integer.parseInt(vnDateMatcher.group(2));
                int year = vnDateMatcher.group(3) != null ? Integer.parseInt(vnDateMatcher.group(3)) : java.time.LocalDate.now().getYear();
                java.time.LocalDate date = java.time.LocalDate.of(year, month, day);
                return new LocalDateTime[]{DateUtils.getStartOfDay(date), DateUtils.getEndOfDay(date)};
            } catch (Exception e) {
                log.warn("[AI] Không parse được ngày tiếng Việt: {}", msg);
            }
        }

        // Bước 5: Mốc tương đối phổ biến
        if (msg.contains("hôm nay") || msg.contains("today")) {
            return new LocalDateTime[]{DateUtils.getStartOfToday(), DateUtils.getEndOfToday()};
        }
        if (msg.contains("hôm qua") || msg.contains("yesterday")) {
            java.time.LocalDate yesterday = java.time.LocalDate.now().minusDays(1);
            return new LocalDateTime[]{DateUtils.getStartOfDay(yesterday), DateUtils.getEndOfDay(yesterday)};
        }
        if (msg.contains("tuần trước") || msg.contains("tuần qua") || msg.contains("last week")) {
            return DateUtils.getLastWeek();
        }
        if (msg.contains("tuần này") || msg.contains("this week")) {
            return DateUtils.getThisWeek();
        }
        if (msg.contains("tháng trước") || msg.contains("tháng qua") || msg.contains("last month")) {
            return DateUtils.getLastMonth();
        }
        if (msg.contains("tháng này") || msg.contains("this month")) {
            return DateUtils.getThisMonth();
        }
        if (msg.contains("quý trước") || msg.contains("quý vừa rồi") || msg.contains("last quarter")) {
            return DateUtils.getLastQuarter();
        }
        if (msg.contains("quý này") || msg.contains("this quarter")) {
            return DateUtils.getThisQuarter();
        }
        if (msg.contains("năm trước") || msg.contains("năm ngoái") || msg.contains("last year")) {
            return DateUtils.getLastYear();
        }
        if (msg.contains("năm nay") || msg.contains("this year")) {
            return DateUtils.getThisYear();
        }
        if (msg.contains("tương lai") || msg.contains("sắp tới") || msg.contains("future")) {
            return DateUtils.getFuture();
        }

        // Bước 6: Quý cụ thể "quý 1", "quý 2/2025", "quý 1 2025", "quarter 1/2025", "Q1"
        // Hỗ trợ cả space, /, - giữa quý và năm
        Matcher qMatcher = QUARTER_PATTERN.matcher(msg);
        if (qMatcher.find()) {
            int quarter = Integer.parseInt(qMatcher.group(1));
            int year = qMatcher.group(2) != null ? Integer.parseInt(qMatcher.group(2)) : java.time.LocalDate.now().getYear();
            if (quarter >= 1 && quarter <= 4) return DateUtils.getSpecificQuarter(quarter, year);
        }

        // Bước 7: Tháng/Năm dạng "12/2025", "3/2024" (mm/yyyy, không có ngày)
        // Phải check TRƯỚC "tháng X" vì "tháng 12 2025" sẽ match ở bước 8
        Matcher myMatcher = MONTH_YEAR_PATTERN.matcher(msg);
        if (myMatcher.find()) {
            int month = Integer.parseInt(myMatcher.group(1));
            int year = Integer.parseInt(myMatcher.group(2));
            if (month >= 1 && month <= 12) return DateUtils.getSpecificMonth(month, year);
        }

        // Bước 8: Tháng cụ thể "tháng 3", "tháng 12/2024", "tháng 12 2025", "month 11/2026"
        // 8.1: Ưu tiên format "tháng X năm Y" (VD: tháng 2 năm 2026)
        Matcher mvnMatcher = MONTH_YEAR_VN_PATTERN.matcher(msg);
        if (mvnMatcher.find()) {
            int month = Integer.parseInt(mvnMatcher.group(1));
            int year = Integer.parseInt(mvnMatcher.group(2));
            if (month >= 1 && month <= 12) return DateUtils.getSpecificMonth(month, year);
        }

        // 8.2: Hỗ trợ format "tháng X", "tháng X/YYYY", "tháng X-YYYY", "tháng X YYYY"
        Matcher mMatcher = MONTH_PATTERN.matcher(msg);
        if (mMatcher.find()) {
            int month = Integer.parseInt(mMatcher.group(1));
            int year = mMatcher.group(2) != null ? Integer.parseInt(mMatcher.group(2)) : java.time.LocalDate.now().getYear();
            if (month >= 1 && month <= 12) return DateUtils.getSpecificMonth(month, year);
        }

        // Bước 9: Ngày cụ thể "15/04", "16/03/2026" (dd/mm hoặc dd/mm/yyyy) - Ưu tiên trước năm cụ thể
        Matcher dateMatcher = SINGLE_DATE_PATTERN.matcher(msg);
        if (dateMatcher.find()) {
            try {
                int day = Integer.parseInt(dateMatcher.group(1));
                int month = Integer.parseInt(dateMatcher.group(2));
                int year = dateMatcher.group(3) != null ? Integer.parseInt(dateMatcher.group(3)) : java.time.LocalDate.now().getYear();
                java.time.LocalDate date = java.time.LocalDate.of(year, month, day);
                return new LocalDateTime[]{DateUtils.getStartOfDay(date), DateUtils.getEndOfDay(date)};
            } catch (Exception e) {
                log.warn("[AI] Không parse được ngày cụ thể: {}", msg);
            }
        }

        // Bước 10: Năm cụ thể "năm 2024", "2021" - Chỉ match khi không có ngày cụ thể
        Matcher yMatcher = YEAR_PATTERN.matcher(msg);
        if (yMatcher.find()) {
            int year = Integer.parseInt(yMatcher.group(1));
            return DateUtils.getSpecificYear(year);
        }

        // Mặc định: tháng này
        return DateUtils.getThisMonth();
    }

    /**
     * [6.9] Parse thứ trong tuần từ message tiếng Việt.
     * Trả về DayOfWeek hoặc null nếu không match.
     */
    private java.time.DayOfWeek parseDayOfWeek(String msg) {
        if (msg.contains("chủ nhật") || msg.contains("chu nhat")) return java.time.DayOfWeek.SUNDAY;
        if (msg.contains("thứ hai") || msg.contains("thứ 2") || msg.contains("thu hai")) return java.time.DayOfWeek.MONDAY;
        if (msg.contains("thứ ba") || msg.contains("thứ 3") || msg.contains("thu ba")) return java.time.DayOfWeek.TUESDAY;
        if (msg.contains("thứ tư") || msg.contains("thứ 4") || msg.contains("thu tu")) return java.time.DayOfWeek.WEDNESDAY;
        if (msg.contains("thứ năm") || msg.contains("thứ 5") || msg.contains("thu nam")) return java.time.DayOfWeek.THURSDAY;
        if (msg.contains("thứ sáu") || msg.contains("thứ 6") || msg.contains("thu sau")) return java.time.DayOfWeek.FRIDAY;
        if (msg.contains("thứ bảy") || msg.contains("thứ 7") || msg.contains("thu bay")) return java.time.DayOfWeek.SATURDAY;
        return null;
    }

    /**
     * [6.10] Tạo reply báo cáo thật từ DB: tổng thu, tổng chi, top 3 category chi nhiều nhất.
     * Dùng TransactionRepository query trực tiếp, trả reply bằng tiếng Việt.
     */
    private String buildReportReply(Account account, String userMessage) {
        try {
            String msg = userMessage.toLowerCase().trim();
            LocalDateTime[] dates = parseDateRangeFromMessage(msg);
            LocalDateTime startDate = dates[0];
            LocalDateTime endDate = dates[1];

            // Bước 1: Nếu user hỏi có từ khóa ngân sách → luôn gọi buildBudgetReply
            // để trả về theo ngân sách category thay vì tổng toàn bộ
            if (hasBudgetKeyword(msg)) {
                log.info("[AI] Phát hiện từ khóa ngân sách trong message, gọi buildBudgetReply");
                return buildBudgetReply(account, userMessage);
            }

            // Bước 2: Không có từ khóa ngân sách → Query tổng thu/chi trong khoảng thời gian
            List<CategoryReportDTO> catReports =
                    transactionService.getCategoryReport(account.getId(), startDate, endDate, null, null);

            BigDecimal totalIncome = BigDecimal.ZERO; // Tổng thu nhập trong khoảng thời gian
            BigDecimal totalExpense = BigDecimal.ZERO; // Tổng chi tiêu trong khoảng thời gian
            List<CategoryReportDTO> topExpenses = new ArrayList<>(); // Danh sách category chi tiêu để tìm top

            for (var r : catReports) { // Vòng lặp qua từng category report
                if (Boolean.TRUE.equals(r.categoryType())) { // Nếu là category thu nhập
                    totalIncome = totalIncome.add(r.totalAmount()); // Cộng vào tổng thu
                } else { // Nếu là category chi tiêu
                    totalExpense = totalExpense.add(r.totalAmount()); // Cộng vào tổng chi
                    topExpenses.add(r); // Thêm vào danh sách để tìm top
                }
            }

            // Bước 2: Sắp xếp top chi tiêu cao nhất
            topExpenses.sort((a, b) -> b.totalAmount().compareTo(a.totalAmount())); // Sắp xếp giảm dần theo số tiền

            // Bước 3: Xác định nhãn thời gian để reply thân thiện
            String timeLabel = detectTimeLabel(msg);

            // Bước 4: Build reply thân thiện
            StringBuilder sb = new StringBuilder();
            sb.append(String.format("📊 Báo cáo %s:\n", timeLabel));
            sb.append(String.format("• Tổng thu: %,.0f đ\n", totalIncome));
            sb.append(String.format("• Tổng chi: %,.0f đ\n", totalExpense));
            BigDecimal net = totalIncome.subtract(totalExpense);
            sb.append(String.format("• Còn lại: %,.0f đ\n", net));

            if (!topExpenses.isEmpty()) {
                sb.append("\n🔥 Top chi tiêu nhiều nhất:\n");
                int count = Math.min(5, topExpenses.size());
                for (int i = 0; i < count; i++) {
                    var r = topExpenses.get(i);
                    sb.append(String.format("  %d. %s: %,.0f đ", i + 1, r.categoryName(), r.totalAmount()));
                    if (r.percentage() != null && r.percentage() > 0) {
                        sb.append(String.format(" (%.0f%%)", r.percentage()));
                    }
                    sb.append("\n");
                }
            }

            // Bước 5: Thêm gợi ý nếu chi nhiều hơn thu
            if (totalExpense.compareTo(totalIncome) > 0) {
                sb.append("\n⚠️ Bạn đang chi nhiều hơn thu! Cần cắt giảm chi tiêu hoặc tăng thu nhập.");
            } else if (totalIncome.compareTo(BigDecimal.ZERO) > 0) {
                BigDecimal saveRate = net.multiply(BigDecimal.valueOf(100)).divide(totalIncome, 0, java.math.RoundingMode.HALF_UP);
                sb.append(String.format("\n💰 Tỷ lệ tiết kiệm: %,.0f%% thu nhập.", saveRate));
                if (saveRate.intValue() < 20) {
                    sb.append(" Nên nhắm ≥20% để tích lũy hiệu quả.");
                }
            }

            if (totalIncome.compareTo(BigDecimal.ZERO) == 0 && totalExpense.compareTo(BigDecimal.ZERO) == 0) {
                return String.format("Bạn chưa có giao dịch nào trong %s.", timeLabel);
            }

            return sb.toString();
        } catch (Exception e) {
            log.error("[AI] Lỗi build report reply: ", e);
            return "Tôi chưa thể lấy dữ liệu báo cáo. Bạn thử hỏi lại với khoảng thời gian cụ thể (tháng này, tuần này)?";
        }
    }

    /**
     * [6.13] Query ngân sách và tư vấn chi tiêu.
     * Xử lý 2 dạng ngân sách: all_categories=true/false
     * Query transaction không lấy deleted.
     */
    private String buildBudgetReply(Account account, String userMessage) {
        try {
            log.info("[AI] buildBudgetReply - userMessage: {}", userMessage);

            // Bước 1: Parse thời gian từ message
            String msg = userMessage.toLowerCase().trim();
            LocalDateTime[] dates = parseDateRangeFromMessage(msg);
            LocalDateTime startDate = dates[0];
            LocalDateTime endDate = dates[1];
            log.info("[AI] Parsed date range: {} - {}", startDate, endDate);

            // Bước 1.5: Parse budgetType từ message
            final fpt.aptech.server.enums.budget.BudgetType budgetTypeFilter;
            if (msg.contains("tuần") || msg.contains("week")) {
                budgetTypeFilter = fpt.aptech.server.enums.budget.BudgetType.WEEKLY;
                log.info("[AI] Detected budgetType: WEEKLY");
            } else if (msg.contains("tháng") || msg.contains("month")) {
                budgetTypeFilter = fpt.aptech.server.enums.budget.BudgetType.MONTHLY;
                log.info("[AI] Detected budgetType: MONTHLY");
            } else if (msg.contains("năm") || msg.contains("year")) {
                budgetTypeFilter = fpt.aptech.server.enums.budget.BudgetType.YEARLY;
                log.info("[AI] Detected budgetType: YEARLY");
            } else {
                budgetTypeFilter = null; // Nếu không có từ khóa → không filter theo budgetType (lấy tất cả)
            }

            // Bước 2: Lấy ngân sách active của user trong khoảng thời gian
            // Query trực tiếp từ repository (bypass check walletId của BudgetService)
            List<fpt.aptech.server.entity.Budget> budgetEntities =
                budgetRepo.getBudgets(account.getId().longValue(), startDate.toLocalDate(), null);
            log.info("[AI] Total budgets: {}", budgetEntities.size());

            // Lọc ngân sách theo thời gian
            LocalDate startLocal = startDate.toLocalDate();
            LocalDate endLocal = endDate.toLocalDate();
            List<fpt.aptech.server.entity.Budget> filteredBudgets = budgetEntities.stream()
                .filter(b -> {
                    try {
                        boolean timeMatch = !b.getBeginDate().isAfter(endLocal) && !b.getEndDate().isBefore(startLocal);
                        // Filter thêm theo budgetType nếu có
                        // Cho phép ngân sách có budgetType = NULL match với bất kỳ budgetTypeFilter nào
                        // (vì ngân sách cũ không có budgetType được set)
                        boolean typeMatch = budgetTypeFilter == null || b.getBudgetType() == null || b.getBudgetType() == budgetTypeFilter;
                        return timeMatch && typeMatch;
                    } catch (Exception e) {
                        log.error("[AI] Lỗi filter budget: {}", e.getMessage());
                        return false;
                    }
                })
                .toList();
            log.info("[AI] Filtered budgets: {}", filteredBudgets.size());

            if (filteredBudgets.isEmpty()) {
                log.info("[AI] Không có ngân sách trong khoảng thời gian {} - {}", startLocal, endLocal);
                return String.format("Bạn chưa có ngân sách cho khoảng thời gian này (%s - %s). Bạn có ngân sách cho các tháng: 2/2026, 3/2026, 4/2026.", startLocal, endLocal);
            }

            // Convert sang DTO để dùng các computed fields (spentAmount, remainingAmount, etc.)
            // toBudgetResponse là private → dùng getBudgetById() thay thế
            List<fpt.aptech.server.dto.budget.BudgetResponse> activeBudgets = filteredBudgets.stream()
                .map(b -> budgetService.getBudgetById(b.getId(), account.getId()))
                .toList();

            // Bước 3: Build reply tư vấn cho từng ngân sách
            StringBuilder sb = new StringBuilder();
            sb.append(String.format("💰 Ngân sách (%s - %s):\n", startLocal, endLocal));

            for (var budget : activeBudgets) {
                try {
                    // Bước 3.1: Tính toán chi tiêu (đã có trong BudgetResponse DTO)
                    BigDecimal spent = budget.getSpentAmount();
                    BigDecimal remaining = budget.getRemainingAmount();
                    BigDecimal progress = budget.getProgress();
                    boolean exceeded = budget.getExceeded();
                    boolean warning = budget.getWarning();
                    long daysLeft = java.time.temporal.ChronoUnit.DAYS.between(
                        java.time.LocalDate.now(), budget.getEndDate());
                    if (daysLeft < 0) daysLeft = 0;
                    
                    BigDecimal dailyShould = budget.getDailyShouldSpend();
                    BigDecimal dailyActual = budget.getDailyActualSpend();
                    BigDecimal projected = budget.getProjectedSpend();

                    // Bước 3.2: Kiểm tra ngân sách quá khứ vs hiện tại/tương lai
                    boolean isExpiredBudget = budget.getEndDate().isBefore(java.time.LocalDate.now());

                    // Bước 3.3: Build reply cho ngân sách này
                    String categoryLabel = budget.getAllCategories() ? "Tất cả danh mục" :
                        budget.getCategories().stream()
                            .map(c -> c.ctgName())
                            .collect(java.util.stream.Collectors.joining(", "));

                    sb.append(String.format("\n📌 %s (%s) [%s]:\n",
                        budget.getWalletName() != null ? budget.getWalletName() : "Tất cả ví",
                        categoryLabel,
                        budget.getBudgetType() != null ? budget.getBudgetType().name() : "CUSTOM"));
                    sb.append(String.format("• Ngân sách: %,.0f đ\n", budget.getAmount()));
                    sb.append(String.format("• Đã chi: %,.0f đ (%.0f%%)\n", spent, progress.multiply(BigDecimal.valueOf(100))));
                    sb.append(String.format("• Còn lại: %,.0f đ\n", remaining));
                    sb.append(String.format("• Chi trung bình/ngày: %,.0f đ\n", dailyActual));

                    // Chỉ hiển thị dự kiến chi tiêu và gợi ý nếu ngân sách chưa hết hạn
                    if (!isExpiredBudget) {
                        sb.append(String.format("• Dự kiến chi tiêu hết kỳ: %,.0f đ\n", projected));
                    }

                    // Bước 3.4: Tư vấn dựa trên tình trạng ngân sách
                    if (exceeded) {
                        sb.append(String.format("⚠️ Đã vượt ngân sách %,.0f đ! Cần cắt giảm chi tiêu ngay.\n",
                            spent.subtract(budget.getAmount())));
                    } else if (warning) {
                        sb.append(String.format("⚠️ Có nguy cơ vượt ngân sách! Nếu tiếp tục chi như hiện tại (%,.0f đ/ngày), bạn sẽ vượt ngân sách.\n",
                            dailyActual));
                        // Chỉ hiển thị gợi ý nếu ngân sách chưa hết hạn
                        if (!isExpiredBudget && daysLeft > 0) {
                            sb.append(String.format("💡 Gợi ý: Chỉ nên chi tối đa %,.0f đ/ngày trong %d ngày còn lại.\n",
                                dailyShould, daysLeft));
                        }
                    } else {
                        sb.append("✅ Chi tiêu trong tầm kiểm soát.\n");
                        // Chỉ hiển thị gợi ý nếu ngân sách chưa hết hạn
                        if (!isExpiredBudget && daysLeft > 0 && remaining.compareTo(BigDecimal.ZERO) > 0) {
                            sb.append(String.format("💡 Gợi ý: Bạn có thể chi tối đa %,.0f đ/ngày trong %d ngày còn lại.\n",
                                dailyShould, daysLeft));
                        }
                    }

                    // Bước 3.5: Tư vấn category chi nhiều nhất (nếu all_categories=false)
                    if (!budget.getAllCategories() && !budget.getCategories().isEmpty()) {
                        // Query transaction của ngân sách này để tìm category chi nhiều nhất
                        List<TransactionResponse> transactions = budgetService.getBudgetTransactions(
                            budget.getId(), account.getId());
                        
                        // Group by category
                        java.util.Map<Integer, BigDecimal> categorySpending = new java.util.HashMap<>();
                        for (var t : transactions) {
                            if (t.categoryId() != null && !t.categoryType()) { // categoryType true=thu, false=chi
                                categorySpending.merge(t.categoryId(), t.amount(), BigDecimal::add);
                            }
                        }
                        
                        // Tìm category chi nhiều nhất
                        var topCategory = categorySpending.entrySet().stream()
                            .max(java.util.Map.Entry.comparingByValue());
                        
                        if (topCategory.isPresent()) {
                            Integer catId = topCategory.get().getKey();
                            BigDecimal catAmount = topCategory.get().getValue();
                            var cat = categoryRepo.findById(catId).orElse(null);
                            if (cat != null) {
                                sb.append(String.format("🔥 Chi nhiều nhất: %s (%,.0f đ)\n", 
                                    cat.getCtgName(), catAmount));
                            }
                        }
                    }
                } catch (Exception e) {
                    log.error("[AI] Lỗi xử lý budget {}: {}", budget.getId(), e.getMessage());
                    sb.append(String.format("\n⚠️ Không thể hiển thị ngân sách này (lỗi: %s)\n", e.getMessage()));
                }
            }

            return sb.toString();
        } catch (Exception e) {
            log.error("[AI] Lỗi build budget reply: ", e);
            return String.format("Tôi chưa thể lấy dữ liệu ngân sách. Lỗi: %s. Bạn thử hỏi lại với khoảng thời gian cụ thể (tháng này, tuần này)?", e.getMessage());
        }
    }

    /**
     * [6.11] Xác định nhãn thời gian từ message để hiển thị đẹp trong reply.
     * Match cùng thứ tự ưu tiên với parseDateRangeFromMessage.
     */
    private String detectTimeLabel(String msg) {
        // Custom range
        Matcher rangeMatcher = DATE_RANGE_PATTERN.matcher(msg);
        if (rangeMatcher.find()) {
            String from = rangeMatcher.group(1) + "/" + rangeMatcher.group(2)
                    + (rangeMatcher.group(3) != null ? "/" + rangeMatcher.group(3) : "");
            String to = rangeMatcher.group(4) + "/" + rangeMatcher.group(5)
                    + (rangeMatcher.group(6) != null ? "/" + rangeMatcher.group(6) : "");
            return "từ " + from + " đến " + to;
        }

        // Thứ trong tuần (check TRƯỚC N tương đối — cùng thứ tự với parseDateRangeFromMessage)
        java.time.DayOfWeek dow = parseDayOfWeek(msg);
        if (dow != null) {
            String dayName = switch (dow) {
                case MONDAY -> "thứ Hai"; case TUESDAY -> "thứ Ba"; case WEDNESDAY -> "thứ Tư";
                case THURSDAY -> "thứ Năm"; case FRIDAY -> "thứ Sáu"; case SATURDAY -> "thứ Bảy";
                case SUNDAY -> "Chủ Nhật";
            };
            if (msg.contains("tuần trước") || msg.contains("tuần qua")) dayName += " tuần trước";
            else if (msg.contains("tuần này")) dayName += " tuần này";
            return dayName;
        }

        // N khoảng tương đối (lookbehind tránh match "thứ 5 tuần trước")
        Matcher relMatcher = RELATIVE_PATTERN.matcher(msg);
        if (relMatcher.find()) return relMatcher.group(1) + " " + relMatcher.group(2) + " " + relMatcher.group(3);

        // Ngày tiếng Việt: "1 tháng 4", "ngày 1 tháng 4 2025"
        Matcher vnDateMatcher = VN_DATE_PATTERN.matcher(msg);
        if (vnDateMatcher.find()) {
            String yr = vnDateMatcher.group(3) != null ? "/" + vnDateMatcher.group(3) : "";
            return "ngày " + vnDateMatcher.group(1) + "/" + vnDateMatcher.group(2) + yr;
        }

        // Mốc tương đối
        if (msg.contains("hôm nay") || msg.contains("today")) return "hôm nay";
        if (msg.contains("hôm qua") || msg.contains("yesterday")) return "hôm qua";
        if (msg.contains("tuần trước") || msg.contains("tuần qua")) return "tuần trước";
        if (msg.contains("tuần này")) return "tuần này";
        if (msg.contains("tháng trước") || msg.contains("tháng qua")) return "tháng trước";
        if (msg.contains("tháng này")) return "tháng này";
        if (msg.contains("quý trước") || msg.contains("quý vừa rồi")) return "quý trước";
        if (msg.contains("quý này")) return "quý này";
        if (msg.contains("năm trước") || msg.contains("năm ngoái")) return "năm trước";
        if (msg.contains("năm nay")) return "năm nay";
        if (msg.contains("tương lai") || msg.contains("sắp tới")) return "tương lai";

        // Quý cụ thể (hỗ trợ space)
        Matcher qMatcher = QUARTER_PATTERN.matcher(msg);
        if (qMatcher.find()) {
            String yr = qMatcher.group(2) != null ? "/" + qMatcher.group(2) : "";
            return "quý " + qMatcher.group(1) + yr;
        }
        // Tháng/Năm dạng mm/yyyy
        Matcher myMatcher = MONTH_YEAR_PATTERN.matcher(msg);
        if (myMatcher.find()) return "tháng " + myMatcher.group(1) + "/" + myMatcher.group(2);
        // Tháng cụ thể (hỗ trợ space)
        Matcher mMatcher = MONTH_PATTERN.matcher(msg);
        if (mMatcher.find()) {
            String yr = mMatcher.group(2) != null ? "/" + mMatcher.group(2) : "";
            return "tháng " + mMatcher.group(1) + yr;
        }
        // Ngày cụ thể dd/mm - Ưu tiên trước năm cụ thể để tránh match nhầm
        Matcher dateMatcher = SINGLE_DATE_PATTERN.matcher(msg);
        if (dateMatcher.find()) {
            String yr = dateMatcher.group(3) != null ? "/" + dateMatcher.group(3) : "";
            return "ngày " + dateMatcher.group(1) + "/" + dateMatcher.group(2) + yr;
        }
        // Năm cụ thể - Chỉ match khi không có ngày cụ thể
        Matcher yMatcher = YEAR_PATTERN.matcher(msg);
        if (yMatcher.find()) return "năm " + yMatcher.group(1);

        return "tháng này"; // Default
    }

    /**
     * [6.12] Điều hướng xử lý theo Intent.
     * Có FALLBACK cho ADD_TRANSACTION: dùng Java keyword matching khi AI trả thiếu dữ liệu.
     */
    private AiChatResponse handleIntent(Account account, JsonNode node, AiIntent intent, String userMessage) {
        String reply = "Tôi đã hiểu yêu cầu.";
        String displayReply = null; // Reply sạch gửi Flutter (không chứa ACTION_PARAMS)
        AiChatResponse.AiAction action = null;
        String lowerMsg = userMessage.toLowerCase().trim();

        // Bước 0: CHỈ ép GENERAL_CHAT khi AI trả sai intent=ADD_TRANSACTION nhưng message là tư vấn
        // KHÔNG override VIEW_REPORT/VIEW_BUDGET vì user có thể hỏi báo cáo có time cụ thể
        // VD: "15/04 tôi tiêu bao nhiêu?" → VIEW_REPORT (không phải advisory)
        if (isAdvisoryQuestion(lowerMsg) && intent == AiIntent.ADD_TRANSACTION) {
            log.info("[AI] Câu tư vấn nhưng AI trả ADD_TRANSACTION → ép GENERAL_CHAT.");
            intent = AiIntent.GENERAL_CHAT;
        }
        // Ưu tiên: nếu có time cụ thể + report keyword → VIEW_REPORT (không phải advisory)
        // VD: "6/2024 tôi chi những gì?", "hôm qua tôi tiêu bao nhiêu?", "quý 1/2023 chi gì?"
        else if (hasSpecificTimeReference(lowerMsg) && hasReportKeyword(lowerMsg)
                 && intent != AiIntent.ADD_TRANSACTION) {
            log.info("[AI] Phát hiện time cụ thể + report keyword → ép VIEW_REPORT (không advisory).");
            intent = AiIntent.VIEW_REPORT;
        }

        // Bước 1: Xử lý theo từng loại Intent
        switch (intent) {
            case ADD_TRANSACTION -> {
                // Trích xuất dữ liệu từ AI response
                BigDecimal amount = new BigDecimal(node.path("amount").asText("0")); // Số tiền từ AI
                Integer categoryId = node.path("categoryId").asInt(0); // Category ID từ AI
                String note = node.path("note").asText(""); // Note mô tả từ AI
                // isIncome KHÔNG lấy từ AI — backend tự suy ra từ category.ctgType (DB là nguồn chuẩn)
                boolean isIncome; // true=thu nhập, false=chi tiêu

                // VALIDATE: Java regex tìm số tiền trong message gốc — nếu không có thì coi như amount = null
                // Lý do: AI hay đoán bừa (VD: "hôm nay tôi đi ăn phở" → AI trả 50000 mặc dù message không có số)
                BigDecimal javaAmount = extractAmountFromMessage(userMessage); // Tìm số tiền bằng Java regex
                if (javaAmount != null) { // Nếu Java tìm thấy số tiền
                    amount = javaAmount; // Ưu tiên Java tìm được (độ tin cậy hơn AI)
                    log.info("[AI] Java regex tìm thấy amount: {}", amount);
                } else { // Nếu Java không tìm thấy
                    amount = BigDecimal.ZERO; // Coi như không có số tiền
                    log.info("[AI] Java regex KHÔNG tìm thấy số tiền → coi như amount = 0 (bỏ qua AI đoán)");
                }

                // Guard: nếu vẫn không có amount → từ chối tạo giao dịch
                if (amount.compareTo(BigDecimal.ZERO) <= 0) { // Nếu amount <= 0
                    reply = "Bạn muốn ghi nhận giao dịch bao nhiêu tiền? (VD: 50k, 1tr, 200 nghìn)"; // Hỏi lại số tiền
                    AIConversation askAmountMsg = createAiReply(account, reply, AiIntent.GENERAL_CHAT); // Lưu tin nhắn AI
                    return new AiChatResponse(askAmountMsg.getId(), reply, AiIntent.GENERAL_CHAT.getValue(), null, null, null); // Trả response
                }

                // ƯU TIÊN Java keyword matching (chính xác hơn AI đoán bừa).
                // Nếu Java không match → KHÔNG tin AI (hay hallucinate VD "fffsf 50k" → Insurance),
                // dùng default OTHER_EXPENSE (3) để user chỉnh sau trong picker.
                int javaCat = categoryMappingService.mapCategoryFromText(userMessage); // Tìm category bằng Java keyword
                if (javaCat > 0) { // Nếu Java match được category
                    log.info("[AI] Java keyword matched categoryId: {} (AI trả: {})", javaCat, categoryId);
                    categoryId = javaCat; // Dùng category từ Java
                } else { // Nếu Java không match được
                    // Fallback: nếu message chỉ là số tiền → lấy category từ message user gần nhất trước đó
                    // VD: "hôm nay tôi đi ăn phở" → AI hỏi số tiền → user trả "350k" → cần lấy category "Food & Beverage" từ message trước
                    List<AIConversation> recentUserMsgs = aiRepo.findTop5ByAccountIdAndSenderTypeOrderByCreatedAtDesc(account.getId(), false); // Lấy 5 tin nhắn user gần nhất
                    if (!recentUserMsgs.isEmpty()) { // Nếu có tin nhắn trước
                        for (AIConversation prevMsg : recentUserMsgs) { // Vòng lặp qua từng tin nhắn trước
                            int prevCat = categoryMappingService.mapCategoryFromText(prevMsg.getMessageContent()); // Tìm category trong tin nhắn trước
                            if (prevCat > 0) { // Nếu tìm thấy
                                categoryId = prevCat; // Dùng category từ tin nhắn trước
                                log.info("[AI] Fallback categoryId từ message trước: {}", categoryId);
                                break; // Dừng vòng lặp khi tìm được
                            }
                        }
                    }
                    if (categoryId == 0) { // Nếu vẫn không có category
                        log.info("[AI] Không match keyword và không tìm thấy category từ message trước → dùng default=3.");
                        categoryId = 3; // Default: Other Expenses
                    }
                }

                // FALLBACK note: luôn dùng Java trích xuất từ message gốc
                // Lý do: AI hay hallucinate thêm từ (VD: "tiền nhà 50k" → AI note="Thu tiền nhà")
                String javaNote = extractNoteFromMessage(userMessage); // Trích note bằng Java
                // Bước 1: Ưu tiên note từ Java nếu tìm thấy trong message hiện tại
                if (!javaNote.isEmpty()) { // Nếu Java tìm được note
                    note = javaNote; // Dùng note từ Java
                    log.info("[AI] Sử dụng note từ Java extract: {}", note);
                }
                // Bước 2: Nếu Java không tìm thấy note (message chỉ là số tiền) → lấy note từ message user gần nhất trước đó
                if (note.isEmpty()) { // Nếu note rỗng
                    List<AIConversation> recentUserMsgs = aiRepo.findTop5ByAccountIdAndSenderTypeOrderByCreatedAtDesc(account.getId(), false); // Lấy 5 tin nhắn user gần nhất
                    if (!recentUserMsgs.isEmpty()) { // Nếu có tin nhắn trước
                        for (AIConversation prevMsg : recentUserMsgs) { // Vòng lặp qua từng tin nhắn trước
                            String prevNote = extractNoteFromMessage(prevMsg.getMessageContent()); // Trích note từ tin nhắn trước
                            if (!prevNote.isEmpty()) { // Nếu tìm được note
                                note = prevNote; // Dùng note từ tin nhắn trước
                                log.info("[AI] Fallback note từ message trước: {}", note);
                                break; // Dừng vòng lặp khi tìm được
                            }
                        }
                    }
                }
                // Bước 3: Nếu vẫn không có note → dùng default từ AI hoặc để rỗng
                if (note.isEmpty()) { // Nếu note vẫn rỗng
                    note = node.path("note").asText(""); // Dùng note từ AI
                    log.info("[AI] Sử dụng note từ AI (default): {}", note);
                }

                // Xác định isIncome TỪ DB: category.ctgType (true=thu nhập, false=chi tiêu)
                // Đây là nguồn chuẩn duy nhất, không phụ thuộc AI
                Category catForIncome = categoryRepo.findById(categoryId).orElse(null); // Lấy category từ DB
                if (catForIncome != null && catForIncome.getCtgType() != null) { // Nếu tìm thấy category
                    isIncome = Boolean.TRUE.equals(catForIncome.getCtgType()); // Dùng ctgType từ DB
                } else { // Nếu không tìm thấy category
                    // Fallback: dùng set cứng nếu load DB thất bại
                    isIncome = INCOME_CATEGORIES.contains(categoryId); // Kiểm tra trong set cứng
                }

                // Lấy danh sách ví của user
                List<Wallet> wallets = walletRepo.findByAccountId(account.getId()).stream() // Query ví theo account
                        .filter(w -> Boolean.FALSE.equals(w.getDeleted())) // Lọc ví chưa xóa
                        .toList(); // Chuyển thành List

                // Lọc ví thỏa mãn số tiền cho giao dịch chi (expense)
                List<Wallet> validWallets = new ArrayList<>(); // Danh sách ví đủ tiền
                if (!isIncome) { // Nếu là giao dịch chi
                    final BigDecimal finalAmount = amount; // Biến final cho lambda
                    validWallets = wallets.stream() // Stream qua các ví
                        .filter(w -> w.getBalance().compareTo(finalAmount) >= 0) // Chỉ lấy ví đủ số dư
                        .toList(); // Chuyển thành List
                } else { // Nếu là giao dịch thu
                    validWallets = wallets; // Tất cả ví đều hợp lệ
                }

                // Auto-detect: nếu user gõ tên ví trong message → set sẵn id
                // VD: "ăn phở 50k ví MB Bank" → walletId=10 (bỏ qua auto select)
                Integer matchedWalletId = wallets.stream() // Stream qua các ví
                        .filter(w -> w.getWalletName() != null // Ví có tên
                                && lowerMsg.contains(w.getWalletName().toLowerCase())) // Message chứa tên ví
                        .map(Wallet::getId) // Lấy ID
                        .findFirst().orElse(null); // Lấy cái đầu tiên hoặc null

                // Nếu user không chỉ định ví rõ ràng, tự động chọn ví đầu tiên thỏa mãn
                if (matchedWalletId == null && !validWallets.isEmpty()) { // Nếu không có ví được chọn và có ví hợp lệ
                    matchedWalletId = validWallets.get(0).getId(); // Chọn ví đầu tiên
                }

                Map<String, Object> params = new HashMap<>(); // Map lưu params cho giao dịch
                params.put("amount", amount); // Lưu số tiền
                params.put("categoryId", categoryId); // Lưu category ID
                params.put("note", note); // Lưu note
                params.put("isIncome", isIncome); // Lưu loại thu/chi

                if (matchedWalletId != null) { // Nếu có ví được chọn
                    params.put("walletId", matchedWalletId); // Lưu wallet ID
                } else { // Nếu không có ví nào đủ tiền cho khoản chi
                    reply = "Số dư trong các ví của bạn không đủ để thực hiện giao dịch này."; // Thông báo lỗi
                    AIConversation askAmountMsg = createAiReply(account, reply, AiIntent.GENERAL_CHAT); // Lưu tin nhắn AI
                    return new AiChatResponse(askAmountMsg.getId(), reply, AiIntent.GENERAL_CHAT.getValue(), null, null, null); // Trả response lỗi
                }

                // Lưu params dưới dạng JSON để dùng khi user confirm
                String paramsJson; // Chuỗi JSON params
                try { // Thử serialize params sang JSON
                    paramsJson = objectMapper.writeValueAsString(params); // Serialize
                } catch (Exception e) { // Nếu lỗi
                    log.error("[AI] Lỗi khi serialize params: {}", e.getMessage()); // Log lỗi
                    paramsJson = "{}"; // Dùng JSON rỗng
                }

                // displayReply = reply sạch gửi Flutter (không chứa JSON)
                String categoryName = categoryRepo.findById(categoryId) // Lấy category từ DB
                        .map(Category::getCtgName) // Lấy tên category
                        .orElse("Khác"); // Fallback: "Khác"

                String sourceName = null; // Tên ví
                if (matchedWalletId != null) { // Nếu có wallet ID
                    Integer finalWalletId = matchedWalletId; // Biến final cho lambda
                    sourceName = wallets.stream().filter(w -> w.getId().equals(finalWalletId)) // Tìm ví theo ID
                            .map(Wallet::getWalletName).findFirst().orElse(null); // Lấy tên ví
                }

                if (sourceName != null) { // Nếu có tên ví
                    displayReply = String.format( // Format reply có tên ví
                        "Bạn muốn ghi nhận %s %,.0f đ cho mục '%s' từ ví '%s' đúng không?",
                        isIncome ? "Khoản thu" : "Khoản chi", // Loại giao dịch
                        amount.doubleValue(), categoryName, sourceName); // Số tiền, category, ví
                } else { // Nếu không có tên ví
                    displayReply = String.format( // Format reply không có tên ví
                        "Bạn muốn ghi nhận %s %,.0f đ cho mục '%s' đúng không?",
                        isIncome ? "Khoản thu" : "Khoản chi", // Loại giao dịch
                        amount.doubleValue(), categoryName); // Số tiền, category
                }
                // reply lưu DB = displayReply text đẹp (không nhùng JSON params)
                reply = displayReply;

                action = new AiChatResponse.AiAction("create_transaction", false, params, List.of("Xác nhận", "Hủy")); // Tạo action
            }
            case VIEW_REPORT -> {
                // Query giao dịch thật từ DB theo khoảng thời gian user nói
                reply = buildReportReply(account, userMessage);
            }
            case VIEW_BUDGET -> {
                // Query ngân sách thật từ DB và tư vấn
                reply = buildBudgetReply(account, userMessage);
            }
            case GENERAL_CHAT -> {
                // Ưu tiên 1: Kiểm tra yêu cầu đặt nhắc nhở
                if (isReminderRequest(lowerMsg)) {
                    log.info("[AI] Phát hiện yêu cầu đặt nhắc nhở.");
                    reply = handleReminder(account, userMessage);
                    break;
                }

                // Ưu tiên 2: Dùng AI reply trước (để AI có thể trả lời gợi ý như prompt)
                reply = node.path("reply").asText("");

                // Ưu tiên 3: Nếu là câu tư vấn + KHÔNG có time cụ thể → build advisory từ DB (3 tháng gần nhất)
                // Nếu user hỏi có time cụ thể → đã route về VIEW_REPORT ở bước 0 rồi, ko vào đây
                if (isAdvisoryQuestion(lowerMsg) && !hasSpecificTimeReference(lowerMsg) && hasReportKeyword(lowerMsg)) {
                    log.info("[AI] Câu tư vấn KHÔNG có time cụ thể → build advisory từ DB (3 tháng).");
                    String advisoryReply = buildAdvisoryReply(account, userMessage);
                    if (advisoryReply != null) {
                        reply = advisoryReply;
                    }
                }
                // Ưu tiên 3b: Nếu reply rỗng + có report keyword → fallback advisory
                else if (reply.trim().isEmpty() && hasReportKeyword(lowerMsg)) {
                    log.info("[AI] AI reply rỗng + có report keyword → fallback advisory.");
                    String advisoryReply = buildAdvisoryReply(account, userMessage);
                    if (advisoryReply != null) {
                        reply = advisoryReply;
                    }
                }

                // Nếu reply rỗng hoặc bị nhiễu JSON → log để debug
                // Không coi error từ parser là rỗng (đã fallback raw text)
                if (reply.trim().isEmpty()
                    || (reply.contains("intent") && !reply.contains("Parse JSON"))
                    || (reply.contains("{") && !reply.contains("Parse JSON"))) {

                    log.warn("[AI] GENERAL_CHAT reply rỗng! Raw JSON: {}", node);
                    reply = "Xin lỗi, tôi chưa hiểu rõ ý bạn. Bạn có thể nói cụ thể hơn không?";
                }
            }
        }

        // Bước 2: Lưu reply với params riêng vào DB
        AIConversation aiMsg = createAiReply(account, reply, intent, (intent == AiIntent.ADD_TRANSACTION && action != null) ? action.params() : null);

        // Bước 3: Trả displayReply sạch cho Flutter (không lộ JSON)
        return new AiChatResponse(
                aiMsg.getId(),
                displayReply != null ? displayReply : reply,
                intent.getValue(),
                null,
                null,
                action
        );
    }

    // =================================================================================
    // GỢI Ý TÀI CHÍNH CÁ NHÂN HÓA (ADVISORY)
    // =================================================================================

    /**
     * [7.1] Build gợi ý tài chính dựa trên DATA THỰC từ DB.
     * Công thức thế giới: 50/30/20 Rule (Needs/Wants/Savings).
     * Bước 1: Query 3 tháng gần nhất → tính trung bình thu/chi mỗi tháng
     * Bước 2: Query tháng hiện tại → so sánh với trung bình
     * Bước 3: Tìm top 5 category chi nhiều nhất → cảnh báo nếu >20% tăng
     * Bước 4: Tính daily budget = còn lại / ngày còn lại trong tháng
     * Bước 5: Đề xuất cắt giảm cụ thể theo 50/30/20
     */
    private String buildAdvisoryReply(Account account, String userMessage) {
        try {
            String msg = userMessage.toLowerCase().trim();
            java.time.LocalDate today = java.time.LocalDate.now();

            // Bước 1: Parse số tiền từ user message (VD: "mức lương 5tr", "lương 5 triệu")
            BigDecimal userProvidedIncome = extractAmountFromMessage(msg);
            boolean useUserIncome = userProvidedIncome != null && userProvidedIncome.compareTo(BigDecimal.ZERO) > 0;

            // Bước 2: Xác định khoảng thời gian advisory (user nói gì thì parse, mặc định 3 tháng)
            int monthsToAnalyze = 3;
            Matcher relM = MONTH_PATTERN_ADVISORY.matcher(msg);
            if (relM.find()) {
                int n = Integer.parseInt(relM.group(1));
                if (n >= 1 && n <= 12) monthsToAnalyze = n;
            }

            // Bước 3: Query 3 tháng gần nhất — lấy tổng thu/chi theo category MỖI tháng
            BigDecimal totalIncome3m = BigDecimal.ZERO; // Tổng thu nhập trong N tháng
            BigDecimal totalExpense3m = BigDecimal.ZERO; // Tổng chi tiêu trong N tháng
            Map<String, BigDecimal> catExpenseTotal = new LinkedHashMap<>(); // Map category → tổng chi N tháng

            for (int i = 1; i <= monthsToAnalyze; i++) { // Vòng lặp qua từng tháng (1, 2, 3...)
                java.time.LocalDate monthStart = today.minusMonths(i).withDayOfMonth(1); // Ngày đầu tháng i
                java.time.LocalDate monthEnd = monthStart.plusMonths(1).minusDays(1); // Ngày cuối tháng i
                LocalDateTime start = DateUtils.getStartOfDay(monthStart); // Start of day
                LocalDateTime end = DateUtils.getEndOfDay(monthEnd); // End of day

                List<CategoryReportDTO> reports = transactionService.getCategoryReport(
                        account.getId(), start, end, null, null); // Query report cho tháng i
                for (var r : reports) { // Vòng lặp qua từng category trong tháng
                    if (Boolean.TRUE.equals(r.categoryType())) { // Nếu là category thu nhập
                        totalIncome3m = totalIncome3m.add(r.totalAmount()); // Cộng vào tổng thu
                    } else { // Nếu là category chi tiêu
                        totalExpense3m = totalExpense3m.add(r.totalAmount()); // Cộng vào tổng chi
                        catExpenseTotal.merge(r.categoryName(), r.totalAmount(), BigDecimal::add); // Gộp theo category
                    }
                }
            }

            // Bước 3: Tính trung bình mỗi tháng (hoặc dùng số tiền user cung cấp)
            BigDecimal avgMonthlyIncome = useUserIncome ? userProvidedIncome : totalIncome3m.divide(BigDecimal.valueOf(monthsToAnalyze), 0, java.math.RoundingMode.HALF_UP); // Thu trung bình/tháng
            BigDecimal avgMonthlyExpense = totalExpense3m.divide(BigDecimal.valueOf(monthsToAnalyze), 0, java.math.RoundingMode.HALF_UP); // Chi trung bình/tháng

            // Bước 4: Query tháng hiện tại
            LocalDateTime[] thisMonth = DateUtils.getThisMonth(); // Lấy khoảng thời gian tháng này
            List<CategoryReportDTO> currentReports = transactionService.getCategoryReport(
                    account.getId(), thisMonth[0], thisMonth[1], null, null); // Query report tháng này

            BigDecimal curIncome = BigDecimal.ZERO; // Thu nhập tháng hiện tại
            BigDecimal curExpense = BigDecimal.ZERO; // Chi tiêu tháng hiện tại
            Map<String, BigDecimal> curCatExpense = new LinkedHashMap<>(); // Map category → chi tháng này
            for (var r : currentReports) { // Vòng lặp qua từng category tháng này
                if (Boolean.TRUE.equals(r.categoryType())) { // Nếu là category thu nhập
                    curIncome = curIncome.add(r.totalAmount()); // Cộng vào thu tháng này
                } else { // Nếu là category chi tiêu
                    curExpense = curExpense.add(r.totalAmount()); // Cộng vào chi tháng này
                    curCatExpense.put(r.categoryName(), r.totalAmount()); // Lưu vào map
                }
            }

            // Bước 5: So sánh từng category vs trung bình 3 tháng
            Map<String, BigDecimal> catAvg = new LinkedHashMap<>(); // Map category → chi trung bình/tháng
            for (var entry : catExpenseTotal.entrySet()) { // Vòng lặp qua từng category
                catAvg.put(entry.getKey(), entry.getValue().divide(BigDecimal.valueOf(monthsToAnalyze), 0, java.math.RoundingMode.HALF_UP)); // Tính trung bình
            }

            // Top 5 category chi nhiều nhất (3 tháng)
            List<Map.Entry<String, BigDecimal>> topCats = catAvg.entrySet().stream() // Stream các entry
                    .sorted((a, b) -> b.getValue().compareTo(a.getValue())) // Sắp xếp giảm dần
                    .limit(5) // Chỉ lấy 5 cái đầu
                    .toList(); // Chuyển thành List

            // Bước 6: Tính ngày còn lại + daily budget
            int dayOfMonth = today.getDayOfMonth(); // Ngày hiện tại trong tháng (VD: 15)
            int daysInMonth = today.lengthOfMonth(); // Tổng số ngày trong tháng (VD: 30)
            int daysRemaining = daysInMonth - dayOfMonth; // Số ngày còn lại trong tháng
            BigDecimal remaining = avgMonthlyIncome.compareTo(BigDecimal.ZERO) > 0 // Nếu thu > 0
                    ? avgMonthlyIncome.subtract(curExpense) // Còn lại = thu - chi hiện tại
                    : BigDecimal.ZERO; // Nếu thu = 0 → còn lại = 0
            BigDecimal dailyBudget = daysRemaining > 0 // Nếu còn ngày
                    ? remaining.divide(BigDecimal.valueOf(daysRemaining), 0, java.math.RoundingMode.HALF_UP) // Ngân sách/ngày
                    : BigDecimal.ZERO; // Nếu không còn ngày → 0

            // Bước 7: Xác định mức thu nhập → áp dụng 50/30/20
            BigDecimal incomeRef = avgMonthlyIncome.compareTo(BigDecimal.ZERO) > 0 ? avgMonthlyIncome : curIncome; // Dùng thu TB hoặc thu hiện tại
            BigDecimal needs = incomeRef.multiply(BigDecimal.valueOf(0.50)); // 50% thiết yếu (ăn, ở, đi lại)
            BigDecimal wants = incomeRef.multiply(BigDecimal.valueOf(0.30)); // 30% linh hoạt (giải trí, mua sắm)
            BigDecimal savings = incomeRef.multiply(BigDecimal.valueOf(0.20)); // 20% tiết kiệm (đầu tư, quỹ)

            // Bước 6.1: Tính daily budget theo 50/30/20
            BigDecimal dailyNeeds = incomeRef.multiply(BigDecimal.valueOf(0.50)) // Thiết yếu/ngày
                    .divide(BigDecimal.valueOf(daysInMonth), 0, java.math.RoundingMode.HALF_UP);
            BigDecimal dailyWants = incomeRef.multiply(BigDecimal.valueOf(0.30)) // Linh hoạt/ngày
                    .divide(BigDecimal.valueOf(daysInMonth), 0, java.math.RoundingMode.HALF_UP);
            BigDecimal dailySavings = incomeRef.multiply(BigDecimal.valueOf(0.20)) // Tiết kiệm/ngày
                    .divide(BigDecimal.valueOf(daysInMonth), 0, java.math.RoundingMode.HALF_UP);

            // Bước 8: Build reply (rút gọn, tập trung thông tin chính)
            StringBuilder sb = new StringBuilder();
            String incomeSource = useUserIncome ? "theo mức lương bạn cung cấp" : String.format("%d tháng gần nhất", monthsToAnalyze);
            sb.append(String.format("📊 **Phân tích tài chính %s:**\n", incomeSource));
            sb.append(String.format("• Thu nhập: %,.0f đ/tháng\n", avgMonthlyIncome));
            sb.append(String.format("• Chi tiêu TB: %,.0f đ/tháng\n", avgMonthlyExpense));

            // Tỷ lệ tiết kiệm
            BigDecimal saveRate = BigDecimal.ZERO;
            if (avgMonthlyIncome.compareTo(BigDecimal.ZERO) > 0) {
                saveRate = avgMonthlyIncome.subtract(avgMonthlyExpense)
                        .multiply(BigDecimal.valueOf(100))
                        .divide(avgMonthlyIncome, 0, java.math.RoundingMode.HALF_UP);
                sb.append(String.format("• Tỷ lệ tiết kiệm: %d%%\n", saveRate.intValue()));
            }

            // Gợi ý 50/30/20
            if (incomeRef.compareTo(BigDecimal.ZERO) > 0) {
                sb.append("\n💰 **Gợi ý phân bổ (50/30/20):**\n");
                sb.append(String.format("• Thiết yếu (50%%): %,.0f đ\n", needs));
                sb.append("  (Ăn uống, nhà ở, điện nước, xăng xe, bảo hiểm)\n");
                sb.append(String.format("• Linh hoạt (30%%): %,.0f đ\n", wants));
                sb.append(String.format("• Tiết kiệm (20%%): %,.0f đ\n", savings));
                sb.append("  (Gửi tiết kiệm, đầu tư, quỹ khẩn cấp)\n");

                // Gợi ý dòng tiền theo từng ngày
                sb.append(String.format("\n📅 **Gợi ý dòng tiền mỗi ngày (%d ngày/tháng):**\n", daysInMonth));
                sb.append(String.format("• Thiết yếu: %,.0f đ/ngày (~%dk/ngày)\n", dailyNeeds, dailyNeeds.divide(BigDecimal.valueOf(1000), 0, java.math.RoundingMode.HALF_UP).intValue()));
                sb.append(String.format("• Linh hoạt: %,.0f đ/ngày (~%dk/ngày)\n", dailyWants, dailyWants.divide(BigDecimal.valueOf(1000), 0, java.math.RoundingMode.HALF_UP).intValue()));
                sb.append(String.format("• Tiết kiệm: %,.0f đ/ngày (~%dk/ngày)\n", dailySavings, dailySavings.divide(BigDecimal.valueOf(1000), 0, java.math.RoundingMode.HALF_UP).intValue()));

                // Chỉ cảnh báo nếu chi > thu
                if (avgMonthlyExpense.compareTo(avgMonthlyIncome) > 0) {
                    sb.append("\n⚠️ Bạn đang chi nhiều hơn thu! Cần cắt giảm chi tiêu.");
                } else if (saveRate.intValue() < 20) {
                    sb.append("\n💡 Tăng tiết kiệm để đạt mục tiêu 20%.");
                }
            }

            // Nếu không có dữ liệu
            if (totalIncome3m.compareTo(BigDecimal.ZERO) == 0 && totalExpense3m.compareTo(BigDecimal.ZERO) == 0 && !useUserIncome) {
                return "Bạn chưa có giao dịch nào trong 3 tháng gần nhất. Hãy bắt đầu ghi chép thu chi để tôi có thể tư vấn chính xác hơn!";
            }

            return sb.toString();
        } catch (Exception e) {
            log.error("[AI] Lỗi build advisory reply: ", e);
            return null; // Trả null → fallback về AI reply
        }
    }

    // =================================================================================
    // ĐẶT NHẮC NHỞ (SET REMINDER)
    // =================================================================================

    /**
     * [8.1] Kiểm tra message có phải yêu cầu đặt nhắc nhở không.
     * Keywords: nhắc, thông báo, đặt thông báo, nhắc nhở, ghi nhớ, nhớ nhắc, remind
     */
    private boolean isReminderRequest(String msg) {
        String[] reminderWords = {
            "nhắc tôi", "nhắc mình", "nhắc nhở", "đặt nhắc", "đặt thông báo",
            "thông báo cho tôi", "thông báo giúp", "nhớ nhắc", "ghi nhớ giúp",
            "remind me", "set reminder", "hãy nhắc", "nhắc giúp", "báo cho tôi"
        };
        for (String w : reminderWords) {
            if (msg.contains(w)) return true;
        }
        return false;
    }

    /**
     * [8.2] Xử lý yêu cầu đặt nhắc nhở từ user.
     * Bước 1: Parse nội dung nhắc nhở (bỏ phần thời gian)
     * Bước 2: Parse thời gian nhắc từ message (dùng parseDateRangeFromMessage)
     * Bước 3: Tạo notification qua NotificationService với scheduledTime
     * Trả reply xác nhận.
     */
    private String handleReminder(Account account, String userMessage) {
        try {
            String msg = userMessage.toLowerCase().trim();
            java.time.LocalDate today = java.time.LocalDate.now();

            // Bước 1: Parse thời gian nhắc
            LocalDateTime scheduledTime = parseReminderTime(msg);

            // Bước 1.5: Validate không cho đặt nhắc nhở trong QUÁ KHỨ
            // Buffer 2 phút: tránh false-reject khi user set giờ đúng hiện tại (19:26:00 < 19:26:xx)
            if (scheduledTime.isBefore(LocalDateTime.now().minusMinutes(2))) {
                log.warn("[AI] Reminder time trong quá khứ: {} < now → từ chối", scheduledTime);
                return String.format(
                    "⚠️ Không thể đặt nhắc nhở trong quá khứ!\n• Thời gian bạn yêu cầu: %s\n• Bây giờ: %s\n\nHãy chọn thời gian trong tương lai nhé!",
                    scheduledTime.format(java.time.format.DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy")),
                    LocalDateTime.now().format(java.time.format.DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy"))
                );
            }

            // Bước 2: Trích xuất nội dung nhắc nhở (bỏ phần keyword + thời gian)
            String content = extractReminderContent(userMessage);

            // Bước 3: Tạo notification qua service
            NotificationContent notiMsg = NotificationMessages.aiScheduledReminder(content);
            notificationService.createNotification(
                    account,
                    notiMsg.title(),
                    notiMsg.content(),
                    NotificationType.CHAT_AI,
                    null,
                    scheduledTime
            );

            // Bước 4: Format reply xác nhận
            String timeStr;
            if (scheduledTime.toLocalDate().equals(today)) {
                timeStr = String.format("hôm nay lúc %02d:%02d", scheduledTime.getHour(), scheduledTime.getMinute());
            } else if (scheduledTime.toLocalDate().equals(today.plusDays(1))) {
                timeStr = String.format("ngày mai (%s)", scheduledTime.toLocalDate().format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy")));
            } else {
                timeStr = scheduledTime.toLocalDate().format(java.time.format.DateTimeFormatter.ofPattern("dd/MM/yyyy"));
            }

            return String.format("🔔 Đã đặt nhắc nhở!\n• Nội dung: %s\n• Thời gian: %s\n\nTôi sẽ gửi thông báo cho bạn đúng lịch.", content, timeStr);
        } catch (Exception e) {
            log.error("[AI] Lỗi xử lý reminder: ", e);
            return "Không thể đặt nhắc nhở. Bạn thử nói rõ hơn? VD: \"Nhắc tôi trả nợ anh Tuấn ngày 25/04\"";
        }
    }

    /**
     * [8.2.1] Convert giờ AM/PM dựa trên keyword buổi trong message.
     * "tối", "chiều", "đêm" → nếu hour <= 12 thì +12 (PM)
     * "sáng", "trưa" → giữ nguyên (AM)
     * VD: "6h38 tối" → 18, "3h chiều" → 15, "2h sáng" → 2, "14h" → 14 (đã >12, không đổi)
     */
    private int convertHourByPeriod(int hour, String msg) {
        // Bước 1: Kiểm tra keyword PM ("tối", "chiều", "đêm")
        boolean isPM = msg.contains("tối") || msg.contains("chiều") || msg.contains("đêm") || msg.contains("khuya");
        // Bước 2: Kiểm tra keyword AM ("sáng")
        boolean isAM = msg.contains("sáng");
        // Bước 3: Convert nếu cần
        if (isPM && hour >= 1 && hour <= 11) { // Nếu PM và hour 1-11 → +12
            log.info("[AI] Convert giờ PM: {} → {}", hour, hour + 12);
            return hour + 12; // VD: 6 tối → 18
        }
        if (isAM && hour == 12) { // Nếu sáng và hour=12 → 0 (nửa đêm)
            return 0;
        }
        return hour; // Giữ nguyên nếu không có keyword hoặc đã đúng format 24h
    }

    /**
     * [8.3] Parse thời gian nhắc nhở từ message.
     * Hỗ trợ: hôm nay, ngày mai, ngày cụ thể (dd/mm, dd/mm/yyyy), tháng sau, tuần sau...
     * Hỗ trợ giờ cụ thể: 5h20, 17:30, 5:20...
     * Mặc định 8:00 sáng nếu không có giờ cụ thể.
     */
    private LocalDateTime parseReminderTime(String msg) {
        java.time.LocalDate today = java.time.LocalDate.now(); // Ngày hôm nay
        java.time.LocalTime defaultTime = java.time.LocalTime.of(8, 0); // Giờ mặc định 8:00 sáng

        // Bước 1: Parse giờ cụ thể từ message (vd: 5h20, 17:30, 5:20)
        java.time.LocalTime specificTime = null; // Giờ cụ thể từ message
        // Pattern 1: 5h20, 17h30, 5h (dạng chữ h)
        Matcher hourMinPattern = HOUR_MIN_PATTERN_H.matcher(msg);
        if (hourMinPattern.find()) { // Nếu match pattern chữ h
            int hour = Integer.parseInt(hourMinPattern.group(1)); // Lấy giờ
            int minute = hourMinPattern.group(2) != null ? Integer.parseInt(hourMinPattern.group(2)) : 0; // Lấy phút (default 0)
            // Bước 1.1: Convert AM/PM dựa trên keyword buổi ("tối", "chiều", "đêm" → PM, "sáng" → AM)
            hour = convertHourByPeriod(hour, msg);
            if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) { // Validate giờ phút hợp lệ
                specificTime = java.time.LocalTime.of(hour, minute); // Tạo LocalTime
                log.info("[AI] Parse giờ cụ thể: {}:{}", hour, minute);
            }
        }
        // Pattern 2: 17:30, 5:20 (dấu :)
        if (specificTime == null) { // Nếu chưa parse được giờ
            Matcher timePattern = HOUR_MIN_PATTERN_COLON.matcher(msg);
            if (timePattern.find()) { // Nếu match pattern dấu :
                int hour = Integer.parseInt(timePattern.group(1)); // Lấy giờ
                int minute = Integer.parseInt(timePattern.group(2)); // Lấy phút
                // Bước 1.1: Convert AM/PM dựa trên keyword buổi
                hour = convertHourByPeriod(hour, msg);
                if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) { // Validate giờ phút hợp lệ
                    specificTime = java.time.LocalTime.of(hour, minute); // Tạo LocalTime
                    log.info("[AI] Parse giờ cụ thể (HH:MM): {}:{}", hour, minute);
                }
            }
        }

        // Bước 2: Xác định ngày nhắc nhở
        java.time.LocalDate targetDate = today; // Ngày đích (default hôm nay)
        boolean isToday = false; // Flag đánh dấu là hôm nay

        // Ưu tiên 1: Parse ngày cụ thể dd/mm, dd/mm/yyyy, dd-mm, dd-mm-yyyy
        // Pattern 1: dd/mm/yyyy (VD: 19/5/2026)
        Matcher datePatternFull = DATE_PATTERN_FULL.matcher(msg);
        if (datePatternFull.find()) { // Nếu match pattern dd/mm/yyyy
            try {
                int day = Integer.parseInt(datePatternFull.group(1)); // Lấy ngày
                int month = Integer.parseInt(datePatternFull.group(2)); // Lấy tháng
                int year = Integer.parseInt(datePatternFull.group(3)); // Lấy năm
                targetDate = java.time.LocalDate.of(year, month, day); // Tạo LocalDate
                log.info("[AI] Parse ngày cụ thể (dd/mm/yyyy): {}/{}/{}", day, month, year);
            } catch (Exception e) { // Nếu parse lỗi
                log.warn("[AI] Lỗi parse ngày cụ thể: {}", e.getMessage());
            }
        } else {
            // Pattern 2: dd/mm (VD: 19/5) - dùng năm hiện tại
            Matcher datePatternShort = DATE_PATTERN_SHORT.matcher(msg);
            if (datePatternShort.find()) { // Nếu match pattern dd/mm
                try {
                    int day = Integer.parseInt(datePatternShort.group(1)); // Lấy ngày
                    int month = Integer.parseInt(datePatternShort.group(2)); // Lấy tháng
                    int year = today.getYear(); // Dùng năm hiện tại
                    targetDate = java.time.LocalDate.of(year, month, day); // Tạo LocalDate
                    log.info("[AI] Parse ngày cụ thể (dd/mm): {}/{} (năm {})", day, month, year);
                } catch (Exception e) { // Nếu parse lỗi
                    log.warn("[AI] Lỗi parse ngày cụ thể: {}", e.getMessage());
                }
            }
        }

        // Nếu đã parse được ngày cụ thể → bỏ qua các logic khác
        if (!targetDate.equals(today)) { // Nếu targetDate khác hôm nay (đã parse được ngày cụ thể)
            // Chỉ cần kết hợp giờ rồi trả về
            java.time.LocalTime finalTime = specificTime != null ? specificTime : defaultTime; // Dùng giờ cụ thể hoặc default 8:00
            LocalDateTime result = targetDate.atTime(finalTime); // Kết hợp ngày + giờ
            return result; // Trả thời gian nhắc nhở
        }

        // Ưu tiên 2: Các keyword ngày tháng (hôm nay, ngày mai, etc.)
        // "hôm nay" → hôm nay
        if (msg.contains("hôm nay")) { // Nếu message chứa "hôm nay"
            targetDate = today; // Đích = hôm nay
            isToday = true; // Đánh dấu là hôm nay
        }
        // "ngay bây giờ" hoặc "ngay" → hôm nay, ngay lập tức
        else if (msg.contains("ngay bây giờ") || msg.contains("ngay")) { // Nếu message chứa "ngay"
            targetDate = today; // Đích = hôm nay
            isToday = true; // Đánh dấu là hôm nay
            if (specificTime == null) { // Nếu không có giờ cụ thể
                // Nếu không có giờ cụ thể → dùng giờ hiện tại + 5 phút
                return LocalDateTime.now().plusMinutes(5); // Trả ngay lập tức
            }
        }
        // "ngày mai"
        else if (msg.contains("ngày mai") || msg.contains("mai")) { // Nếu message chứa "ngày mai"
            targetDate = today.plusDays(1); // Đích = ngày mai
        }
        // "tuần sau" / "tuần tới"
        else if (msg.contains("tuần sau") || msg.contains("tuần tới")) { // Nếu message chứa "tuần sau"
            targetDate = today.plusWeeks(1); // Đích = tuần sau
        }
        // "tháng sau" / "tháng tới"
        else if (msg.contains("tháng sau") || msg.contains("tháng tới")) { // Nếu message chứa "tháng sau"
            targetDate = today.plusMonths(1).withDayOfMonth(1); // Đích = đầu tháng sau
        }
        // Thứ cụ thể: "thứ 5 tuần sau"
        else { // Fallback: thử parse thứ trong tuần
            java.time.DayOfWeek dow = parseDayOfWeek(msg); // Parse thứ
            if (dow != null) { // Nếu parse được thứ
                // Tìm ngày thứ đó tiếp theo (trong tương lai)
                for (int i = 1; i <= 7; i++) { // Vòng lặp 7 ngày
                    targetDate = today.plusDays(i); // Thử từng ngày
                    if (targetDate.getDayOfWeek() == dow) break; // Nếu match thứ → dừng
                }
                if (msg.contains("tuần sau") || msg.contains("tuần tới")) { // Nếu có "tuần sau"
                    targetDate = targetDate.plusWeeks(1); // Cộng thêm 1 tuần
                }
            }
        }

        // Bước 3: Kết hợp ngày + giờ
        java.time.LocalTime finalTime = specificTime != null ? specificTime : defaultTime; // Dùng giờ cụ thể hoặc default 8:00
        LocalDateTime result = targetDate.atTime(finalTime); // Kết hợp ngày + giờ

        // Nếu là hôm nay và giờ đã qua → lùi sang ngày mai
        if (isToday && result.isBefore(LocalDateTime.now())) { // Nếu là hôm nay và thời gian đã qua
            result = result.plusDays(1); // Lùi sang ngày mai
            log.info("[AI] Giờ đã qua → lùi sang ngày mai");
        }

        return result; // Trả thời gian nhắc nhở
    }

    /**
     * [8.4] Trích xuất nội dung nhắc nhở (bỏ phần keyword nhắc + thời gian).
     * VD: "nhắc tôi trả nợ anh Tuấn ngày 25/04" → "trả nợ anh Tuấn"
     */
    private String extractReminderContent(String userMessage) {
        String content = userMessage;
        // Bước 1: Cắt bỏ phần thời gian "vào lúc X" / "vào X" / "lúc X" (nếu có)
        // Lấy phần TRƯỚC keyword thời gian làm content
        // VD: "nhắc tôi trả nợ 50k vào lúc 5h24 tối ngày 21/4/2026"
        //  → cắt tại "vào lúc" → "nhắc tôi trả nợ 50k"
        String lower = content.toLowerCase();
        String[] timeSplitters = {" vào lúc ", " vào ngày ", " vào ", " lúc "};
        for (String splitter : timeSplitters) { // Vòng lặp qua các keyword cắt
            int idx = lower.indexOf(splitter);
            if (idx > 0) { // Nếu tìm thấy và không ở đầu câu
                content = content.substring(0, idx); // Lấy phần trước splitter
                lower = content.toLowerCase(); // Cập nhật lower
                break; // Dừng vòng lặp
            }
        }

        // Bước 2: Bỏ keyword nhắc ở đầu câu
        String[] removeWords = {
            "nhắc tôi", "nhắc mình", "nhắc nhở", "đặt nhắc", "đặt thông báo",
            "thông báo cho tôi", "thông báo giúp", "nhớ nhắc", "ghi nhớ giúp",
            "hãy nhắc", "nhắc giúp", "báo cho tôi", "remind me", "set reminder",
            "hôm nay", "ngày mai", "tuần sau", "tuần tới", "tháng sau", "tháng tới",
            "ngay bây giờ"
        };
        for (String w : removeWords) { // Vòng lặp qua từng từ cần bỏ
            int idx = lower.indexOf(w);
            if (idx >= 0) { // Nếu tìm thấy
                content = content.substring(0, idx) + content.substring(idx + w.length()); // Bỏ từ đó
                lower = content.toLowerCase(); // Cập nhật lower
            }
        }

        // Bước 3: Bỏ các pattern thời gian còn sót (nếu user viết không có "vào"/"lúc")
        // Bỏ giờ dd/mm/yyyy và dd/mm
        content = content.replaceAll("\\d{1,2}/\\d{1,2}(?:/\\d{4})?", ""); // Ngày dd/mm hoặc dd/mm/yyyy
        content = content.replaceAll("(?i)ngày\\s+\\d{1,2}\\s+tháng\\s+\\d{1,2}(?:\\s+\\d{4})?", ""); // "ngày X tháng Y"
        content = content.replaceAll("\\d{1,2}h\\d{0,2}", ""); // Giờ dạng 5h, 5h24, 17h30
        content = content.replaceAll("\\d{1,2}:\\d{2}", ""); // Giờ dạng 17:30, 5:24
        content = content.replaceAll("(?i)(sáng|chiều|tối|trưa|khuya|đêm)\\b", ""); // Buổi trong ngày
        content = content.replaceAll("(?i)(chủ nhật|thứ\\s*(hai|ba|tư|năm|sáu|bảy|[2-7]))", ""); // Thứ trong tuần
        content = content.replaceAll("\\bngày\\b", ""); // Từ "ngày" đứng một mình

        // Bước 4: Clean spaces
        content = content.replaceAll("\\s+", " ").trim(); // Gộp khoảng trắng
        return content.isEmpty() ? "Nhắc nhở từ SmartMoney AI" : content; // Fallback nếu rỗng
    }

    /**
     * DTO lưu trữ kết quả tạo giao dịch.
     */
    private record ActionResult(boolean success, Long createdId, String reply) {}

    /**
     * DTO lưu trữ thông tin action chờ xác nhận.
     */
    private record PendingAction(String actionType, Map<String, Object> params, boolean isConfirm) {}

    /**
     * [9.1] Chuẩn hóa message: lowercase, giữ nguyên dấu tiếng Việt
     * Ví dụ: "Lưu" → "lưu", "Hủy" → "hủy"
     */
    private String normalizeMessage(String message) {
        if (message == null || message.isEmpty()) {
            return "";
        }
        // Chỉ chuyển thành lowercase, giữ nguyên dấu tiếng Việt
        return message.toLowerCase();
    }

    /**
     * [9.2] Kiểm tra xem user có đang trả lời confirm cho action gần nhất không.
     * Trả về PendingAction nếu user đang trả lời confirm, null nếu không.
     */
    private PendingAction checkPendingAction(Integer accountId, String userMessage) {
        log.info("[AI] checkPendingAction - userMessage: '{}'", userMessage);

        // Bước 1: Lấy tin nhắn AI gần nhất (senderType = true)
        List<AIConversation> recentAiMessages = aiRepo.findTop1ByAccountIdAndSenderTypeOrderByCreatedAtDesc(accountId, true); // Query 1 tin nhắn AI gần nhất

        if (recentAiMessages.isEmpty()) { // Nếu không có tin nhắn AI nào
            log.warn("[AI] Không tìm thấy tin nhắn AI nào");
            return null; // Trả null (không có action chờ confirm)
        }

        // Bước 2: Kiểm tra tin nhắn AI gần nhất có phải là action chờ confirm không
        AIConversation lastAiMsg = recentAiMessages.getFirst(); // Lấy tin nhắn AI gần nhất
        log.info("[AI] Tin nhắn AI gần nhất - id: {}, intent: {}, senderType: {}",
            lastAiMsg.getId(), lastAiMsg.getIntent(), lastAiMsg.getSenderType());

        // Kiểm tra xem intent có phải là ADD_TRANSACTION không (action tạo giao dịch)
        if (lastAiMsg.getIntent() == null || lastAiMsg.getIntent() != AiIntent.ADD_TRANSACTION.getValue()) { // Nếu intent không phải ADD_TRANSACTION
            log.warn("[AI] Tin nhắn AI không có intent ADD_TRANSACTION (intent: {})", lastAiMsg.getIntent());
            return null; // Trả null (không phải action chờ confirm)
        }

        // Bước 3: Chuẩn hóa user message và kiểm tra xem user có trả lời confirm không
        String normalized = normalizeMessage(userMessage); // Chuẩn hóa message (lowercase)
        log.info("[AI] Normalized message: '{}'", normalized);

        // Pattern confirm: tiếng Việt (có dấu) + tiếng Anh
        boolean isConfirm = normalized.matches(".*(đồng ý|lưu|lưu đi|xác nhận|thực hiện|dong y|dongy|luu|luu di|save|ok|yes|confirm|xac nhan|xacnhan|thuc hien|thuchien|agree|agreed|accept).*"); // Regex match confirm
        log.info("[AI] isConfirm: {}", isConfirm);

        // Pattern cancel: tiếng Việt (có dấu) + tiếng Anh
        boolean isCancel = normalized.matches(".*(hủy|không|bỏ qua|huy|khong|no|cancel|bo qua|boqua|reject|decline|disagree).*"); // Regex match cancel
        log.info("[AI] isCancel: {}", isCancel);

        if (!isConfirm && !isCancel) { // Nếu không match cả confirm và cancel
            log.warn("[AI] User message không match với confirm/cancel pattern");
            return null; // Trả null (không phải trả lời confirm)
        }

        // Bước 4: Đọc params từ actionParams field thay vì parse từ messageContent
        String actionParams = lastAiMsg.getActionParams();
        if (actionParams == null || actionParams.trim().isEmpty()) {
            log.warn("[AI] AI message không có actionParams - không phải đang chờ confirm");
            return null; // Trả null (không phải action chờ confirm)
        }

        try { // Thử parse JSON params từ actionParams
            log.info("[AI] JSON params từ actionParams: {}", actionParams);
            JsonNode paramsJson = objectMapper.readTree(actionParams); // Parse JSON

            Map<String, Object> params = new HashMap<>(); // Map lưu params
            // Parse amount từ text sang BigDecimal để tránh scientific notation
            params.put("amount", new BigDecimal(paramsJson.path("amount").asText("0"))); // Lấy số tiền
            params.put("categoryId", paramsJson.path("categoryId").asInt(3)); // Lấy category ID (default 3)
            params.put("note", paramsJson.path("note").asText("")); // Lấy note
            params.put("isIncome", paramsJson.path("isIncome").asBoolean(false)); // Lấy isIncome

            // Parse walletId nếu có
            if (paramsJson.has("walletId") && !paramsJson.get("walletId").isNull()) { // Nếu có wallet ID
                 params.put("walletId", paramsJson.path("walletId").asInt()); // Lấy wallet ID
            }

            // Parse receiptId nếu có (để set source_type = 4)
            if (paramsJson.has("receiptId") && !paramsJson.get("receiptId").isNull()) {
                params.put("receiptId", paramsJson.path("receiptId").asInt());
            }

            // Bước 5: Thêm ai_chat_id để thỏa mãn constraint CHK_Transaction_Integrity
            params.put("aiChatId", lastAiMsg.getId()); // Lưu ID tin nhắn AI

            log.info("[AI] Trả về PendingAction - actionType: create_transaction, isConfirm: {}", isConfirm);
            return new PendingAction("create_transaction", params, isConfirm); // Trả PendingAction
        } catch (Exception e) { // Nếu lỗi parse JSON
            log.error("[AI] Lỗi khi parse actionParams: {}", e.getMessage());
            return null; // Trả null (lỗi)
        }
    }

    /**
     * [9.3] Xây dựng câu trả lời cho giao dịch đã tạo.
     */
    private String buildTransactionReply(BigDecimal amount, Integer walletId, Integer accountId) {
        double amountValue = amount != null ? amount.doubleValue() : 0.0;
        if (walletId != null) {
            Wallet wallet = walletRepo.findByAccountId(accountId).stream()
                    .filter(w -> w.getId().equals(walletId) && Boolean.FALSE.equals(w.getDeleted()))
                    .findFirst()
                    .orElseThrow(() -> new SecurityException("You do not have permission to access this wallet."));
            return String.format("Đã lưu giao dịch %,.0f đ vào ví %s.", amountValue, wallet.getWalletName());
        } else {
            return String.format("Đã lưu giao dịch %,.0f đ.", amountValue);
        }
    }

    /**
     * [9.4] Đọc Integer an toàn từ Map (tránh ClassCastException).
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

    /**
     * [9.5] Hàm gọi TransactionService để tạo Transaction thực tế.
     */
    private ActionResult executeCreateTransaction(Account account, Map<String, Object> params) {
        try {
            // Bước 1: Trích xuất dữ liệu từ tham số cơ bản
            BigDecimal amount = params.get("amount") != null // Nếu có amount
                    ? new BigDecimal(params.get("amount").toString()) : null; // Chuyển sang BigDecimal
            Integer categoryId = getIntParam(params, "categoryId"); // Lấy category ID an toàn
            String note = (String) params.get("note"); // Lấy note

            // Bước 1.5: Nếu là OCR (có receiptId) → thêm ngày vào note nếu chưa có date
            Integer checkReceiptId = getIntParam(params, "receiptId");
            if (checkReceiptId != null && note != null && !note.isEmpty()) {
                // Kiểm tra note đã có date chưa (pattern dd/MM/yyyy hoặc yyyy-MM-dd)
                boolean hasDate = note.matches(".*(\\d{2}/\\d{2}/\\d{4}|\\d{4}-\\d{2}-\\d{2}).*");
                if (!hasDate) {
                    // Ưu tiên dùng date từ OCR nếu có, ngược lại dùng ngày hiện tại
                    String ocrDateStr = (String) params.get("ocrDate");
                    String dateToAdd;
                    if (ocrDateStr != null && !ocrDateStr.isEmpty()) {
                        // Parse date từ OCR (format yyyy-MM-dd) sang dd/MM/yyyy
                        try {
                            LocalDate ocrDate = LocalDate.parse(ocrDateStr);
                            dateToAdd = ocrDate.format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
                        } catch (Exception e) {
                            log.warn("[AI] Không thể parse ocrDate: {}, dùng ngày hiện tại", ocrDateStr);
                            dateToAdd = LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
                        }
                    } else {
                        // Dùng ngày hiện tại
                        dateToAdd = LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy"));
                    }
                    note = note + " ngày " + dateToAdd;
                }
            }

            // Bước 2: Đọc các ID bằng getIntParam an toàn
            Integer walletId = getIntParam(params, "walletId"); // Lấy wallet ID an toàn
            Integer aiChatId = getIntParam(params, "aiChatId"); // Lấy AI chat ID an toàn

            // Bước 3: Đọc các field khác
            Boolean reportable = params.get("reportable") == null // Nếu không có reportable
                    || Boolean.parseBoolean(params.get("reportable").toString()); // Default true

            // Bước 4: Đọc transDate (mặc định = now nếu null)
            LocalDateTime transDate = LocalDateTime.now(); // Default = thời gian hiện tại
            if (params.get("transDate") != null) { // Nếu có transDate
                try { // Thử parse
                    transDate = LocalDateTime.parse(params.get("transDate").toString()); // Parse LocalDateTime
                } catch (Exception e) { // Nếu lỗi parse
                    log.warn("[AI] Không thể parse transDate: {}, dùng thời gian hiện tại", params.get("transDate"));
                }
            }

            // Bước 5: Lấy category theo categoryId
            Category matchedCat = null; // Category tìm được

            if (categoryId != null) { // Nếu có categoryId
                matchedCat = categoryRepo.findById(categoryId).orElse(null); // Query category từ DB
            }

            // Bước 6: Fallback nếu không tìm thấy categoryId
            if (matchedCat == null) { // Nếu không tìm thấy category
                boolean isIncome = params.containsKey("isIncome") && Boolean.parseBoolean(params.get("isIncome").toString()); // Lấy isIncome từ params
                Integer defaultCatId = isIncome ? SystemCategory.INCOME_OTHER.getId() : SystemCategory.OTHER_EXPENSE.getId(); // Default category ID
                matchedCat = categoryRepo.findById(defaultCatId).orElseThrow(() -> new RuntimeException("Default category not found.")); // Query default category
                log.warn("[AI] CategoryId {} not found, using default ID: {}", categoryId, defaultCatId);
            }

            // Bước 9: Xây dựng Request DTO đầy đủ
            // Nếu có receiptId trong params → sourceType = 4 (receipt), ngược lại = 2 (chat)
            Integer receiptId = getIntParam(params, "receiptId");
            int sourceType = (receiptId != null) ? TransactionSourceType.RECEIPT.getValue() : TransactionSourceType.CHAT.getValue();

            TransactionRequest txRequest = TransactionRequest.builder() // Builder pattern
                    .walletId(walletId) // Set wallet ID
                    .categoryId(matchedCat.getId()) // Set category ID
                    .amount(amount) // Set số tiền
                    .note(note) // Set note
                    .transDate(transDate) // Set ngày giao dịch
                    .reportable(reportable) // Set reportable
                    .sourceType(sourceType) // Set nguồn: 4 nếu receipt, 2 nếu chat
                    .aiChatId(aiChatId) // Set AI chat ID
                    .build(); // Build request

            // Bước 10: Gọi Transaction Service
            TransactionResponse txResponse = transactionService.createTransaction(txRequest, account.getId()); // Tạo giao dịch

            // Bước 11: Xây dựng câu trả lời phản hồi
            String rep = buildTransactionReply(amount, txResponse.walletId(), account.getId()); // Build reply

            // Bước 12: Trả về kết quả thành công
            return new ActionResult(true, txResponse.id(), rep); // Trả ActionResult success

        } catch (Exception e) { // Nếu lỗi
            log.error("[AI] Lỗi khi tạo giao dịch tự động: ", e); // Log lỗi
            //Trả về thông báo lỗi
            return new ActionResult(false, null, "Không thể lưu giao dịch: " + e.getMessage()); // Trả ActionResult error
        }
    }
}
