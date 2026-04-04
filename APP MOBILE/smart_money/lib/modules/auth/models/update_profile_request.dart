class UpdateProfileRequest {
  final String? accUsername;
  final String? accPhone;
  final String? accEmail;
  final String? currencyCode;
  final String? fullname;
  final String? gender;
  final String? dateofbirth;
  final String? identityCard;
  final String? address;

  UpdateProfileRequest({
    this.accUsername,
    this.accPhone,
    this.accEmail,
    this.currencyCode,
    this.fullname,
    this.gender,
    this.dateofbirth,
    this.identityCard,
    this.address,
  });

  Map<String, dynamic> toJson() {
    return {
      'accUsername': accUsername,
      'accPhone': accPhone,
      'accEmail': accEmail,
      'currencyCode': currencyCode,
      'fullname': fullname,
      'gender': gender,
      'dateofbirth': dateofbirth,
      'identityCard': identityCard,
      'address': address,
    };
  }
}