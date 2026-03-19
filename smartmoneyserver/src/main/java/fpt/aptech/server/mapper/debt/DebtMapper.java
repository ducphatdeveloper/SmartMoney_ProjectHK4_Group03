package fpt.aptech.server.mapper.debt;

import fpt.aptech.server.dto.debt.DebtResponse;
import fpt.aptech.server.dto.debt.DebtUpdateRequest;
import fpt.aptech.server.entity.Debt;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;

@Mapper(componentModel = "spring")
public interface DebtMapper {

    /**
     * Chuyển đổi từ Debt (Entity) sang DebtResponse (DTO).
     * Bỏ qua trường 'paidAmount' vì nó sẽ được tính toán riêng trong Service.
     */
    @Mapping(target = "paidAmount", ignore = true)
    DebtResponse toResponse(Debt entity);

    /**
     * Cập nhật Debt (Entity) từ DebtUpdateRequest (DTO).
     * Chỉ cập nhật 3 field được phép: personName, dueDate, note.
     * Không cho sửa: totalAmount, debtType (tính từ transaction), remainAmount, finished.
     */
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "account", ignore = true)
    @Mapping(target = "debtType", ignore = true)
    @Mapping(target = "totalAmount", ignore = true)
    @Mapping(target = "remainAmount", ignore = true)
    @Mapping(target = "finished", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    void updateFromRequest(DebtUpdateRequest request, @MappingTarget Debt entity);
}