package fpt.aptech.server.service.ai;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * [1] CategoryMappingService — Service chuyên xử lý mapping từ text sang categoryId.
 * Tách ra từ AIConversationServiceImpl để tránh circular dependency với ReceiptServiceImpl.
 */
@Slf4j
@Service
public class CategoryMappingService {

    // Map keyword -> categoryId (thứ tự: cụm dài trước, từ ngắn sau để match chính xác)
    private static final LinkedHashMap<String, Integer> CATEGORY_KEYWORD_MAP = new LinkedHashMap<>();
    static {
        // ===== CỤM TỪ DÀI TRƯỚC (tránh match nhầm) =====
        // Medical Check-up (40)
        CATEGORY_KEYWORD_MAP.put("khám sức khỏe", 40); CATEGORY_KEYWORD_MAP.put("khám tổng quát", 40);
        CATEGORY_KEYWORD_MAP.put("khám bệnh", 40); CATEGORY_KEYWORD_MAP.put("khám định kỳ", 40);
        CATEGORY_KEYWORD_MAP.put("xét nghiệm", 40); CATEGORY_KEYWORD_MAP.put("siêu âm", 40);
        CATEGORY_KEYWORD_MAP.put("chụp x-quang", 40); CATEGORY_KEYWORD_MAP.put("tầm soát", 40);
        CATEGORY_KEYWORD_MAP.put("khám phụ khoa", 40); CATEGORY_KEYWORD_MAP.put("khám thai", 40);
        CATEGORY_KEYWORD_MAP.put("health check", 40); CATEGORY_KEYWORD_MAP.put("check-up", 40);
        CATEGORY_KEYWORD_MAP.put("checkup", 40); CATEGORY_KEYWORD_MAP.put("medical check", 40);
        CATEGORY_KEYWORD_MAP.put("blood test", 40); CATEGORY_KEYWORD_MAP.put("ultrasound", 40);
        CATEGORY_KEYWORD_MAP.put("x-ray", 40); CATEGORY_KEYWORD_MAP.put("screening", 40);
        CATEGORY_KEYWORD_MAP.put("mri", 40);

        // Sports & Fitness (41)
        CATEGORY_KEYWORD_MAP.put("tập thể dục", 41); CATEGORY_KEYWORD_MAP.put("tập gym", 41);
        CATEGORY_KEYWORD_MAP.put("phòng gym", 41); CATEGORY_KEYWORD_MAP.put("phí gym", 41);
        CATEGORY_KEYWORD_MAP.put("thể thao", 41); CATEGORY_KEYWORD_MAP.put("thể dục", 41);
        CATEGORY_KEYWORD_MAP.put("yoga", 41); CATEGORY_KEYWORD_MAP.put("pilates", 41);
        CATEGORY_KEYWORD_MAP.put("aerobic", 41); CATEGORY_KEYWORD_MAP.put("zumba", 41);
        CATEGORY_KEYWORD_MAP.put("bơi lội", 41); CATEGORY_KEYWORD_MAP.put("chạy bộ", 41);
        CATEGORY_KEYWORD_MAP.put("đạp xe", 41); CATEGORY_KEYWORD_MAP.put("đá bóng", 41);
        CATEGORY_KEYWORD_MAP.put("bóng rổ", 41); CATEGORY_KEYWORD_MAP.put("cầu lông", 41);
        CATEGORY_KEYWORD_MAP.put("boxing", 41); CATEGORY_KEYWORD_MAP.put("võ thuật", 41);
        CATEGORY_KEYWORD_MAP.put("gym", 41); CATEGORY_KEYWORD_MAP.put("fitness", 41);
        CATEGORY_KEYWORD_MAP.put("workout", 41); CATEGORY_KEYWORD_MAP.put("exercise", 41);
        CATEGORY_KEYWORD_MAP.put("swimming", 41); CATEGORY_KEYWORD_MAP.put("running", 41);
        CATEGORY_KEYWORD_MAP.put("cycling", 41); CATEGORY_KEYWORD_MAP.put("badminton", 41);
        CATEGORY_KEYWORD_MAP.put("tennis", 41); CATEGORY_KEYWORD_MAP.put("football", 41);
        CATEGORY_KEYWORD_MAP.put("basketball", 41); CATEGORY_KEYWORD_MAP.put("bơi", 41);
        CATEGORY_KEYWORD_MAP.put("tập chạy", 41); CATEGORY_KEYWORD_MAP.put("tập đi", 41);
        CATEGORY_KEYWORD_MAP.put("tập bơi", 41); CATEGORY_KEYWORD_MAP.put("tập boxing", 41);

        // Beauty (39)
        CATEGORY_KEYWORD_MAP.put("làm đẹp", 39); CATEGORY_KEYWORD_MAP.put("chăm sóc da", 39);
        CATEGORY_KEYWORD_MAP.put("trang điểm", 39); CATEGORY_KEYWORD_MAP.put("mỹ phẩm", 39);
        CATEGORY_KEYWORD_MAP.put("làm tóc", 39); CATEGORY_KEYWORD_MAP.put("cắt tóc", 39);
        CATEGORY_KEYWORD_MAP.put("nhuộm tóc", 39); CATEGORY_KEYWORD_MAP.put("uốn tóc", 39);
        CATEGORY_KEYWORD_MAP.put("gội đầu", 39); CATEGORY_KEYWORD_MAP.put("làm nail", 39);
        CATEGORY_KEYWORD_MAP.put("sơn móng", 39); CATEGORY_KEYWORD_MAP.put("tắm trắng", 39);
        CATEGORY_KEYWORD_MAP.put("triệt lông", 39); CATEGORY_KEYWORD_MAP.put("làm mặt", 39);
        CATEGORY_KEYWORD_MAP.put("son môi", 39); CATEGORY_KEYWORD_MAP.put("kem dưỡng", 39);
        CATEGORY_KEYWORD_MAP.put("nước hoa", 39); CATEGORY_KEYWORD_MAP.put("xông hơi", 39);
        CATEGORY_KEYWORD_MAP.put("spa", 39); CATEGORY_KEYWORD_MAP.put("salon", 39);
        CATEGORY_KEYWORD_MAP.put("beauty", 39); CATEGORY_KEYWORD_MAP.put("skincare", 39);
        CATEGORY_KEYWORD_MAP.put("makeup", 39); CATEGORY_KEYWORD_MAP.put("cosmetics", 39);
        CATEGORY_KEYWORD_MAP.put("facial", 39); CATEGORY_KEYWORD_MAP.put("perfume", 39);
        CATEGORY_KEYWORD_MAP.put("manicure", 39); CATEGORY_KEYWORD_MAP.put("pedicure", 39);
        CATEGORY_KEYWORD_MAP.put("haircut", 39); CATEGORY_KEYWORD_MAP.put("massage", 39);
        CATEGORY_KEYWORD_MAP.put("botox", 39); CATEGORY_KEYWORD_MAP.put("filler", 39);

        // Food & Beverage (1)
        CATEGORY_KEYWORD_MAP.put("ăn sáng", 1); CATEGORY_KEYWORD_MAP.put("ăn trưa", 1);
        CATEGORY_KEYWORD_MAP.put("ăn tối", 1); CATEGORY_KEYWORD_MAP.put("ăn vặt", 1);
        CATEGORY_KEYWORD_MAP.put("ăn khuya", 1); CATEGORY_KEYWORD_MAP.put("ăn uống", 1);
        CATEGORY_KEYWORD_MAP.put("ăn nhẹ", 1); CATEGORY_KEYWORD_MAP.put("nhà hàng", 1);
        CATEGORY_KEYWORD_MAP.put("quán ăn", 1); CATEGORY_KEYWORD_MAP.put("quán nhậu", 1);
        CATEGORY_KEYWORD_MAP.put("đồ ăn", 1); CATEGORY_KEYWORD_MAP.put("gọi đồ ăn", 1);
        CATEGORY_KEYWORD_MAP.put("đặt cơm", 1); CATEGORY_KEYWORD_MAP.put("grab food", 1);
        CATEGORY_KEYWORD_MAP.put("shopee food", 1); CATEGORY_KEYWORD_MAP.put("baemin", 1);
        CATEGORY_KEYWORD_MAP.put("food delivery", 1); CATEGORY_KEYWORD_MAP.put("trà sữa", 1);
        CATEGORY_KEYWORD_MAP.put("milk tea", 1); CATEGORY_KEYWORD_MAP.put("bubble tea", 1);
        CATEGORY_KEYWORD_MAP.put("cà phê", 1); CATEGORY_KEYWORD_MAP.put("coffee", 1);
        CATEGORY_KEYWORD_MAP.put("cafe", 1); CATEGORY_KEYWORD_MAP.put("nước uống", 1);
        CATEGORY_KEYWORD_MAP.put("nước ngọt", 1); CATEGORY_KEYWORD_MAP.put("nước ép", 1);
        CATEGORY_KEYWORD_MAP.put("sinh tố", 1); CATEGORY_KEYWORD_MAP.put("bia", 1);
        CATEGORY_KEYWORD_MAP.put("rượu", 1); CATEGORY_KEYWORD_MAP.put("phở", 1);
        CATEGORY_KEYWORD_MAP.put("bún", 1); CATEGORY_KEYWORD_MAP.put("mì", 1);
        CATEGORY_KEYWORD_MAP.put("cơm", 1); CATEGORY_KEYWORD_MAP.put("cháo", 1);
        CATEGORY_KEYWORD_MAP.put("bánh mì", 1); CATEGORY_KEYWORD_MAP.put("xôi", 1);
        CATEGORY_KEYWORD_MAP.put("lẩu", 1); CATEGORY_KEYWORD_MAP.put("nướng", 1);
        CATEGORY_KEYWORD_MAP.put("sushi", 1); CATEGORY_KEYWORD_MAP.put("pizza", 1);
        CATEGORY_KEYWORD_MAP.put("hamburger", 1); CATEGORY_KEYWORD_MAP.put("fastfood", 1);
        CATEGORY_KEYWORD_MAP.put("breakfast", 1); CATEGORY_KEYWORD_MAP.put("lunch", 1);
        CATEGORY_KEYWORD_MAP.put("dinner", 1); CATEGORY_KEYWORD_MAP.put("snack", 1);
        CATEGORY_KEYWORD_MAP.put("restaurant", 1); CATEGORY_KEYWORD_MAP.put("food", 1);
        CATEGORY_KEYWORD_MAP.put("eat", 1); CATEGORY_KEYWORD_MAP.put("meal", 1);
        CATEGORY_KEYWORD_MAP.put("ăn", 1);
        // Brand fast food/đồ uống phổ biến → Food (1)
        CATEGORY_KEYWORD_MAP.put("kfc", 1); CATEGORY_KEYWORD_MAP.put("mcdonald", 1);
        CATEGORY_KEYWORD_MAP.put("burger king", 1); CATEGORY_KEYWORD_MAP.put("jollibee", 1);
        CATEGORY_KEYWORD_MAP.put("lotteria", 1); CATEGORY_KEYWORD_MAP.put("texas chicken", 1);
        CATEGORY_KEYWORD_MAP.put("popeyes", 1); CATEGORY_KEYWORD_MAP.put("pizza hut", 1);
        CATEGORY_KEYWORD_MAP.put("domino", 1); CATEGORY_KEYWORD_MAP.put("subway", 1);
        CATEGORY_KEYWORD_MAP.put("starbucks", 1); CATEGORY_KEYWORD_MAP.put("highland", 1);
        CATEGORY_KEYWORD_MAP.put("phúc long", 1); CATEGORY_KEYWORD_MAP.put("gong cha", 1);
        CATEGORY_KEYWORD_MAP.put("gongcha", 1); CATEGORY_KEYWORD_MAP.put("tocotoco", 1);
        CATEGORY_KEYWORD_MAP.put("toco toco", 1); CATEGORY_KEYWORD_MAP.put("the coffee house", 1);
        CATEGORY_KEYWORD_MAP.put("bách hóa xanh", 1); CATEGORY_KEYWORD_MAP.put("winmart", 1);
        CATEGORY_KEYWORD_MAP.put("đi ăn", 1); CATEGORY_KEYWORD_MAP.put("gà rán", 1);
        CATEGORY_KEYWORD_MAP.put("trà đá", 1); CATEGORY_KEYWORD_MAP.put("nước mía", 1);

        // Insurance (2)
        CATEGORY_KEYWORD_MAP.put("bảo hiểm", 2); CATEGORY_KEYWORD_MAP.put("bhxh", 2);
        CATEGORY_KEYWORD_MAP.put("bhyt", 2); CATEGORY_KEYWORD_MAP.put("insurance", 2);
        CATEGORY_KEYWORD_MAP.put("premium", 2);

        // Investment (4)
        CATEGORY_KEYWORD_MAP.put("đầu tư", 4); CATEGORY_KEYWORD_MAP.put("cổ phiếu", 4);
        CATEGORY_KEYWORD_MAP.put("chứng khoán", 4); CATEGORY_KEYWORD_MAP.put("trái phiếu", 4);
        CATEGORY_KEYWORD_MAP.put("bitcoin", 4); CATEGORY_KEYWORD_MAP.put("crypto", 4);
        CATEGORY_KEYWORD_MAP.put("mua vàng", 4); CATEGORY_KEYWORD_MAP.put("forex", 4);
        CATEGORY_KEYWORD_MAP.put("investment", 4); CATEGORY_KEYWORD_MAP.put("stock", 4);

        // Transportation (5)
        CATEGORY_KEYWORD_MAP.put("đi taxi", 5); CATEGORY_KEYWORD_MAP.put("đi grab", 5);
        CATEGORY_KEYWORD_MAP.put("đi be", 5); CATEGORY_KEYWORD_MAP.put("đi xe", 5);
        CATEGORY_KEYWORD_MAP.put("đi xe buýt", 5); CATEGORY_KEYWORD_MAP.put("đi bus", 5);
        CATEGORY_KEYWORD_MAP.put("đi tàu", 5); CATEGORY_KEYWORD_MAP.put("đi metro", 5);
        CATEGORY_KEYWORD_MAP.put("đổ xăng", 5); CATEGORY_KEYWORD_MAP.put("xăng", 5);
        CATEGORY_KEYWORD_MAP.put("vé xe", 5); CATEGORY_KEYWORD_MAP.put("vé tàu", 5);
        CATEGORY_KEYWORD_MAP.put("vé máy bay", 5); CATEGORY_KEYWORD_MAP.put("gửi xe", 5);
        CATEGORY_KEYWORD_MAP.put("phí toll", 5); CATEGORY_KEYWORD_MAP.put("taxi", 5);
        CATEGORY_KEYWORD_MAP.put("grab", 5); CATEGORY_KEYWORD_MAP.put("uber", 5);
        CATEGORY_KEYWORD_MAP.put("parking", 5); CATEGORY_KEYWORD_MAP.put("fuel", 5);
        CATEGORY_KEYWORD_MAP.put("transport", 5);

        // Family (6)
        CATEGORY_KEYWORD_MAP.put("biếu bố mẹ", 6); CATEGORY_KEYWORD_MAP.put("gửi tiền về nhà", 6);
        CATEGORY_KEYWORD_MAP.put("tiền gia đình", 6); CATEGORY_KEYWORD_MAP.put("nuôi con", 6);
        CATEGORY_KEYWORD_MAP.put("học phí con", 6); CATEGORY_KEYWORD_MAP.put("family", 6);

        // Entertainment (7)
        CATEGORY_KEYWORD_MAP.put("xem phim", 7); CATEGORY_KEYWORD_MAP.put("rạp phim", 7);
        CATEGORY_KEYWORD_MAP.put("karaoke", 7); CATEGORY_KEYWORD_MAP.put("chơi game", 7);
        CATEGORY_KEYWORD_MAP.put("giải trí", 7); CATEGORY_KEYWORD_MAP.put("vui chơi", 7);
        CATEGORY_KEYWORD_MAP.put("concert", 7); CATEGORY_KEYWORD_MAP.put("cinema", 7);
        CATEGORY_KEYWORD_MAP.put("entertainment", 7); CATEGORY_KEYWORD_MAP.put("movie", 7);
        CATEGORY_KEYWORD_MAP.put("bar", 7); CATEGORY_KEYWORD_MAP.put("pub", 7);
        CATEGORY_KEYWORD_MAP.put("club", 7); CATEGORY_KEYWORD_MAP.put("bowling", 7);

        // Education (8)
        CATEGORY_KEYWORD_MAP.put("học phí", 8); CATEGORY_KEYWORD_MAP.put("tiền học", 8);
        CATEGORY_KEYWORD_MAP.put("khóa học", 8); CATEGORY_KEYWORD_MAP.put("mua sách", 8);
        CATEGORY_KEYWORD_MAP.put("gia sư", 8); CATEGORY_KEYWORD_MAP.put("luyện thi", 8);
        CATEGORY_KEYWORD_MAP.put("ielts", 8); CATEGORY_KEYWORD_MAP.put("toeic", 8);
        CATEGORY_KEYWORD_MAP.put("education", 8); CATEGORY_KEYWORD_MAP.put("tuition", 8);
        CATEGORY_KEYWORD_MAP.put("course", 8); CATEGORY_KEYWORD_MAP.put("udemy", 8);

        // Shopping (10)
        CATEGORY_KEYWORD_MAP.put("mua sắm", 10); CATEGORY_KEYWORD_MAP.put("mua quần áo", 10);
        CATEGORY_KEYWORD_MAP.put("mua đồ", 10); CATEGORY_KEYWORD_MAP.put("quần áo", 10);
        CATEGORY_KEYWORD_MAP.put("giày dép", 10); CATEGORY_KEYWORD_MAP.put("túi xách", 10);
        CATEGORY_KEYWORD_MAP.put("shopping", 10); CATEGORY_KEYWORD_MAP.put("shopee", 10);
        CATEGORY_KEYWORD_MAP.put("lazada", 10); CATEGORY_KEYWORD_MAP.put("tiki", 10);
        // Sách, truyện, đồ dùng → Shopping (10), KHÔNG phải Education
        CATEGORY_KEYWORD_MAP.put("truyện tranh", 10); CATEGORY_KEYWORD_MAP.put("manga", 10);
        CATEGORY_KEYWORD_MAP.put("comic", 10); CATEGORY_KEYWORD_MAP.put("mua truyện", 10);
        CATEGORY_KEYWORD_MAP.put("light novel", 10); CATEGORY_KEYWORD_MAP.put("mua manga", 10);

        // Gifts & Donations (11)
        CATEGORY_KEYWORD_MAP.put("tặng quà", 11); CATEGORY_KEYWORD_MAP.put("mua quà", 11);
        CATEGORY_KEYWORD_MAP.put("quà sinh nhật", 11); CATEGORY_KEYWORD_MAP.put("phong bì", 11);
        CATEGORY_KEYWORD_MAP.put("mừng cưới", 11); CATEGORY_KEYWORD_MAP.put("lì xì", 11);
        CATEGORY_KEYWORD_MAP.put("mừng tuổi", 11); CATEGORY_KEYWORD_MAP.put("quyên góp", 11);
        CATEGORY_KEYWORD_MAP.put("từ thiện", 11); CATEGORY_KEYWORD_MAP.put("gift", 11);
        CATEGORY_KEYWORD_MAP.put("charity", 11); CATEGORY_KEYWORD_MAP.put("donate", 11);

        // Health (12)
        CATEGORY_KEYWORD_MAP.put("mua thuốc", 12); CATEGORY_KEYWORD_MAP.put("nhà thuốc", 12);
        CATEGORY_KEYWORD_MAP.put("bệnh viện", 12); CATEGORY_KEYWORD_MAP.put("phòng khám", 12);
        CATEGORY_KEYWORD_MAP.put("bác sĩ", 12); CATEGORY_KEYWORD_MAP.put("chữa bệnh", 12);
        CATEGORY_KEYWORD_MAP.put("điều trị", 12); CATEGORY_KEYWORD_MAP.put("phẫu thuật", 12);
        CATEGORY_KEYWORD_MAP.put("nha sĩ", 12); CATEGORY_KEYWORD_MAP.put("khám răng", 12);
        CATEGORY_KEYWORD_MAP.put("thuốc", 12); CATEGORY_KEYWORD_MAP.put("vitamin", 12);
        CATEGORY_KEYWORD_MAP.put("pharmacy", 12); CATEGORY_KEYWORD_MAP.put("hospital", 12);
        CATEGORY_KEYWORD_MAP.put("doctor", 12); CATEGORY_KEYWORD_MAP.put("medicine", 12);
        CATEGORY_KEYWORD_MAP.put("dentist", 12);

        // Transfer Out (13)
        CATEGORY_KEYWORD_MAP.put("chuyển tiền", 13); CATEGORY_KEYWORD_MAP.put("chuyển khoản", 13);
        CATEGORY_KEYWORD_MAP.put("gửi tiền", 13); CATEGORY_KEYWORD_MAP.put("chuyển cho", 13);
        CATEGORY_KEYWORD_MAP.put("transfer", 13); CATEGORY_KEYWORD_MAP.put("send money", 13);

        // Interest Payment (14)
        CATEGORY_KEYWORD_MAP.put("trả lãi", 14); CATEGORY_KEYWORD_MAP.put("đóng lãi", 14);
        CATEGORY_KEYWORD_MAP.put("lãi vay", 14); CATEGORY_KEYWORD_MAP.put("interest payment", 14);

        // Salary (15) - Income
        CATEGORY_KEYWORD_MAP.put("lương", 15); CATEGORY_KEYWORD_MAP.put("nhận lương", 15);
        CATEGORY_KEYWORD_MAP.put("tiền lương", 15); CATEGORY_KEYWORD_MAP.put("salary", 15);
        CATEGORY_KEYWORD_MAP.put("wage", 15); CATEGORY_KEYWORD_MAP.put("paycheck", 15);

        // Interest Received (16) - Income
        CATEGORY_KEYWORD_MAP.put("thu lãi", 16); CATEGORY_KEYWORD_MAP.put("nhận lãi", 16);
        CATEGORY_KEYWORD_MAP.put("lãi tiết kiệm", 16); CATEGORY_KEYWORD_MAP.put("cổ tức", 16);
        CATEGORY_KEYWORD_MAP.put("dividend", 16);

        // Other Income (17) - Income
        CATEGORY_KEYWORD_MAP.put("thưởng", 17); CATEGORY_KEYWORD_MAP.put("tiền thưởng", 17);
        CATEGORY_KEYWORD_MAP.put("hoa hồng", 17); CATEGORY_KEYWORD_MAP.put("freelance", 17);
        CATEGORY_KEYWORD_MAP.put("làm thêm", 17); CATEGORY_KEYWORD_MAP.put("trúng thưởng", 17);
        CATEGORY_KEYWORD_MAP.put("xổ số", 17); CATEGORY_KEYWORD_MAP.put("bonus", 17);

        // Transfer In (18) - Income
        CATEGORY_KEYWORD_MAP.put("nhận tiền", 18); CATEGORY_KEYWORD_MAP.put("nhận chuyển khoản", 18);
        CATEGORY_KEYWORD_MAP.put("được chuyển", 18); CATEGORY_KEYWORD_MAP.put("receive money", 18);

        // Lending (19)
        CATEGORY_KEYWORD_MAP.put("cho vay", 19); CATEGORY_KEYWORD_MAP.put("cho mượn", 19);
        CATEGORY_KEYWORD_MAP.put("lending", 19); CATEGORY_KEYWORD_MAP.put("lend", 19);

        // Borrowing (20) - Income
        CATEGORY_KEYWORD_MAP.put("vay tiền", 20); CATEGORY_KEYWORD_MAP.put("mượn tiền", 20);
        CATEGORY_KEYWORD_MAP.put("vay ngân hàng", 20); CATEGORY_KEYWORD_MAP.put("borrow", 20);

        // Debt Collection (21) - Income
        CATEGORY_KEYWORD_MAP.put("thu nợ", 21); CATEGORY_KEYWORD_MAP.put("đòi nợ", 21);
        CATEGORY_KEYWORD_MAP.put("collect debt", 21);

        // Debt Repayment (22)
        CATEGORY_KEYWORD_MAP.put("trả nợ", 22); CATEGORY_KEYWORD_MAP.put("trả góp", 22);
        CATEGORY_KEYWORD_MAP.put("hoàn nợ", 22); CATEGORY_KEYWORD_MAP.put("pay debt", 22);
        CATEGORY_KEYWORD_MAP.put("installment", 22);

        // Vehicle Maintenance (23)
        CATEGORY_KEYWORD_MAP.put("bảo dưỡng xe", 23); CATEGORY_KEYWORD_MAP.put("sửa xe", 23);
        CATEGORY_KEYWORD_MAP.put("thay dầu", 23); CATEGORY_KEYWORD_MAP.put("thay nhớt", 23);
        CATEGORY_KEYWORD_MAP.put("thay lốp", 23); CATEGORY_KEYWORD_MAP.put("rửa xe", 23);
        CATEGORY_KEYWORD_MAP.put("đăng kiểm", 23); CATEGORY_KEYWORD_MAP.put("car repair", 23);
        CATEGORY_KEYWORD_MAP.put("oil change", 23); CATEGORY_KEYWORD_MAP.put("car wash", 23);

        // Home Services (24)
        CATEGORY_KEYWORD_MAP.put("dọn nhà", 24); CATEGORY_KEYWORD_MAP.put("dọn dẹp", 24);
        CATEGORY_KEYWORD_MAP.put("giặt ủi", 24); CATEGORY_KEYWORD_MAP.put("giặt đồ", 24);
        CATEGORY_KEYWORD_MAP.put("giúp việc", 24); CATEGORY_KEYWORD_MAP.put("cleaning", 24);
        CATEGORY_KEYWORD_MAP.put("laundry", 24);

        // Home Repair & Decor (25)
        CATEGORY_KEYWORD_MAP.put("sửa nhà", 25); CATEGORY_KEYWORD_MAP.put("trang trí nhà", 25);
        CATEGORY_KEYWORD_MAP.put("nội thất", 25); CATEGORY_KEYWORD_MAP.put("sơn nhà", 25);
        CATEGORY_KEYWORD_MAP.put("thợ xây", 25); CATEGORY_KEYWORD_MAP.put("thợ điện", 25);
        CATEGORY_KEYWORD_MAP.put("thợ nước", 25); CATEGORY_KEYWORD_MAP.put("furniture", 25);
        CATEGORY_KEYWORD_MAP.put("renovation", 25);

        // Pets (26)
        CATEGORY_KEYWORD_MAP.put("thú cưng", 26); CATEGORY_KEYWORD_MAP.put("vật nuôi", 26);
        CATEGORY_KEYWORD_MAP.put("thức ăn chó", 26); CATEGORY_KEYWORD_MAP.put("thức ăn mèo", 26);
        CATEGORY_KEYWORD_MAP.put("khám thú y", 26); CATEGORY_KEYWORD_MAP.put("pet", 26);
        CATEGORY_KEYWORD_MAP.put("vet", 26);

        // Online Services (27)
        CATEGORY_KEYWORD_MAP.put("netflix", 27); CATEGORY_KEYWORD_MAP.put("spotify", 27);
        CATEGORY_KEYWORD_MAP.put("youtube premium", 27); CATEGORY_KEYWORD_MAP.put("chatgpt", 27);
        CATEGORY_KEYWORD_MAP.put("subscription", 27); CATEGORY_KEYWORD_MAP.put("gia hạn", 27);

        // Travel & Leisure (28)
        CATEGORY_KEYWORD_MAP.put("du lịch", 28); CATEGORY_KEYWORD_MAP.put("đi du lịch", 28);
        CATEGORY_KEYWORD_MAP.put("nghỉ mát", 28); CATEGORY_KEYWORD_MAP.put("đi phượt", 28);
        CATEGORY_KEYWORD_MAP.put("khách sạn", 28); CATEGORY_KEYWORD_MAP.put("hotel", 28);
        CATEGORY_KEYWORD_MAP.put("resort", 28); CATEGORY_KEYWORD_MAP.put("homestay", 28);
        CATEGORY_KEYWORD_MAP.put("airbnb", 28); CATEGORY_KEYWORD_MAP.put("đặt phòng", 28);
        CATEGORY_KEYWORD_MAP.put("travel", 28); CATEGORY_KEYWORD_MAP.put("vacation", 28);

        // Electricity Bill (29)
        CATEGORY_KEYWORD_MAP.put("tiền điện", 29); CATEGORY_KEYWORD_MAP.put("hóa đơn điện", 29);
        CATEGORY_KEYWORD_MAP.put("electricity", 29); CATEGORY_KEYWORD_MAP.put("electric bill", 29);

        // Phone Bill (30)
        CATEGORY_KEYWORD_MAP.put("nạp điện thoại", 30); CATEGORY_KEYWORD_MAP.put("nạp thẻ", 30);
        CATEGORY_KEYWORD_MAP.put("cước điện thoại", 30); CATEGORY_KEYWORD_MAP.put("tiền điện thoại", 30);
        CATEGORY_KEYWORD_MAP.put("phone bill", 30); CATEGORY_KEYWORD_MAP.put("topup", 30);

        // Gas Bill (31)
        CATEGORY_KEYWORD_MAP.put("tiền gas", 31); CATEGORY_KEYWORD_MAP.put("bình gas", 31);
        CATEGORY_KEYWORD_MAP.put("gas bill", 31);

        // Internet Bill (32)
        CATEGORY_KEYWORD_MAP.put("tiền mạng", 32); CATEGORY_KEYWORD_MAP.put("tiền wifi", 32);
        CATEGORY_KEYWORD_MAP.put("cước internet", 32); CATEGORY_KEYWORD_MAP.put("internet bill", 32);

        // Water Bill (33)
        CATEGORY_KEYWORD_MAP.put("tiền nước", 33); CATEGORY_KEYWORD_MAP.put("hóa đơn nước", 33);
        CATEGORY_KEYWORD_MAP.put("water bill", 33);

        // Other Utility Bills (34)
        CATEGORY_KEYWORD_MAP.put("phí chung cư", 34); CATEGORY_KEYWORD_MAP.put("phí quản lý", 34);
        CATEGORY_KEYWORD_MAP.put("phí bảo trì", 34); CATEGORY_KEYWORD_MAP.put("phí rác", 34);

        // TV Bill (35)
        CATEGORY_KEYWORD_MAP.put("truyền hình cáp", 35); CATEGORY_KEYWORD_MAP.put("hóa đơn tv", 35);
        CATEGORY_KEYWORD_MAP.put("cable tv", 35); CATEGORY_KEYWORD_MAP.put("k+", 35);

        // Rent (36)
        CATEGORY_KEYWORD_MAP.put("tiền thuê nhà", 36); CATEGORY_KEYWORD_MAP.put("tiền trọ", 36);
        CATEGORY_KEYWORD_MAP.put("tiền phòng", 36); CATEGORY_KEYWORD_MAP.put("phòng trọ", 36);
        CATEGORY_KEYWORD_MAP.put("rent", 36);

        // Personal Items (37)
        CATEGORY_KEYWORD_MAP.put("đồ dùng cá nhân", 37); CATEGORY_KEYWORD_MAP.put("kem đánh răng", 37);
        CATEGORY_KEYWORD_MAP.put("dầu gội", 37); CATEGORY_KEYWORD_MAP.put("sữa tắm", 37);
        CATEGORY_KEYWORD_MAP.put("khẩu trang", 37); CATEGORY_KEYWORD_MAP.put("giấy vệ sinh", 37);
        CATEGORY_KEYWORD_MAP.put("personal items", 37);

        // Home Appliances (38)
        CATEGORY_KEYWORD_MAP.put("đồ gia dụng", 38); CATEGORY_KEYWORD_MAP.put("máy giặt", 38);
        CATEGORY_KEYWORD_MAP.put("tủ lạnh", 38); CATEGORY_KEYWORD_MAP.put("điều hòa", 38);
        CATEGORY_KEYWORD_MAP.put("máy lạnh", 38); CATEGORY_KEYWORD_MAP.put("lò vi sóng", 38);
        CATEGORY_KEYWORD_MAP.put("nồi cơm điện", 38); CATEGORY_KEYWORD_MAP.put("máy hút bụi", 38);
        CATEGORY_KEYWORD_MAP.put("home appliances", 38);

        // ===== KEYWORDS BỔ SUNG (cụm dài trước) =====

        // Vehicle Maintenance bổ sung (23)
        CATEGORY_KEYWORD_MAP.put("bảo trì xe máy", 23); CATEGORY_KEYWORD_MAP.put("bảo dưỡng xe máy", 23);
        CATEGORY_KEYWORD_MAP.put("bơm bánh xe", 23); CATEGORY_KEYWORD_MAP.put("vá xe", 23);
        CATEGORY_KEYWORD_MAP.put("thay vỏ xe", 23); CATEGORY_KEYWORD_MAP.put("thay phụ tùng", 23);
        CATEGORY_KEYWORD_MAP.put("sửa chữa xe", 23); CATEGORY_KEYWORD_MAP.put("bảo trì xe", 23);
        CATEGORY_KEYWORD_MAP.put("maintenance", 23); CATEGORY_KEYWORD_MAP.put("repair", 23);

        // Transportation bổ sung (5)
        CATEGORY_KEYWORD_MAP.put("đổ xăng", 5); CATEGORY_KEYWORD_MAP.put("mua xăng", 5);
        CATEGORY_KEYWORD_MAP.put("mua xe", 5); CATEGORY_KEYWORD_MAP.put("mua ô tô", 5);
        CATEGORY_KEYWORD_MAP.put("mua xe máy", 5); CATEGORY_KEYWORD_MAP.put("mua xe đạp", 5);
        CATEGORY_KEYWORD_MAP.put("phí giao thông", 5); CATEGORY_KEYWORD_MAP.put("toll fee", 5);

        // Education bổ sung (8)
        CATEGORY_KEYWORD_MAP.put("đóng học phí cho con", 8); CATEGORY_KEYWORD_MAP.put("học phí cho con", 8);
        CATEGORY_KEYWORD_MAP.put("đóng học phí", 8); CATEGORY_KEYWORD_MAP.put("đóng tiền học", 8);
        CATEGORY_KEYWORD_MAP.put("học anh văn", 8); CATEGORY_KEYWORD_MAP.put("học tiếng anh", 8);
        CATEGORY_KEYWORD_MAP.put("học thêm", 8); CATEGORY_KEYWORD_MAP.put("học coding", 8);
        CATEGORY_KEYWORD_MAP.put("học lập trình", 8);

        // Rent bổ sung (36)
        CATEGORY_KEYWORD_MAP.put("thuê nhà", 36); CATEGORY_KEYWORD_MAP.put("tiền thuê", 36);
        CATEGORY_KEYWORD_MAP.put("thuê phòng", 36); CATEGORY_KEYWORD_MAP.put("đóng tiền phòng", 36);
        CATEGORY_KEYWORD_MAP.put("trả tiền trọ", 36);

        // Other Utility Bills bổ sung (34)
        CATEGORY_KEYWORD_MAP.put("thuế đất", 34); CATEGORY_KEYWORD_MAP.put("thuế nhà", 34);
        CATEGORY_KEYWORD_MAP.put("đóng thuế", 34); CATEGORY_KEYWORD_MAP.put("nộp thuế", 34);
        CATEGORY_KEYWORD_MAP.put("phí dịch vụ", 34); CATEGORY_KEYWORD_MAP.put("service fee", 34);

        // Salary bổ sung (15) - Income
        CATEGORY_KEYWORD_MAP.put("lãnh lương", 15); CATEGORY_KEYWORD_MAP.put("nhận lương", 15);
        CATEGORY_KEYWORD_MAP.put("phát lương", 15); CATEGORY_KEYWORD_MAP.put("ứng lương", 15);
        CATEGORY_KEYWORD_MAP.put("tiền công", 15); CATEGORY_KEYWORD_MAP.put("công nhật", 15);
        CATEGORY_KEYWORD_MAP.put("income", 15); CATEGORY_KEYWORD_MAP.put("earn", 15);
        CATEGORY_KEYWORD_MAP.put("earned", 15); CATEGORY_KEYWORD_MAP.put("received salary", 15);

        // Debt Repayment bổ sung (22)
        CATEGORY_KEYWORD_MAP.put("trả nợ", 22); CATEGORY_KEYWORD_MAP.put("thanh toán nợ", 22);
        CATEGORY_KEYWORD_MAP.put("hoàn tiền", 22); CATEGORY_KEYWORD_MAP.put("trả lại tiền", 22);
        CATEGORY_KEYWORD_MAP.put("đóng tiền", 22); CATEGORY_KEYWORD_MAP.put("nộp tiền", 22);
        CATEGORY_KEYWORD_MAP.put("trả tiền", 22); CATEGORY_KEYWORD_MAP.put("pay back", 22);
        CATEGORY_KEYWORD_MAP.put("repay", 22); CATEGORY_KEYWORD_MAP.put("settle debt", 22);

        // Debt Collection bổ sung (21) - Income
        CATEGORY_KEYWORD_MAP.put("đòi tiền", 21); CATEGORY_KEYWORD_MAP.put("lấy lại tiền", 21);
        CATEGORY_KEYWORD_MAP.put("thu nợ", 21);
        // "thu tiền" generic → Other Income (17), không phải Debt Collection
        // vì "thu tiền nhà/phòng" = thu nhập cho thuê, "thu tiền bán hàng" = thu nhập bán hàng
        CATEGORY_KEYWORD_MAP.put("thu tiền nhà", 17); CATEGORY_KEYWORD_MAP.put("thu tiền phòng", 17);
        CATEGORY_KEYWORD_MAP.put("thu tiền thuê", 17); CATEGORY_KEYWORD_MAP.put("thu tiền bán", 17);
        CATEGORY_KEYWORD_MAP.put("thu tiền", 17);
        CATEGORY_KEYWORD_MAP.put("collect", 21); CATEGORY_KEYWORD_MAP.put("recovered", 21);

        // Borrowing bổ sung (20) - Income
        CATEGORY_KEYWORD_MAP.put("cầm đồ", 20); CATEGORY_KEYWORD_MAP.put("thế chấp", 20);
        CATEGORY_KEYWORD_MAP.put("vay nợ", 20); CATEGORY_KEYWORD_MAP.put("vay tín dụng", 20);
        CATEGORY_KEYWORD_MAP.put("vay nóng", 20); CATEGORY_KEYWORD_MAP.put("vay nặng lãi", 20);

        // Lending bổ sung (19)
        CATEGORY_KEYWORD_MAP.put("cho mượn", 19); CATEGORY_KEYWORD_MAP.put("cho bạn vay", 19);
        CATEGORY_KEYWORD_MAP.put("cho anh vay", 19); CATEGORY_KEYWORD_MAP.put("cho em vay", 19);
        CATEGORY_KEYWORD_MAP.put("loan out", 19);

        // Investment bổ sung (4)
        CATEGORY_KEYWORD_MAP.put("tiết kiệm", 4); CATEGORY_KEYWORD_MAP.put("bỏ ống heo", 4);
        CATEGORY_KEYWORD_MAP.put("gửi tiết kiệm", 4); CATEGORY_KEYWORD_MAP.put("mua vàng", 4);
        CATEGORY_KEYWORD_MAP.put("đầu tư bất động sản", 4); CATEGORY_KEYWORD_MAP.put("saving", 4);
        CATEGORY_KEYWORD_MAP.put("save money", 4); CATEGORY_KEYWORD_MAP.put("invest", 4);

        // Other Income bổ sung (17) - Income
        CATEGORY_KEYWORD_MAP.put("bán nhà", 17); CATEGORY_KEYWORD_MAP.put("bán xe", 17);
        CATEGORY_KEYWORD_MAP.put("bán đồ", 17); CATEGORY_KEYWORD_MAP.put("bán hàng", 17);
        CATEGORY_KEYWORD_MAP.put("ký hợp đồng", 17); CATEGORY_KEYWORD_MAP.put("thanh lý", 17);
        CATEGORY_KEYWORD_MAP.put("kiếm thêm", 17); CATEGORY_KEYWORD_MAP.put("làm tự do", 17);
        CATEGORY_KEYWORD_MAP.put("side job", 17); CATEGORY_KEYWORD_MAP.put("sell", 17);
        CATEGORY_KEYWORD_MAP.put("sold", 17);

        // Shopping bổ sung (10)
        CATEGORY_KEYWORD_MAP.put("mua điện thoại", 10); CATEGORY_KEYWORD_MAP.put("mua laptop", 10);
        CATEGORY_KEYWORD_MAP.put("mua máy tính", 10); CATEGORY_KEYWORD_MAP.put("mua iphone", 10);
        CATEGORY_KEYWORD_MAP.put("mua samsung", 10); CATEGORY_KEYWORD_MAP.put("mua sắm", 10);
        CATEGORY_KEYWORD_MAP.put("mua quà", 10); CATEGORY_KEYWORD_MAP.put("mua đồ", 10);
        CATEGORY_KEYWORD_MAP.put("order", 10); CATEGORY_KEYWORD_MAP.put("purchase", 10);
        CATEGORY_KEYWORD_MAP.put("buy", 10); CATEGORY_KEYWORD_MAP.put("bought", 10);

        // Entertainment bổ sung (7)
        CATEGORY_KEYWORD_MAP.put("game", 7); CATEGORY_KEYWORD_MAP.put("gaming", 7);

        // Family bổ sung (6)
        CATEGORY_KEYWORD_MAP.put("chăm sóc người thân", 6); CATEGORY_KEYWORD_MAP.put("chăm bệnh", 6);
        CATEGORY_KEYWORD_MAP.put("chăm người bệnh", 6); CATEGORY_KEYWORD_MAP.put("nuôi dưỡng", 6);
        CATEGORY_KEYWORD_MAP.put("phụng dưỡng", 6); CATEGORY_KEYWORD_MAP.put("chu cấp", 6);
        CATEGORY_KEYWORD_MAP.put("take care", 6);

        // Home Repair bổ sung (25)
        CATEGORY_KEYWORD_MAP.put("mua nhà", 25); CATEGORY_KEYWORD_MAP.put("xây nhà", 25);
        CATEGORY_KEYWORD_MAP.put("cải tạo nhà", 25); CATEGORY_KEYWORD_MAP.put("xây dựng", 25);

        // Transfer In bổ sung (18) - Income
        CATEGORY_KEYWORD_MAP.put("receive", 18); CATEGORY_KEYWORD_MAP.put("received", 18);
        CATEGORY_KEYWORD_MAP.put("got money", 18); CATEGORY_KEYWORD_MAP.put("nhận được tiền", 18);

        // General expense fallback (3)
        CATEGORY_KEYWORD_MAP.put("chi tiêu", 3); CATEGORY_KEYWORD_MAP.put("chi phí", 3);
        CATEGORY_KEYWORD_MAP.put("tiêu tiền", 3); CATEGORY_KEYWORD_MAP.put("expense", 3);
        CATEGORY_KEYWORD_MAP.put("spend", 3); CATEGORY_KEYWORD_MAP.put("spent", 3);
        CATEGORY_KEYWORD_MAP.put("paid", 3); CATEGORY_KEYWORD_MAP.put("pay", 3);

        // ===== ĐỘNG TỪ HÀNH ĐỘNG (cụm dài → đơn, đặt cuối để ưu tiên thấp) =====

        // BÁN = thu (Income) → Other Income (17)
        CATEGORY_KEYWORD_MAP.put("bán đồ cũ", 17); CATEGORY_KEYWORD_MAP.put("bán hàng online", 17);
        CATEGORY_KEYWORD_MAP.put("bán online", 17); CATEGORY_KEYWORD_MAP.put("bán thanh lý", 17);
        CATEGORY_KEYWORD_MAP.put("bán lại", 17); CATEGORY_KEYWORD_MAP.put("bán được", 17);

        // LẤY = thu (Income) → Debt Collection (21)
        CATEGORY_KEYWORD_MAP.put("lấy tiền về", 21); CATEGORY_KEYWORD_MAP.put("lấy lại tiền", 21);
        CATEGORY_KEYWORD_MAP.put("lấy tiền", 21); CATEGORY_KEYWORD_MAP.put("lấy lại", 21);

        // THU = thu nhập (Income) → Other Income (17)
        CATEGORY_KEYWORD_MAP.put("thu nhập thêm", 17); CATEGORY_KEYWORD_MAP.put("thu nhập từ", 17);
        CATEGORY_KEYWORD_MAP.put("thu nhập", 17);

        // CHO / BIẾU / TẶNG = chi (Expense) → Gifts & Donations (11)
        CATEGORY_KEYWORD_MAP.put("cho tiền con", 11); CATEGORY_KEYWORD_MAP.put("cho tiền bạn", 11);
        CATEGORY_KEYWORD_MAP.put("cho tiền vợ", 11); CATEGORY_KEYWORD_MAP.put("cho tiền chồng", 11);
        CATEGORY_KEYWORD_MAP.put("biếu tiền", 11); CATEGORY_KEYWORD_MAP.put("tặng tiền", 11);
        CATEGORY_KEYWORD_MAP.put("cho tiền", 11); CATEGORY_KEYWORD_MAP.put("biếu", 11);
        CATEGORY_KEYWORD_MAP.put("tặng", 11);

        // TRẢ = chi (Expense) → Debt Repayment (22)
        CATEGORY_KEYWORD_MAP.put("trả tiền thuê", 36); CATEGORY_KEYWORD_MAP.put("trả tiền nhà", 36);
        CATEGORY_KEYWORD_MAP.put("trả tiền điện", 29); CATEGORY_KEYWORD_MAP.put("trả tiền nước", 33);
        CATEGORY_KEYWORD_MAP.put("trả tiền mạng", 32); CATEGORY_KEYWORD_MAP.put("trả tiền xe", 22);
        CATEGORY_KEYWORD_MAP.put("trả góp xe", 22); CATEGORY_KEYWORD_MAP.put("trả góp nhà", 22);
        CATEGORY_KEYWORD_MAP.put("thanh toán", 22);

        // SỬA = chi (Expense): sửa nhà → 25, sửa xe → 23, sửa chữa đồ → 3
        CATEGORY_KEYWORD_MAP.put("sửa nhà cửa", 25); CATEGORY_KEYWORD_MAP.put("sửa chữa nhà", 25);
        CATEGORY_KEYWORD_MAP.put("sửa xe máy", 23); CATEGORY_KEYWORD_MAP.put("sửa ô tô", 23);
        CATEGORY_KEYWORD_MAP.put("sửa điện thoại", 38); CATEGORY_KEYWORD_MAP.put("sửa máy tính", 38);
        CATEGORY_KEYWORD_MAP.put("sửa điện", 25); CATEGORY_KEYWORD_MAP.put("sửa nước", 25);
        CATEGORY_KEYWORD_MAP.put("sửa chữa", 3);

        // RỬA = chi (Expense): rửa xe → 23, rửa bát/dọn dẹp → 24
        CATEGORY_KEYWORD_MAP.put("rửa xe ô tô", 23); CATEGORY_KEYWORD_MAP.put("rửa xe máy", 23);
        CATEGORY_KEYWORD_MAP.put("rửa bát", 24); CATEGORY_KEYWORD_MAP.put("rửa dọn", 24);

        // NỘP = chi (Expense) → tùy ngữ cảnh: học phí/thuế/tiền nhà
        CATEGORY_KEYWORD_MAP.put("nộp học phí", 8); CATEGORY_KEYWORD_MAP.put("nộp thuế", 34);
        CATEGORY_KEYWORD_MAP.put("nộp phí", 34); CATEGORY_KEYWORD_MAP.put("nộp bảo hiểm", 2);

        // NHẬN = thu (Income) → Transfer In (18)
        CATEGORY_KEYWORD_MAP.put("nhận thưởng", 17); CATEGORY_KEYWORD_MAP.put("nhận hoa hồng", 17);
        CATEGORY_KEYWORD_MAP.put("nhận thu nhập", 17); CATEGORY_KEYWORD_MAP.put("nhận được", 18);
        CATEGORY_KEYWORD_MAP.put("nhận", 18);

        // MUA = chi (Expense) → Shopping (10) nếu không có context cụ thể
        CATEGORY_KEYWORD_MAP.put("mua thực phẩm", 1); CATEGORY_KEYWORD_MAP.put("mua đồ ăn", 1);
        CATEGORY_KEYWORD_MAP.put("mua thuốc tây", 12); CATEGORY_KEYWORD_MAP.put("mua bảo hiểm", 2);
        CATEGORY_KEYWORD_MAP.put("mua vé máy bay", 28); CATEGORY_KEYWORD_MAP.put("mua vé tàu", 5);
        CATEGORY_KEYWORD_MAP.put("mua", 10);

        // ĐI = chi: đi ăn → Food (1), đi chơi → Entertainment (7), đi học → Education (8)
        CATEGORY_KEYWORD_MAP.put("đi ăn uống", 1); CATEGORY_KEYWORD_MAP.put("đi nhà hàng", 1);
        CATEGORY_KEYWORD_MAP.put("đi chơi", 7); CATEGORY_KEYWORD_MAP.put("đi xem phim", 7);
        CATEGORY_KEYWORD_MAP.put("đi học", 8); CATEGORY_KEYWORD_MAP.put("đi du học", 8);
        CATEGORY_KEYWORD_MAP.put("đi khám", 40); CATEGORY_KEYWORD_MAP.put("đi bệnh viện", 12);
        CATEGORY_KEYWORD_MAP.put("đi spa", 39); CATEGORY_KEYWORD_MAP.put("đi cắt tóc", 39);

        // ĐÓNG = chi (Expense) → tùy context
        CATEGORY_KEYWORD_MAP.put("đóng bảo hiểm", 2); CATEGORY_KEYWORD_MAP.put("đóng phí bảo hiểm", 2);
        CATEGORY_KEYWORD_MAP.put("đóng tiền điện", 29); CATEGORY_KEYWORD_MAP.put("đóng tiền nước", 33);
        CATEGORY_KEYWORD_MAP.put("đóng tiền mạng", 32); CATEGORY_KEYWORD_MAP.put("đóng tiền trọ", 36);

        // ===== TỪ ĐƠN (ưu tiên THẤP NHẤT - chỉ match khi không có cụm nào phù hợp) =====
        CATEGORY_KEYWORD_MAP.put("bán", 17);   // bán = thu nhập
        CATEGORY_KEYWORD_MAP.put("thu", 17);   // thu = thu nhập chung (Other Income)
        CATEGORY_KEYWORD_MAP.put("trả", 22);   // trả = trả nợ/chi
        CATEGORY_KEYWORD_MAP.put("nộp", 34);   // nộp = đóng các khoản
        CATEGORY_KEYWORD_MAP.put("sửa", 3);    // sửa = chi sửa chữa
        CATEGORY_KEYWORD_MAP.put("rửa", 23);   // rửa (xe) = bảo trì

        // Sort keyword theo độ dài giảm dần để đảm bảo cụm dài match trước
        LinkedHashMap<String, Integer> sortedMap = new LinkedHashMap<>();
        CATEGORY_KEYWORD_MAP.entrySet().stream()
                .sorted((e1, e2) -> Integer.compare(e2.getKey().length(), e1.getKey().length()))
                .forEach(entry -> sortedMap.put(entry.getKey(), entry.getValue()));
        CATEGORY_KEYWORD_MAP.clear();
        CATEGORY_KEYWORD_MAP.putAll(sortedMap);
    }

    /**
     * [1.1] Match category từ text/note sang categoryId.
     * Dùng cho cả AI Chat và OCR Receipt.
     * Logic: Duyệt LinkedHashMap (đã sort theo độ dài giảm dần) → match đầu tiên thắng.
     * Static block sort keyword theo độ dài giảm dần để đảm bảo cụm dài match trước,
     * tránh match nhầm khi có cả cụm dài và từ ngắn.
     * VD: "khám sức khỏe" (40) sẽ match trước "khám" (nếu có),
     * "grab food" (1) sẽ match trước "grab" (5).
     */
    public int mapCategoryFromText(String text) {
        if (text == null || text.trim().isEmpty()) {
            return 0; // Không có text → return 0 để AI xử lý
        }
        String msg = text.toLowerCase().trim();
        for (Map.Entry<String, Integer> entry : CATEGORY_KEYWORD_MAP.entrySet()) {
            if (msg.contains(entry.getKey())) {
                return entry.getValue();
            }
        }
        return 0; // Không match → để AI xử lý
    }
}
