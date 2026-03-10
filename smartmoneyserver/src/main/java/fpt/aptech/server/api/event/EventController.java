package fpt.aptech.server.api.event;

import fpt.aptech.server.dto.event.EventRequest;
import fpt.aptech.server.dto.event.EventResponse;
import fpt.aptech.server.dto.response.ApiResponse;
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
public class EventController {

    private final EventService eventService;

    @GetMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<EventResponse>>> getEvents(
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        List<EventResponse> events = eventService.getEvents(userId);
        return ResponseEntity.ok(ApiResponse.success(events));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<EventResponse>> getEventById(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        EventResponse event = eventService.getEventById(id, userId);
        return ResponseEntity.ok(ApiResponse.success(event));
    }

    @PostMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<EventResponse>> createEvent(
            @Valid @RequestBody EventRequest request,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        EventResponse newEvent = eventService.createEvent(request, userId);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(newEvent, "Tạo sự kiện thành công"));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<EventResponse>> updateEvent(
            @PathVariable Integer id,
            @Valid @RequestBody EventRequest request,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        EventResponse updatedEvent = eventService.updateEvent(id, request, userId);
        return ResponseEntity.ok(ApiResponse.success(updatedEvent, "Cập nhật sự kiện thành công"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> deleteEvent(
            @PathVariable Integer id,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        eventService.deleteEvent(id, userId);
        return ResponseEntity.ok(ApiResponse.success("Xóa sự kiện thành công"));
    }
}