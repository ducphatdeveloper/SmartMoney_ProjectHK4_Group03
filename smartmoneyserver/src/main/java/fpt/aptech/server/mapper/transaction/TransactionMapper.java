package fpt.aptech.server.mapper.transaction;

import fpt.aptech.server.dto.transaction.request.TransactionRequest;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.Transaction;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Mappings;

import java.util.List;

@Mapper(componentModel = "spring")
public interface TransactionMapper {

    /**
     * Chuyển đổi từ Transaction (Entity) sang TransactionResponse (DTO).
     */
    @Mappings({
        @Mapping(source = "wallet.id", target = "walletId"),
        @Mapping(source = "wallet.walletName", target = "walletName"),
        @Mapping(source = "wallet.goalImageUrl", target = "walletIconUrl"), // Icon Ví

        @Mapping(source = "category.id", target = "categoryId"),
        @Mapping(source = "category.ctgName", target = "categoryName"),
        @Mapping(source = "category.ctgIconUrl", target = "categoryIconUrl"),
        @Mapping(source = "category.ctgType", target = "categoryType"),

        @Mapping(source = "event.id", target = "eventId"),
        @Mapping(source = "event.eventName", target = "eventName"),
        
        @Mapping(source = "debt.id", target = "debtId"), // Map debtId

        @Mapping(source = "savingGoal.id", target = "savingGoalId"),
        @Mapping(source = "savingGoal.goalName", target = "savingGoalName"),
        @Mapping(source = "savingGoal.goalImageUrl", target = "savingGoalIconUrl"), // Icon SavingGoal
        
        @Mapping(source = "aiConversation.id", target = "aiChatId"), // Map aiChatId cho AI transaction
        @Mapping(source = "sourceType", target = "sourceType") // Map sourceType (1=manual|2=chat|3=voice|4=receipt|5=planned)
    })
    TransactionResponse toDto(Transaction transaction);

    /**
     * Chuyển đổi một danh sách Transaction (Entity) sang danh sách TransactionResponse (DTO).
     */
    List<TransactionResponse> toDtoList(List<Transaction> transactions);

    /**
     * Chuyển đổi từ TransactionRequest (DTO) sang Transaction (Entity).
     * MapStruct sẽ tự động map tất cả các trường cùng tên.
     */
    @Mappings({
        // Bỏ qua các trường không có trong Request hoặc do hệ thống quản lý
        @Mapping(target = "id", ignore = true),
        @Mapping(target = "account", ignore = true),
        @Mapping(target = "category", ignore = true),
        @Mapping(target = "wallet", ignore = true),
        @Mapping(target = "event", ignore = true),
        @Mapping(target = "debt", ignore = true),
        @Mapping(target = "savingGoal", ignore = true),
        @Mapping(target = "aiConversation", ignore = true),
        @Mapping(target = "plannedTransaction", ignore = true),
        @Mapping(target = "createdAt", ignore = true),
        @Mapping(target = "sourceType", ignore = true),
        @Mapping(target = "deleted", ignore = true),   // Soft delete — giữ @Builder.Default = false
        @Mapping(target = "deletedAt", ignore = true)   // Soft delete — giữ null mặc định
    })
    Transaction toEntity(TransactionRequest request);
}
