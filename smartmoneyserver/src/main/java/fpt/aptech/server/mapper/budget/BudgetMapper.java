package fpt.aptech.server.mapper.budget;

import fpt.aptech.server.dto.budget.BudgetRequest;
import fpt.aptech.server.dto.budget.BudgetResponse;
import fpt.aptech.server.entity.Budget;
import fpt.aptech.server.mapper.category.CategoryMapper;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;

import java.util.List;

@Mapper(componentModel = "spring", uses = {CategoryMapper.class})
public interface BudgetMapper {

    @Mapping(target = "walletId", source = "wallet.id")
    @Mapping(target = "walletName", source = "wallet.walletName")
    BudgetResponse toDto(Budget entity);

    List<BudgetResponse> toDtoList(List<Budget> entities);

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