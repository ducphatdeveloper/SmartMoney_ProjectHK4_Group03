package fpt.aptech.server.api;

import fpt.aptech.server.dto.AccountDto;
import fpt.aptech.server.dto.PageResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.UserDeviceRepository;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {
    private final AccountRepository accountRepository;
    private final UserDeviceRepository userDeviceRepository;

    @GetMapping("/users")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<PageResponse<AccountDto>> getUsers(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Boolean locked,
            Pageable pageable) {

        Specification<Account> spec = (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();

            // Thêm điều kiện: Chỉ lấy các tài khoản có role_id = 2 (vai trò người dùng thông thường)
            predicates.add(criteriaBuilder.equal(root.get("role").get("id"), 2));

            if (search != null && !search.trim().isEmpty()) {
                String searchKey = "%" + search.toLowerCase() + "%";
                Predicate emailLike = criteriaBuilder.like(criteriaBuilder.lower(root.get("accEmail")), searchKey);
                Predicate phoneLike = criteriaBuilder.like(root.get("accPhone"), "%" + search + "%");
                predicates.add(criteriaBuilder.or(emailLike, phoneLike));
            }

            if (locked != null) {
                predicates.add(criteriaBuilder.equal(root.get("locked"), locked));
            }

            return criteriaBuilder.and(predicates.toArray(new Predicate[0]));
        };

        Page<Account> accountPage = accountRepository.findAll(spec, pageable);
        // Ánh xạ Page<Account> sang Page<AccountDto> để tránh lỗi serialization và chỉ trả về dữ liệu cần thiết
        Page<AccountDto> dtoPage = accountPage.map(AccountDto::new);
        return ResponseEntity.ok(new PageResponse<>(dtoPage));
    }

    @PutMapping("/users/{id}/lock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<String> lockAccount(@PathVariable Integer id) {
        return accountRepository.findById(id)
                .map(account -> {
                    account.setLocked(true);
                    accountRepository.save(account);
                    return ResponseEntity.ok("Account locked successfully.");
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/users/{id}/unlock")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<String> unlockAccount(@PathVariable Integer id) {
        return accountRepository.findById(id)
                .map(account -> {
                    account.setLocked(false);
                    accountRepository.save(account);
                    return ResponseEntity.ok("Account unlocked successfully.");
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/stats")
    @PreAuthorize("hasRole('ROLE_ADMIN') or hasAuthority('ADMIN_SYSTEM_ALL')")
    public ResponseEntity<Map<String, Long>> getStats() {
        Map<String, Long> stats = new HashMap<>();
        stats.put("totalUsers", accountRepository.count());
        stats.put("totalTransactions", 0L);
        stats.put("activeDevices", userDeviceRepository.countByLoggedInTrue());
        return ResponseEntity.ok(stats);
    }
}