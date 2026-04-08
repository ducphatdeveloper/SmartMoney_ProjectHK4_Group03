enum ContactRequestType {
  SUSPICIOUS_TX,
  EMERGENCY,
  ACCOUNT_LOCK,
  ACCOUNT_UNLOCK,
  DATA_LOSS,
  FORGOT_PASSWORD,
  BUG_REPORT,
  DATA_RECOVERY,
  GENERAL
}

extension ContactRequestTypeExt on ContactRequestType {
  String get label {
    switch (this) {
      case ContactRequestType.ACCOUNT_LOCK: return "Yêu cầu khóa tài khoản";
      case ContactRequestType.ACCOUNT_UNLOCK: return "Mở khóa tài khoản";
      case ContactRequestType.FORGOT_PASSWORD: return "Quên mật khẩu";
      case ContactRequestType.EMERGENCY: return "Khẩn cấp (bị hack / giao dịch lạ)";
      case ContactRequestType.BUG_REPORT: return "Báo lỗi ứng dụng";
      case ContactRequestType.DATA_RECOVERY: return "Yêu cầu khôi phục dữ liệu";
      case ContactRequestType.DATA_LOSS: return "Báo mất dữ liệu";
      case ContactRequestType.GENERAL: return "Góp ý / câu hỏi";
      case ContactRequestType.SUSPICIOUS_TX: return "Giao dịch bất thường";
    }
  }
}

class ContactRequestCreateRequest {
  final ContactRequestType requestType;
  final String title;
  final String requestDescription;
  final String fullname;
  final String? contactPhone;
  final String? contactEmail;

  ContactRequestCreateRequest({
    required this.requestType,
    required this.title,
    required this.requestDescription,
    required this.fullname,
    this.contactPhone,
    this.contactEmail,
  });

  Map<String, dynamic> toJson() => {
    'requestType': requestType.name,
    'title': title,
    'requestDescription': requestDescription,
    'fullname': fullname,
    'contactPhone': contactPhone,
    'contactEmail': contactEmail,
  };
}

class ContactRequestResponse {
  final int id;
  final String requestType;
  final String requestPriority;
  final String requestStatus;
  final String fullname;
  final String? contactPhone;
  final String? contactEmail;
  final int? accId;
  final String title;
  final String requestDescription;
  final String? adminNote;
  final String createdAt;
  final String? updatedAt;

  ContactRequestResponse({
    required this.id,
    required this.requestType,
    required this.requestPriority,
    required this.requestStatus,
    required this.fullname,
    this.contactPhone,
    this.contactEmail,
    this.accId,
    required this.title,
    required this.requestDescription,
    this.adminNote,
    required this.createdAt,
    this.updatedAt,
  });

  factory ContactRequestResponse.fromJson(Map<String, dynamic> json) {
    return ContactRequestResponse(
      id: json['id'],
      requestType: json['requestType'] ?? '',
      requestPriority: json['requestPriority'] ?? '',
      requestStatus: json['requestStatus'] ?? '',
      fullname: json['fullname'] ?? '',
      contactPhone: json['contactPhone'],
      contactEmail: json['contactEmail'],
      accId: json['accId'],
      title: json['title'] ?? '',
      requestDescription: json['requestDescription'] ?? '',
      adminNote: json['adminNote'],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'],
    );
  }
}
