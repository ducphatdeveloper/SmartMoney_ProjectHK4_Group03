package fpt.aptech.server.mapper.event;

import fpt.aptech.server.dto.event.EventRequest;
import fpt.aptech.server.dto.event.EventResponse;
import fpt.aptech.server.entity.Event;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;

import java.util.List;

@Mapper(componentModel = "spring")
public interface EventMapper {

    @Mapping(target = "currencyCode", source = "currency.currencyCode")
    EventResponse toDto(Event entity);

    List<EventResponse> toDtoList(List<Event> entities);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "account", ignore = true)
    @Mapping(target = "currency", ignore = true)
    @Mapping(target = "finished", ignore = true)
    Event toEntity(EventRequest request);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "account", ignore = true)
    @Mapping(target = "currency", ignore = true)
    @Mapping(target = "finished", ignore = true)
    void updateEntityFromRequest(EventRequest request, @MappingTarget Event entity);
}