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
        return 'Food & Beverage';
      case SystemCategory.insurance:
        return 'Insurance';
      case SystemCategory.otherExpense:
        return 'Other Expense';
      case SystemCategory.investment:
        return 'Investment';
      case SystemCategory.transportation:
        return 'Transportation';
      case SystemCategory.family:
        return 'Family';
      case SystemCategory.entertainment:
        return 'Entertainment';
      case SystemCategory.education:
        return 'Education';
      case SystemCategory.billsAndUtilities:
        return 'Bills & Utilities';
      case SystemCategory.shopping:
        return 'Shopping';
      case SystemCategory.giftsAndDonations:
        return 'Gifts & Donations';
      case SystemCategory.health:
        return 'Health';
      case SystemCategory.transferOut:
        return 'Transfer Out';
      case SystemCategory.interestPayment:
        return 'Interest Payment';
      case SystemCategory.salary:
        return 'Salary';
      case SystemCategory.interestReceive:
        return 'Interest Received';
      case SystemCategory.incomeOther:
        return 'Other Income';
      case SystemCategory.incomeTransfer:
        return 'Transfer In';
      case SystemCategory.debtLending:
        return 'Lending';
      case SystemCategory.debtBorrowing:
        return 'Borrowing';
      case SystemCategory.debtCollection:
        return 'Debt Collection';
      case SystemCategory.debtRepayment:
        return 'Debt Repayment';
      case SystemCategory.carMaintenance:
        return 'Car Maintenance';
      case SystemCategory.homeServices:
        return 'Home Services';
      case SystemCategory.homeDecor:
        return 'Home Decor';
      case SystemCategory.pets:
        return 'Pets';
      case SystemCategory.onlineServices:
        return 'Online Services';
      case SystemCategory.travel:
        return 'Travel';
      case SystemCategory.electricityBill:
        return 'Electricity Bill';
      case SystemCategory.phoneBill:
        return 'Phone Bill';
      case SystemCategory.gasBill:
        return 'Gas Bill';
      case SystemCategory.internetBill:
        return 'Internet Bill';
      case SystemCategory.waterBill:
        return 'Water Bill';
      case SystemCategory.otherUtilityBill:
        return 'Other Utility Bill';
      case SystemCategory.tvBill:
        return 'TV Bill';
      case SystemCategory.rental:
        return 'Rental';
    }
  }
}

