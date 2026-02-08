package fpt.aptech.server.service.transaction;

import fpt.aptech.server.dto.transaction.TransactionRequest;
import fpt.aptech.server.dto.transaction.TransactionResponse;
import fpt.aptech.server.entity.*;
import fpt.aptech.server.mapper.transaction.TransactionMapper;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CategoryRepository;
import fpt.aptech.server.repos.EventRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.repos.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
public class TransactionServiceImpl implements TransactionService {

    private final TransactionRepository transactionRepository;
    private final AccountRepository accountRepository;
    private final WalletRepository walletRepository;
    private final CategoryRepository categoryRepository;
    private final EventRepository eventRepository;

    private final TransactionMapper transactionMapper;

    @Override
    @Transactional
    public TransactionResponse createTransaction(TransactionRequest request, Integer accountId) {
        Account currentUser = accountRepository.findById(accountId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại."));

        Transaction transaction = transactionMapper.toEntity(request);
        transaction.setAccount(currentUser);

        Wallet wallet = walletRepository.findById(request.walletId())
                .orElseThrow(() -> new IllegalArgumentException("Ví không tồn tại với ID: " + request.walletId()));
        if (!wallet.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sử dụng ví này.");
        }
        transaction.setWallet(wallet);

        Category category = categoryRepository.findById(request.categoryId())
                .orElseThrow(() -> new IllegalArgumentException("Danh mục không tồn tại với ID: " + request.categoryId()));
        if (category.getAccount() != null && !category.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sử dụng danh mục này.");
        }
        transaction.setCategory(category);

        if (request.eventId() != null) {
            Event event = eventRepository.findById(request.eventId())
                    .orElseThrow(() -> new IllegalArgumentException("Sự kiện không tồn tại với ID: " + request.eventId()));
            if (!event.getAccount().getId().equals(accountId)) {
                throw new SecurityException("Bạn không có quyền sử dụng sự kiện này.");
            }
            transaction.setEvent(event);
        }
        
        Transaction savedTransaction = transactionRepository.save(transaction);
        return transactionMapper.toDto(savedTransaction);
    }

    @Override
    @Transactional(readOnly = true)
    public List<TransactionResponse> getTransactionsByCurrentUser(Integer accountId) {
        List<Transaction> transactions = transactionRepository.findByAccountIdAndDeletedFalseOrderByTransDateDesc(accountId);
        return transactionMapper.toDtoList(transactions);
    }

    @Override
    @Transactional(readOnly = true)
    public TransactionResponse getTransactionById(Integer transactionId, Integer accountId) {
        Transaction transaction = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy giao dịch với ID: " + transactionId));

        if (!transaction.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền xem giao dịch này.");
        }

        if (transaction.getDeleted()) {
            throw new IllegalArgumentException("Giao dịch này đã bị xóa.");
        }

        return transactionMapper.toDto(transaction);
    }

    @Override
    @Transactional
    public TransactionResponse updateTransaction(Integer transactionId, TransactionRequest request, Integer accountId) {
        // 1. Tìm giao dịch gốc và kiểm tra quyền sở hữu
        Transaction transaction = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy giao dịch với ID: " + transactionId));
        if (!transaction.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền sửa giao dịch này.");
        }

        // 2. Cập nhật các trường cơ bản từ request
        transaction.setAmount(request.amount());
        transaction.setNote(request.note());
        transaction.setTransDate(request.transDate());
        transaction.setWithPerson(request.withPerson());
        transaction.setReportable(request.reportable());

        // 3. Cập nhật các object liên quan (nếu có thay đổi)
        // --- Wallet ---
        if (!Objects.equals(transaction.getWallet().getId(), request.walletId())) {
            Wallet newWallet = walletRepository.findById(request.walletId())
                    .orElseThrow(() -> new IllegalArgumentException("Ví mới không tồn tại với ID: " + request.walletId()));
            if (!newWallet.getAccount().getId().equals(accountId)) {
                throw new SecurityException("Bạn không có quyền sử dụng ví mới này.");
            }
            transaction.setWallet(newWallet);
        }

        // --- Category ---
        if (!Objects.equals(transaction.getCategory().getId(), request.categoryId())) {
            Category newCategory = categoryRepository.findById(request.categoryId())
                    .orElseThrow(() -> new IllegalArgumentException("Danh mục mới không tồn tại với ID: " + request.categoryId()));
            if (newCategory.getAccount() != null && !newCategory.getAccount().getId().equals(accountId)) {
                throw new SecurityException("Bạn không có quyền sử dụng danh mục mới này.");
            }
            transaction.setCategory(newCategory);
        }

        // --- Event ---
        if (request.eventId() != null) {
            if (transaction.getEvent() == null || !Objects.equals(transaction.getEvent().getId(), request.eventId())) {
                Event newEvent = eventRepository.findById(request.eventId())
                        .orElseThrow(() -> new IllegalArgumentException("Sự kiện mới không tồn tại với ID: " + request.eventId()));
                if (!newEvent.getAccount().getId().equals(accountId)) {
                    throw new SecurityException("Bạn không có quyền sử dụng sự kiện mới này.");
                }
                transaction.setEvent(newEvent);
            }
        } else {
            transaction.setEvent(null); // Cho phép bỏ sự kiện
        }

        // 4. Lưu lại thay đổi
        Transaction updatedTransaction = transactionRepository.save(transaction);

        // 5. Trả về DTO
        return transactionMapper.toDto(updatedTransaction);
    }

    @Override
    @Transactional
    public void deleteTransaction(Integer transactionId, Integer accountId) {
        // 1. Tìm giao dịch và kiểm tra quyền sở hữu
        Transaction transaction = transactionRepository.findById(transactionId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy giao dịch với ID: " + transactionId));
        if (!transaction.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền xóa giao dịch này.");
        }

        // 2. Thực hiện xóa mềm
        transaction.setDeleted(true);

        // 3. Lưu lại thay đổi
        transactionRepository.save(transaction);
    }
}
