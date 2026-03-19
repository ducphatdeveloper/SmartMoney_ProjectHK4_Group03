package fpt.aptech.server.api.event;

import fpt.aptech.server.dto.event.EventCreateRequest;
import fpt.aptech.server.dto.event.EventResponse;
import fpt.aptech.server.dto.event.EventUpdateRequest;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.dto.transaction.view.DailyTransactionGroup;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.event.EventService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/events")
@RequiredArgsConstructor
@PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
public class EventController {

    private final EventService eventService;

    @PostMapping
    public ResponseEntity<ApiResponse<EventResponse>> createEvent(
            @Valid @RequestBody EventCreateRequest request,
            @AuthenticationPrincipal Account currentUser) {
        EventResponse newEvent = eventService.createEvent(request, currentUser.getId());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(newEvent, "Tạo sự kiện thành công."));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<EventResponse>>> getEvents(
            @RequestParam(defaultValue = "false") Boolean isFinished,
            @AuthenticationPrincipal Account currentUser) {
        List<EventResponse> events = eventService.getEvents(currentUser.getId(), isFinished);
        return ResponseEntity.ok(ApiResponse.success(events));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<EventResponse>> getEvent(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        EventResponse event = eventService.getEvent(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(event));
    }

    @GetMapping("/{id}/transactions")
    public ResponseEntity<ApiResponse<List<TransactionResponse>>> getEventTransactions(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        List<TransactionResponse> transactions = eventService.getEventTransactions(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(transactions));
    }

    @GetMapping("/{id}/transactions/grouped")
    public ResponseEntity<ApiResponse<List<DailyTransactionGroup>>> getEventTransactionsGrouped(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        List<DailyTransactionGroup> groups = eventService.getEventTransactionsGrouped(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(groups));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<EventResponse>> updateEvent(
            @PathVariable Integer id,
            @Valid @RequestBody EventUpdateRequest request,
            @AuthenticationPrincipal Account currentUser) {
        EventResponse updatedEvent = eventService.updateEvent(id, request, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(updatedEvent, "Cập nhật sự kiện thành công."));
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<ApiResponse<EventResponse>> updateEventStatus(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        EventResponse updatedEvent = eventService.updateEventStatus(id, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.success(updatedEvent));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteEvent(
            @PathVariable Integer id,
            @RequestParam(defaultValue = "false") Boolean deleteTransactions,
            @AuthenticationPrincipal Account currentUser) {
        eventService.deleteEvent(id, currentUser.getId(), deleteTransactions);
        return ResponseEntity.noContent().build();
    }
}
