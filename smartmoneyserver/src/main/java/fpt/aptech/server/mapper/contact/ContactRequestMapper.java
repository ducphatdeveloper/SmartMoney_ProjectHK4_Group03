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
     * fullname, contactPhone, contactEmail: tên field giống nhau → MapStruct tự map.
     */
    @Mapping(source = "account.id",       target = "accId")
    @Mapping(source = "account.accEmail", target = "accEmail")
    @Mapping(source = "account.accPhone", target = "accPhone")
    @Mapping(source = "account.fullname", target = "accFullname")
    @Mapping(source = "resolvedBy.id",       target = "resolvedById")
    @Mapping(source = "resolvedBy.fullname", target = "resolvedByName")
    ContactRequestResponse toResponse(ContactRequest entity);

    /**
     * Danh sách Entity → danh sách Response DTO.
     */
    List<ContactRequestResponse> toResponseList(List<ContactRequest> entities);

    /**
     * CreateRequest DTO → Entity.
     * Bỏ qua các field do Service tự set: id, account, resolvedBy, status, priority, timestamps.
     * fullname, contactPhone, contactEmail: map trực tiếp theo tên (cùng tên trong DTO và Entity).
     */
    @Mapping(target = "id",              ignore = true)
    @Mapping(target = "account",         ignore = true)
    @Mapping(target = "resolvedBy",      ignore = true)
    @Mapping(target = "requestStatus",   ignore = true)
    @Mapping(target = "requestPriority", ignore = true)
    @Mapping(target = "processedAt",     ignore = true)
    @Mapping(target = "resolvedAt",      ignore = true)
    @Mapping(target = "adminNote",       ignore = true)
    @Mapping(target = "createdAt",       ignore = true)
    @Mapping(target = "updatedAt",       ignore = true)
    // fullname: ignore → Service tự set (auto-fill từ account hoặc dùng giá trị user nhập)
    @Mapping(target = "fullname",        ignore = true)
    ContactRequest toEntity(ContactRequestCreateRequest request);
}
