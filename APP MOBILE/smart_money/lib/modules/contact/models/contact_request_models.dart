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
      case ContactRequestType.ACCOUNT_LOCK: return "Account lock request";
      case ContactRequestType.ACCOUNT_UNLOCK: return "Unlock account";
      case ContactRequestType.FORGOT_PASSWORD: return "Forgot password";
      case ContactRequestType.EMERGENCY: return "Emergency (hacked / suspicious transaction)";
      case ContactRequestType.BUG_REPORT: return "Report app bug";
      case ContactRequestType.DATA_RECOVERY: return "Data recovery request";
      case ContactRequestType.DATA_LOSS: return "Report data loss";
      case ContactRequestType.GENERAL: return "Feedback / question";
      case ContactRequestType.SUSPICIOUS_TX: return "Suspicious transaction";
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
