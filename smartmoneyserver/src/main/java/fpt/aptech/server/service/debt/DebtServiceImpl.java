package fpt.aptech.server.service.debt;

import fpt.aptech.server.dto.debt.DebtResponse;
import fpt.aptech.server.dto.debt.DebtUpdateRequest;
import fpt.aptech.server.dto.transaction.view.TransactionResponse;
import fpt.aptech.server.entity.Debt;
import fpt.aptech.server.entity.Transaction;
import fpt.aptech.server.mapper.debt.DebtMapper;
import fpt.aptech.server.mapper.transaction.TransactionMapper;
import fpt.aptech.server.repos.DebtRepository;
import fpt.aptech.server.repos.PlannedTransactionRepository;
import fpt.aptech.server.repos.TransactionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DebtServiceImpl implements DebtService {

    private final DebtRepository debtRepository;
    private final TransactionRepository transactionRepository;
    private final PlannedTransactionRepository plannedTransactionRepository;
    private final TransactionMapper transactionMapper;
    private final DebtMapper debtMapper;

    @Override
    @Transactional(readOnly = true)
    public List<DebtResponse> getDebts(Integer accId, Boolean debtType) {
        return debtRepository
                .findAllByAccount_IdAndDebtTypeOrderByCreatedAtDesc(accId, debtType)
                .stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public DebtResponse getDebt(Integer debtId, Integer accId) {
        return mapToResponse(getOwnedDebt(debtId, accId));
    }

    @Override
    @Transactional(readOnly = true)
    public List<TransactionResponse> getDebtTransactions(Integer debtId, Integer accId) {
        getOwnedDebt(debtId, accId); // check ownership
        List<Transaction> transactions = transactionRepository.findAllByDebtId(debtId);
        return transactionMapper.toDtoList(transactions);
    }

    @Override
    @Transactional
    public DebtResponse updateDebt(Integer debtId, DebtUpdateRequest request, Integer accId) {
        Debt debt = getOwnedDebt(debtId, accId);

        // Chỉ cho sửa 3 field — totalAmount và debtType KHÔNG được sửa
        debt.setPersonName(request.personName());
        debt.setDueDate(request.dueDate());
        debt.setNote(request.note());

        return mapToResponse(debtRepository.save(debt));
    }

    @Override
    @Transactional
    public DebtResponse updateDebtStatus(Integer debtId, Integer accId) {
        Debt debt = getOwnedDebt(debtId, accId);
        debt.setFinished(!debt.getFinished());
        return mapToResponse(debtRepository.save(debt));
    }

    @Override
    @Transactional
    public void deleteDebt(Integer debtId, Integer accId) {
        Debt debt = getOwnedDebt(debtId, accId);
        // Giữ lại giao dịch, chỉ set debt_id = null
        transactionRepository.setDebtIdToNullByDebtId(debtId);
        plannedTransactionRepository.deactivateAllByDebtId(debtId);        // ← thêm
        plannedTransactionRepository.setDebtIdToNullByDebtId(debtId);      // ← thêm

        // Soft delete khoản nợ (thay vì xóa cứng)
        debt.setDeleted(true);
        debt.setDeletedAt(java.time.LocalDateTime.now());
        debtRepository.save(debt);
    }

    // ================= PRIVATE HELPERS =================

    private Debt getOwnedDebt(Integer debtId, Integer accId) {
        return debtRepository.findByIdAndAccount_Id(debtId, accId)
                .orElseThrow(() -> new SecurityException(
                        "Khoản nợ không tồn tại hoặc bạn không có quyền truy cập."));
    }

    private DebtResponse mapToResponse(Debt debt) {
        BigDecimal paidAmount = debt.getTotalAmount().subtract(debt.getRemainAmount());
        return debtMapper.toResponse(debt).toBuilder()
                .paidAmount(paidAmount)
                .build();
    }
}