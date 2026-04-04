package fpt.aptech.server.mapper.contact;

import fpt.aptech.server.dto.contact.ContactRequestCreateRequest;
import fpt.aptech.server.dto.contact.ContactRequestResponse;
import fpt.aptech.server.entity.ContactRequest;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

/**
 * MapStruct mapper cho ContactRequest Entity ↔ DTO.
 */
@Mapper(componentModel = "spring")
public interface ContactRequestMapper {

    /**
     * Entity → Response DTO.
     * Map thông tin người gửi (account), người xử lý (processedBy), người duyệt (resolvedBy).
     */
    @Mapping(source = "account.id", target = "accId")
    @Mapping(source = "account.accEmail", target = "accEmail")
    @Mapping(source = "account.accPhone", target = "accPhone")
    @Mapping(source = "account.fullname", target = "accFullname")
    @Mapping(source = "processedBy.id", target = "processedById")
    @Mapping(source = "processedBy.fullname", target = "processedByName")
    @Mapping(source = "resolvedBy.id", target = "resolvedById")
    @Mapping(source = "resolvedBy.fullname", target = "resolvedByName")
    ContactRequestResponse toResponse(ContactRequest entity);

    /**
     * Danh sách Entity → danh sách Response DTO.
     */
    List<ContactRequestResponse> toResponseList(List<ContactRequest> entities);

    /**
     * CreateRequest DTO → Entity.
     * Bỏ qua các field do Service tự set: id, account, processedBy, resolvedBy, status, priority, timestamps.
     */
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "account", ignore = true)
    @Mapping(target = "processedBy", ignore = true)
    @Mapping(target = "resolvedBy", ignore = true)
    @Mapping(target = "requestStatus", ignore = true)
    @Mapping(target = "requestPriority", ignore = true)
    @Mapping(target = "processedAt", ignore = true)
    @Mapping(target = "resolvedAt", ignore = true)
    @Mapping(target = "adminNote", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    ContactRequest toEntity(ContactRequestCreateRequest request);
}

