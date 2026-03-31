// ===========================================================
// [1] EventService — Gọi API Event từ Spring Boot
// ===========================================================
// Endpoints (backend):
//   • GET    /api/events?isFinished=false|true
//   • GET    /api/events/{id}
//   • POST   /api/events
//   • PUT    /api/events/{id}
//   • PUT    /api/events/{id}/status
//   • DELETE /api/events/{id}
// ===========================================================

import 'package:smart_money/core/helpers/api_handler.dart';
import 'package:smart_money/core/models/api_response.dart';
import 'package:smart_money/core/constants/app_constants.dart';
import '../models/event_response.dart';
import '../models/event_create_request.dart';
import '../models/event_update_request.dart';

class EventService {

  // Base URL: /api/events
  static String get _base => AppConstants.eventsBase;

  // =============================================
  // [1.1] GET EVENTS — theo trạng thái
  // =============================================
  // isFinished = false → Active
  // isFinished = true  → Finished
  static Future<ApiResponse<List<EventResponse>>> getEvents(bool isFinished) async {
    final url = '$_base?isFinished=$isFinished';

    return ApiHandler.get<List<EventResponse>>(
      url,
      fromJson: (json) => _parseList(json),
    );
  }

  // =============================================
  // [1.2] GET BY ID
  // =============================================
  static Future<ApiResponse<EventResponse>> getById(int id) async {
    final url = '$_base/$id';

    return ApiHandler.get<EventResponse>(
      url,
      fromJson: (json) => EventResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // =============================================
  // [1.3] CREATE EVENT
  // =============================================
  // Body:
  // {
  //   eventName,
  //   eventIconUrl,
  //   endDate,
  //   currencyCode
  // }
  static Future<ApiResponse<EventResponse>> create(EventCreateRequest request) async {
    return ApiHandler.post<EventResponse>(
      _base,
      body: request.toJson(),
      fromJson: (json) => EventResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // =============================================
  // [1.4] UPDATE EVENT
  // =============================================
  static Future<ApiResponse<EventResponse>> update(
      int id,
      EventUpdateRequest request,
      ) async {

    final url = '$_base/$id';

    return ApiHandler.put<EventResponse>(
      url,
      body: request.toJson(),
      fromJson: (json) => EventResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // =============================================
  // [1.5] DELETE EVENT
  // =============================================
  static Future<ApiResponse<void>> delete(int id) async {
    final url = '$_base/$id';

    return ApiHandler.delete<void>(url);
  }

  // =============================================
  // [1.6] TOGGLE STATUS (Active ↔ Finished)
  // =============================================
  static Future<ApiResponse<EventResponse>> toggleStatus(int id) async {
    final url = '$_base/$id/status';

    return ApiHandler.put<EventResponse>(
      url,
      fromJson: (json) => EventResponse.fromJson(json as Map<String, dynamic>),
    );
  }

  // =============================================
  // [1.7] HELPER — parse List<EventResponse>
  // =============================================
  static List<EventResponse> _parseList(dynamic json) {
    if (json is List) {
      return json
          .map((e) => EventResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}