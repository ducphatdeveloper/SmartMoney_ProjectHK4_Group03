package fpt.aptech.server.service.event;

import fpt.aptech.server.dto.event.EventRequest;
import fpt.aptech.server.dto.event.EventResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Currency;
import fpt.aptech.server.entity.Event;
import fpt.aptech.server.mapper.event.EventMapper;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CurrencyRepository;
import fpt.aptech.server.repos.EventRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class EventServiceImpl implements EventService {

    private final EventRepository eventRepository;
    private final AccountRepository accountRepository;
    private final CurrencyRepository currencyRepository;
    private final EventMapper eventMapper;

    @Override
    @Transactional(readOnly = true)
    public List<EventResponse> getEvents(Integer userId) {
        List<Event> events = eventRepository.findAllByAccountId(userId);
        return eventMapper.toDtoList(events);
    }

    @Override
    @Transactional(readOnly = true)
    public EventResponse getEventById(Integer eventId, Integer userId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy sự kiện"));
        if (!event.getAccount().getId().equals(userId)) {
            throw new SecurityException("Không có quyền xem sự kiện này");
        }
        return eventMapper.toDto(event);
    }

    @Override
    @Transactional
    public EventResponse createEvent(EventRequest request, Integer userId) {
        Account currentUser = accountRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại"));

        Currency currency = currencyRepository.findById(request.currencyCode())
                .orElseThrow(() -> new IllegalArgumentException("Tiền tệ không tồn tại"));

        Event event = eventMapper.toEntity(request);
        event.setAccount(currentUser);
        event.setCurrency(currency);
        event.setFinished(false); // Mặc định khi tạo

        Event savedEvent = eventRepository.save(event);
        return eventMapper.toDto(savedEvent);
    }

    @Override
    @Transactional
    public EventResponse updateEvent(Integer eventId, EventRequest request, Integer userId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy sự kiện"));
        if (!event.getAccount().getId().equals(userId)) {
            throw new SecurityException("Không có quyền sửa sự kiện này");
        }

        eventMapper.updateEntityFromRequest(request, event);

        // Cập nhật Currency
        Currency currency = currencyRepository.findById(request.currencyCode())
                .orElseThrow(() -> new IllegalArgumentException("Tiền tệ không tồn tại"));
        event.setCurrency(currency);

        Event updatedEvent = eventRepository.save(event);
        return eventMapper.toDto(updatedEvent);
    }

    @Override
    @Transactional
    public void deleteEvent(Integer eventId, Integer userId) {
        Event event = eventRepository.findById(eventId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy sự kiện"));
        if (!event.getAccount().getId().equals(userId)) {
            throw new SecurityException("Không có quyền xóa sự kiện này");
        }
        // TODO: Cần check xem Event có đang được Transaction nào sử dụng không trước khi xóa
        eventRepository.delete(event);
    }
}