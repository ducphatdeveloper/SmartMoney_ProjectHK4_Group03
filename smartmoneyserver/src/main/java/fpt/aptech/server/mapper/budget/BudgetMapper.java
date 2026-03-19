package fpt.aptech.server.mapper.budget;

import fpt.aptech.server.dto.budget.BudgetRequest;
import fpt.aptech.server.entity.Budget;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;

/**
 * BudgetMapper chỉ handle Entity ↔ Request.
 * BudgetResponse được build thủ công trong BudgetServiceImpl.toBudgetResponse()
 * vì chứa các computed fields (spentAmount, remainingAmount, v.v.).
 */
@Mapper(componentModel = "spring")
public interface BudgetMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "account", ignore = true)
    @Mapping(target = "wallet", ignore = true)
    @Mapping(target = "categories", ignore = true)
    Budget toEntity(BudgetRequest request);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "account", ignore = true)
    @Mapping(target = "wallet", ignore = true)
    @Mapping(target = "categories", ignore = true)
    void updateEntityFromRequest(BudgetRequest request, @MappingTarget Budget entity);
}