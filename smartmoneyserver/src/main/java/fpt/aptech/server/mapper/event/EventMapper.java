package fpt.aptech.server.mapper.event;

import fpt.aptech.server.dto.event.EventCreateRequest;
import fpt.aptech.server.dto.event.EventResponse;
import fpt.aptech.server.dto.event.EventUpdateRequest;
import fpt.aptech.server.entity.Event;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;

import java.util.List;

@Mapper(componentModel = "spring")
public interface EventMapper {

    // Chuyển từ Entity sang DTO Response
    @Mapping(source = "currency.currencyCode", target = "currencyCode")
    @Mapping(target = "totalIncome", ignore = true)
    @Mapping(target = "totalExpense", ignore = true)
    @Mapping(target = "netAmount", ignore = true)
    EventResponse toResponse(Event entity);

    List<EventResponse> toResponseList(List<Event> entities);

    // Chuyển từ DTO CreateRequest sang Entity (dùng khi tạo mới)
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "account", ignore = true)
    @Mapping(target = "currency", ignore = true)
    @Mapping(target = "finished", ignore = true)
    @Mapping(target = "beginDate", ignore = true) // Sẽ được set tự động
    Event fromCreateRequest(EventCreateRequest request);

    // Cập nhật Entity từ DTO UpdateRequest (dùng khi sửa)
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "account", ignore = true)
    @Mapping(target = "currency", ignore = true)
    @Mapping(target = "finished", ignore = true)
    @Mapping(target = "beginDate", ignore = true)
    void updateFromUpdateRequest(EventUpdateRequest request, @MappingTarget Event entity);
}
