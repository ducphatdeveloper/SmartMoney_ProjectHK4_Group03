package fpt.aptech.server.service.event;

import fpt.aptech.server.dto.event.EventRequest;
import fpt.aptech.server.dto.event.EventResponse;

import java.util.List;

public interface EventService {
    List<EventResponse> getEvents(Integer userId);
    EventResponse getEventById(Integer eventId, Integer userId);
    EventResponse createEvent(EventRequest request, Integer userId);
    EventResponse updateEvent(Integer eventId, EventRequest request, Integer userId);
    void deleteEvent(Integer eventId, Integer userId);
}