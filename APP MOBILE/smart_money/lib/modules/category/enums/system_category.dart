/// 36 danh mục hệ thống: Ăn uống, Bảo hiểm, Giao thông, v.v.
enum SystemCategory {
  // Chi tiêu
  foodAndBeverage,      // 1
  insurance,            // 2
  otherExpense,         // 3
  investment,           // 4
  transportation,       // 5
  family,               // 6
  entertainment,        // 7
  education,            // 8
  billsAndUtilities,    // 9
  shopping,             // 10
  giftsAndDonations,    // 11
  health,               // 12
  transferOut,          // 13
  interestPayment,      // 14

  // Thu nhập
  salary,               // 15
  interestReceive,      // 16
  incomeOther,          // 17
  incomeTransfer,       // 18

  // Nợ & Vay
  debtLending,          // 19
  debtBorrowing,        // 20
  debtCollection,       // 21
  debtRepayment,        // 22

  // Danh mục con
  carMaintenance,       // 23
  homeServices,         // 24
  homeDecor,            // 25
  pets,                 // 26
  onlineServices,       // 27
  travel,               // 28
  electricityBill,      // 29
  phoneBill,            // 30
  gasBill,              // 31
  internetBill,         // 32
  waterBill,            // 33
  otherUtilityBill,     // 34
  tvBill,               // 35
  rental;               // 36

  int get value => index + 1;

  static SystemCategory fromValue(int value) {
    if (value < 1 || value > 36) {
      return SystemCategory.otherExpense;
    }
    return SystemCategory.values[value - 1];
  }

  String get displayName {
    switch (this) {
      case SystemCategory.foodAndBeverage:
        return 'Ăn uống';
      case SystemCategory.insurance:
        return 'Bảo hiểm';
      case SystemCategory.otherExpense:
        return 'Chi phí khác';
      case SystemCategory.investment:
        return 'Đầu tư';
      case SystemCategory.transportation:
        return 'Di chuyển';
      case SystemCategory.family:
        return 'Gia đình';
      case SystemCategory.entertainment:
        return 'Giải trí';
      case SystemCategory.education:
        return 'Giáo dục';
      case SystemCategory.billsAndUtilities:
        return 'Hoá đơn & Tiện ích';
      case SystemCategory.shopping:
        return 'Mua sắm';
      case SystemCategory.giftsAndDonations:
        return 'Quà tặng & Quyên góp';
      case SystemCategory.health:
        return 'Sức khỏe';
      case SystemCategory.transferOut:
        return 'Tiền chuyển đi';
      case SystemCategory.interestPayment:
        return 'Trả lãi';
      case SystemCategory.salary:
        return 'Lương';
      case SystemCategory.interestReceive:
        return 'Thu lãi';
      case SystemCategory.incomeOther:
        return 'Thu nhập khác';
      case SystemCategory.incomeTransfer:
        return 'Tiền chuyển đến';
      case SystemCategory.debtLending:
        return 'Cho vay';
      case SystemCategory.debtBorrowing:
        return 'Đi vay';
      case SystemCategory.debtCollection:
        return 'Thu nợ';
      case SystemCategory.debtRepayment:
        return 'Trả nợ';
      case SystemCategory.carMaintenance:
        return 'Bảo dưỡng xe';
      case SystemCategory.homeServices:
        return 'Dịch vụ gia đình';
      case SystemCategory.homeDecor:
        return 'Sửa & trang trí nhà';
      case SystemCategory.pets:
        return 'Vật nuôi';
      case SystemCategory.onlineServices:
        return 'Dịch vụ trực tuyến';
      case SystemCategory.travel:
        return 'Vui - chơi';
      case SystemCategory.electricityBill:
        return 'Hoá đơn điện';
      case SystemCategory.phoneBill:
        return 'Hoá đơn điện thoại';
      case SystemCategory.gasBill:
        return 'Hoá đơn gas';
      case SystemCategory.internetBill:
        return 'Hoá đơn internet';
      case SystemCategory.waterBill:
        return 'Hoá đơn nước';
      case SystemCategory.otherUtilityBill:
        return 'Hoá đơn tiện ích khác';
      case SystemCategory.tvBill:
        return 'Hoá đơn TV';
      case SystemCategory.rental:
        return 'Thuê nhà';
    }
  }
}

