package fpt.aptech.server.enums.category;

import lombok.Getter;

@Getter
public enum SystemCategory {
    
    // ================= CHI TIÊU (EXPENSE) =================
    FOOD_AND_BEVERAGE(1),       // Ăn uống
    INSURANCE(2),               // Bảo hiểm
    OTHER_EXPENSE(3),           // Các chi phí khác
    INVESTMENT(4),              // Đầu tư
    TRANSPORTATION(5),          // Di chuyển
    FAMILY(6),                  // Gia đình
    ENTERTAINMENT(7),           // Giải trí
    EDUCATION(8),               // Giáo dục
    BILLS_AND_UTILITIES(9),     // Hoá đơn & Tiện ích
    SHOPPING(10),               // Mua sắm
    GIFTS_AND_DONATIONS(11),    // Quà tặng & Quyên góp
    HEALTH(12),                 // Sức khỏe
    TRANSFER_OUT(13),           // Tiền chuyển đi
    INTEREST_PAYMENT(14),       // Trả lãi
    
    // ================= THU NHẬP (INCOME) =================
    SALARY(15),                 // Lương
    INTEREST_RECEIVE(16),       // Thu lãi
    INCOME_OTHER(17),           // Thu nhập khác (Dùng khi tạo Wallet)
    INCOME_TRANSFER(18),        // Tiền chuyển đến (Dùng khi tạo Saving Goal)
    
    // ================= NỢ & VAY (DEBT & LOAN) =================
    DEBT_LENDING(19),           // Cho vay
    DEBT_BORROWING(20),         // Đi vay
    DEBT_COLLECTION(21),        // Thu nợ
    DEBT_REPAYMENT(22),         // Trả nợ

    // ================= DANH MỤC CON (SUB-CATEGORIES) =================
    CAR_MAINTENANCE(23),        // Bảo dưỡng xe
    HOME_SERVICES(24),          // Dịch vụ gia đình
    HOME_DECOR(25),             // Sửa & trang trí nhà
    PETS(26),                   // Vật nuôi
    ONLINE_SERVICES(27),        // Dịch vụ trực tuyến
    TRAVEL(28),                 // Vui - chơi
    ELECTRICITY_BILL(29),       // Hoá đơn điện
    PHONE_BILL(30),             // Hoá đơn điện thoại
    GAS_BILL(31),               // Hoá đơn gas
    INTERNET_BILL(32),          // Hoá đơn internet
    WATER_BILL(33),             // Hoá đơn nước
    OTHER_UTILITY_BILL(34),     // Hoá đơn tiện ích khác
    TV_BILL(35),                // Hoá đơn TV
    RENTAL(36),                 // Thuê nhà
    PERSONAL_ITEMS(37),         // Đồ dùng cá nhân
    HOME_APPLIANCES(38),        // Đồ gia dụng
    BEAUTY(39),                 // Làm đẹp
    MEDICAL_CHECKUP(40),        // Khám sức khoẻ
    SPORTS(41);                 // Thể dục thể thao

    private final int id;

    SystemCategory(int id) {
        this.id = id;
    }
}