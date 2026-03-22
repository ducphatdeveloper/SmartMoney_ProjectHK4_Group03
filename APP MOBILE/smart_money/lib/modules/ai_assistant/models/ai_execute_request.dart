/// Request xác nhận hành động AI đã gợi ý.
/// Tương ứng: AiExecuteRequest.java (server)
class AiExecuteRequest {
  final String actionType;
  final Map<String, dynamic> params;

  const AiExecuteRequest({
    required this.actionType,
    required this.params,
  });

  Map<String, dynamic> toJson() => {
        'actionType': actionType,
        'params': params,
      };
}

