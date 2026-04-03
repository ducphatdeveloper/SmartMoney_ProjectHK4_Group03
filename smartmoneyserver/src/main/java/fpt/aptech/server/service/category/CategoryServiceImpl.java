package fpt.aptech.server.service.category;

import fpt.aptech.server.dto.category.CategoryRequest;
import fpt.aptech.server.dto.category.CategoryResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.mapper.category.CategoryMapper;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CategoryRepository;
import fpt.aptech.server.repos.TransactionRepository;
import fpt.aptech.server.service.transaction.TransactionService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
public class CategoryServiceImpl implements CategoryService {

    private static final String DEFAULT_CATEGORY_ICON_FILENAME = "icon_default_category.png";

    private final CategoryRepository categoryRepository;
    private final AccountRepository accountRepository;
    private final CategoryMapper categoryMapper;

    // ... inject thêm TransactionService
    private final TransactionService transactionService; // Hoặc TransactionServiceImpl -- phuc vu cho xoa va gop category
    private final TransactionRepository transactionRepository; // phuc vu cho xoa va gop category

    /**
     * [HELPER] Lấy danh mục do user sở hữu (không phải hệ thống) với quyền kiểm soát toàn bộ (edit/delete).
     * <p>
     * Logic:
     * - Nếu danh mục không tồn tại → throw IllegalArgumentException
     * - Nếu danh mục là hệ thống (account=null) → throw IllegalStateException
     * - Nếu danh mục không phải của user này → throw SecurityException
     * - Nếu tất cả check pass → return Category (an toàn để edit/delete)
     *
     * @param categoryId ID danh mục cần validate
     * @param accountId  ID tài khoản user
     * @return Category entity (đã được validate quyền sở hữu)
     */
    private Category getOwnedCategory(Integer categoryId, Integer accountId) {
        // 1. Dùng Query để lấy Category lên (chỉ cần ID là đủ)
        Category category = categoryRepository.findById(categoryId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy danh mục với ID: " + categoryId));

        // 2. Chặn danh mục hệ thống (Thứ tự này quan trọng để báo lỗi đúng loại)
        if (category.getAccount() == null) {
            throw new IllegalStateException("Không thể xóa/sửa danh mục mặc định của hệ thống.");
        }

        // 3. Kiểm tra quyền sở hữu (Security)
        if (!category.getAccount().getId().equals(accountId)) {
            throw new SecurityException("Bạn không có quyền thao tác danh mục này!");
        }

        return category;
    }

    /**
     * [HELPER] Lấy danh sách danh mục nhận gộp theo loại (Thu/Chi) + filter theo accountId.
     * <p>
     * Dùng khi user chọn MERGE: hiển thị danh sách danh mục cùng loại để user chọn danh mục nhận.
     *
     * @param accountId ID tài khoản user
     * @param ctgType   true (Thu), false (Chi)
     * @return Danh sách danh mục cùng loại có thể nhận gộp
     */
    @Override
    @Transactional(readOnly = true)
    public List<CategoryResponse> getCategoriesForMerge(Integer accountId, Boolean ctgType) {
        List<Category> entities;
        if (ctgType) { // Nếu là Khoản Thu
            List<String> incomeExclusions = List.of("Đi vay", "Thu nợ");
            entities = categoryRepository.findAllIncomeCategories(accountId, incomeExclusions);
        } else { // Nếu là Khoản Chi
            List<String> expenseExclusions = List.of("Cho vay", "Trả nợ");
            entities = categoryRepository.findAllExpenseCategories(accountId, expenseExclusions);
        }
        return categoryMapper.toDtoList(entities);
    }

    /**
     * Xóa danh mục - HYBRID (Hỗ trợ MERGE và DELETE_ALL).
     * 
     * LOGIC:
     * 1. Kiểm tra quyền sở hữu danh mục.
     * 2. Xử lý Giao dịch (Transactions): Hoàn tiền ví -> (Gộp hoặc Xóa giao dịch).
     * 3. Xóa Danh mục: Sử dụng deleteAllInBatch để xóa các danh mục con trước, 
     *    nhằm đảm bảo tính toàn vẹn dữ liệu (FK constraint) trước khi xóa danh mục cha.
     * 
     * ⚠️ LƯU Ý: Không thay đổi object trong childCategories trước khi gọi deleteAllInBatch,
     *    vì nó chạy bằng query thuần (không dọn dẹp Hibernate Session).
     */
    @Override
    @Transactional
    public void deleteCategoryWithOptions(Integer categoryId, Integer accountId, String actionType, Integer newCategoryId) {
        Category category = getOwnedCategory(categoryId, accountId);
        List<Category> childCategories = categoryRepository.findByParent_IdAndAccount_Id(categoryId, accountId);
        String action = (actionType != null) ? actionType.toUpperCase() : "DELETE_ALL";

        if ("MERGE".equals(action)) {
            if (newCategoryId == null) throw new IllegalArgumentException("Thiếu tham số: newCategoryId");
            Category targetCategory = getOwnedCategory(newCategoryId, accountId);

            if (!category.getCtgType().equals(targetCategory.getCtgType())) {
                throw new IllegalArgumentException("Không thể gộp khác loại (Thu/Chi).");
            }
            if (categoryId.equals(newCategoryId)) {
                throw new IllegalArgumentException("Không thể gộp vào chính nó.");
            }

            // --- PHẢI LÀM THEO THỨ TỰ NÀY ---

            // A. Hoàn tiền cho CHA và TOÀN BỘ CON (Khi chúng vẫn còn gắn với Category cũ)
            transactionService.revertAllTransactionBalancesForCategoryNoFetch(categoryId, accountId);
            for (Category child : childCategories) {
                transactionService.revertAllTransactionBalancesForCategoryNoFetch(child.getId(), accountId);
            }

            // B. Sau khi hoàn tiền xong, mới đổi Category ID sang mục mới
            transactionRepository.updateCategoryForUserTransactions(categoryId, newCategoryId, accountId);
            for (Category child : childCategories) {
                transactionRepository.updateCategoryForUserTransactions(child.getId(), newCategoryId, accountId);
            }

        } else {
            // LOGIC XÓA MỀM (DELETE_ALL) — thay vì xóa cứng, dùng soft delete
            for (Category child : childCategories) {
                transactionService.revertAllTransactionBalancesForCategoryNoFetch(child.getId(), accountId);
                transactionRepository.softDeleteAllByCategoryIdAndAccountId(child.getId(), accountId);
            }
            transactionService.revertAllTransactionBalancesForCategoryNoFetch(categoryId, accountId);
            transactionRepository.softDeleteAllByCategoryIdAndAccountId(categoryId, accountId);
        }

        // --- XÓA MỀM DỮ LIỆU: CON TRƯỚC, CHA SAU ---

        // 4. Soft delete danh mục con
        java.time.LocalDateTime now = java.time.LocalDateTime.now();
        for (Category child : childCategories) {
            child.setDeleted(true);
            child.setDeletedAt(now);
        }
        if (!childCategories.isEmpty()) {
            categoryRepository.saveAll(childCategories);
            categoryRepository.flush();
        }

        // 5. Cuối cùng soft delete danh mục cha
        category.setDeleted(true);
        category.setDeletedAt(now);
        categoryRepository.save(category);
    }

    /**
     * Lấy danh sách danh mục theo nhóm (Expense, Income, Debt).
     * - Loại trừ các danh mục đặc biệt không cần hiển thị.
     */
    @Override
    @Transactional(readOnly = true)
    public List<CategoryResponse> getCategoriesByGroup(Integer accountId, String group) {
        List<Category> entities;
        switch (group.toLowerCase()) {

            // ── Tab KHOẢN CHI (Tạo giao dịch) ────────────────────────────────────────
            // Hiển thị tất cả danh mục CHI của hệ thống + user
            // Loại trừ "Cho vay", "Trả nợ" vì 2 mục này thuộc tab riêng (CHO VAY)
            case "expense":
                List<String> expenseExclusions = List.of("Cho vay", "Trả nợ");
                entities = categoryRepository.findAllExpenseCategories(accountId, expenseExclusions);
                break;

            // ── Tab KHOẢN THU (Tạo giao dịch) ────────────────────────────────────────
            // Hiển thị tất cả danh mục THU của hệ thống + user
            // Loại trừ "Đi vay", "Thu nợ" vì 2 mục này thuộc tab riêng (VAY/NỢ)
            case "income":
                List<String> incomeExclusions = List.of("Đi vay", "Thu nợ");
                entities = categoryRepository.findAllIncomeCategories(accountId, incomeExclusions);
                break;

            // ── Tab VAY/NỢ (Tạo giao dịch) ───────────────────────────────────────────
            // Hiển thị đủ 4 danh mục nợ/vay của hệ thống:
            //   CHI: Cho vay (19), Trả nợ (22)
            //   THU: Đi vay  (20), Thu nợ (21)
            case "debt":
                List<String> debtNames = List.of("Cho vay", "Đi vay", "Thu nợ", "Trả nợ");
                entities = categoryRepository.findDebtAndLoanCategories(debtNames);
                break;

            // ── Tab CHO VAY (Chọn nhóm khi tạo Ngân sách) ────────────────────────────
            // Chỉ hiển thị 2 danh mục CHI thuộc nhóm vay/nợ:
            //   Cho vay (19) — tiền tôi cho người khác vay
            //   Trả nợ  (22) — tiền tôi trả lại người đã cho tôi vay
            // Không hiển thị "Đi vay", "Thu nợ" vì đó là THU, ngân sách chỉ quản lý CHI
            case "lending":
                // Tab "CHO VAY" trong Budget picker — chỉ Cho vay + Trả nợ
                List<String> lendingNames = List.of("Cho vay", "Trả nợ");
                entities = categoryRepository.findDebtAndLoanCategories(lendingNames);
                break;
            default:
                throw new IllegalArgumentException("Nhóm danh mục không hợp lệ: " + group);
        }
        return categoryMapper.toDtoList(entities);
    }

    /**
     * Tìm kiếm danh mục theo tên.
     * - Nếu không có từ khóa -> Trả về tất cả danh mục (Hệ thống + User).
     * - Nếu có từ khóa -> Tìm kiếm tương đối (LIKE).
     */
    @Override
    @Transactional(readOnly = true)
    public List<CategoryResponse> searchAllCategories(Integer accountId, String searchTerm) {
        List<Category> entities;
        if (StringUtils.hasText(searchTerm)) {
            // Nếu có từ khóa, thực hiện tìm kiếm
            String finalSearchTerm = "%" + searchTerm.trim() + "%";
            entities = categoryRepository.searchAllUserAndSystemCategories(accountId, finalSearchTerm);
        } else {
            // Nếu không có từ khóa, lấy tất cả
            entities = categoryRepository.findAllSystemAndUserCategories(accountId);
        }
        return categoryMapper.toDtoList(entities);
    }

    /**
     * Lấy danh sách danh mục cha để chọn khi tạo danh mục con.
     * - Lọc theo loại (Thu/Chi).
     * - Loại trừ các danh mục không được phép làm cha.
     */
    @Override
    @Transactional(readOnly = true)
    public List<CategoryResponse> getParentCategories(Integer accountId, Boolean ctgType) {
        List<Category> entities;
        if (ctgType) { // Nếu là Khoản Thu
            entities = categoryRepository.findIncomeParents(accountId, "Lương");
        } else { // Nếu là Khoản Chi
            List<String> excludedNames = List.of(
                    "Các chi phí khác", "Tiền chuyển đi", "Trả lãi",
                    "Cho vay", "Đi vay", "Thu nợ", "Trả nợ"
            );
            entities = categoryRepository.findExpenseParents(accountId, excludedNames);
        }
        return categoryMapper.toDtoList(entities);
    }

    /**
     * Tạo danh mục mới.
     * - Validate trùng tên (Gốc/Con).
     * - Validate quyền sử dụng danh mục cha.
     * - Gán icon mặc định nếu thiếu.
     */
    @Override
    @Transactional
    public CategoryResponse createCategory(CategoryRequest request, Integer accountId) {
        // 1. Validate dữ liệu đầu vào (Trùng tên)
        if (request.parentId() != null) {
            // Nếu tạo danh mục CON: check trùng tên trong cùng cha
            if (categoryRepository.existsByCtgNameAndParent_IdAndAccount_Id(request.ctgName(), request.parentId(), accountId)) {
                Category parent = categoryRepository.findById(request.parentId()).orElse(null);
                String parentName = (parent != null) ? parent.getCtgName() : "";
                throw new IllegalArgumentException("Danh mục '" + request.ctgName() + "' đã tồn tại trong mục '" + parentName + "'.");
            }
        } else {
            // Nếu tạo danh mục GỐC:
            // a. Check trùng tên với danh mục gốc của chính user
            if (categoryRepository.existsByCtgNameAndAccount_IdAndParentIsNull(request.ctgName(), accountId)) {
                throw new IllegalArgumentException("Danh mục gốc '" + request.ctgName() + "' đã tồn tại.");
            }
            // b. Check trùng tên với danh mục gốc của HỆ THỐNG
            if (categoryRepository.existsByCtgNameAndAccountIsNullAndParentIsNull(request.ctgName())) {
                throw new IllegalArgumentException("Không thể tạo danh mục gốc trùng tên với danh mục của hệ thống.");
            }
        }

        // 2. Map DTO sang Entity
        Category category = categoryMapper.toEntity(request);

        // 3. Gán icon mặc định nếu user không chọn
        if (!StringUtils.hasText(request.ctgIconUrl())) {
            category.setCtgIconUrl(DEFAULT_CATEGORY_ICON_FILENAME);
        }

        // 4. Gán Account cho Category
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy tài khoản ID: " + accountId));
        category.setAccount(account);

        // 5. Xử lý danh mục cha (nếu có)
        if (request.parentId() != null) {
            Category parent = categoryRepository.findById(request.parentId())
                    .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy danh mục cha với ID: " + request.parentId()));

            // Validate quyền sở hữu cha
            if (parent.getAccount() != null && !parent.getAccount().getId().equals(accountId)) {
                throw new SecurityException("Không có quyền sử dụng danh mục cha này.");
            }
            category.setParent(parent);
        }

        // 6. Lưu xuống DB
        Category savedCategory = categoryRepository.save(category);

        // 7. Map ngược lại sang DTO để trả về
        return categoryMapper.toDto(savedCategory);
    }

    /**
     * Cập nhật danh mục.
     * - Validate quyền sở hữu.
     * - Validate trùng tên (nếu đổi tên).
     * - Cập nhật thông tin và quan hệ cha-con.
     */
    @Override
    @Transactional
    public CategoryResponse updateCategory(Integer categoryId, CategoryRequest request, Integer accountId) {
        // 1. Tìm danh mục cần cập nhật và validate quyền
        Category category = getOwnedCategory(categoryId, accountId);

        // 2. Validate trùng tên (chỉ khi tên thay đổi) - Phân biệt Gốc/Con
        if (!Objects.equals(category.getCtgName(), request.ctgName())) {
            // Xác định cha "hiệu lực" (effective parent)
            // - Nếu request có truyền parentId → dùng cái mới
            // - Nếu request không truyền parentId → giữ nguyên cha cũ (hoặc null nếu là gốc)
            Integer effectiveParentId = request.parentId() != null
                    ? request.parentId()
                    : (category.getParent() != null ? category.getParent().getId() : null);

            if (effectiveParentId != null) {
                // Là danh mục CON: check trùng tên trong cùng cha
                if (categoryRepository.existsByCtgNameAndParent_IdAndAccount_Id(request.ctgName(), effectiveParentId, accountId)) {
                    Category parent = categoryRepository.findById(effectiveParentId).orElse(null);
                    String parentName = (parent != null) ? parent.getCtgName() : "";
                    throw new IllegalArgumentException("Danh mục '" + request.ctgName() + "' đã tồn tại trong mục '" + parentName + "'.");
                }
            } else {
                // Là danh mục GỐC: check trùng tên với danh mục gốc của user
                if (categoryRepository.existsByCtgNameAndAccount_IdAndParentIsNull(request.ctgName(), accountId)) {
                    throw new IllegalArgumentException("Danh mục gốc '" + request.ctgName() + "' đã tồn tại.");
                }
                // Check trùng tên với danh mục gốc của HỆ THỐNG
                if (categoryRepository.existsByCtgNameAndAccountIsNullAndParentIsNull(request.ctgName())) {
                    throw new IllegalArgumentException("Không thể tạo danh mục gốc trùng tên với danh mục của hệ thống.");
                }
            }
        }

        // 3. Cập nhật các trường từ request
        category.setCtgName(request.ctgName());
        category.setCtgType(request.ctgType());
        category.setCtgIconUrl(request.ctgIconUrl());

        // 4. Cập nhật danh mục cha (nếu request gửi parentId)
        // Nếu request không gửi parentId, sẽ giữ nguyên cha cũ (không thay đổi quan hệ)
        if (request.parentId() != null) {
            Category parent = categoryRepository.findById(request.parentId())
                    .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy danh mục cha với ID: " + request.parentId()));

            // Kiểm tra quyền: Danh mục cha phải là của hệ thống (account=null) hoặc của chính user này.
            if (parent.getAccount() != null && !parent.getAccount().getId().equals(accountId)) {
                throw new SecurityException("Không có quyền sử dụng danh mục cha này.");
            }
            category.setParent(parent);
        }
        // Nếu request.parentId() == null → không cập nhật quan hệ cha, giữ nguyên cái cũ

        // 5. Lưu lại (JPA tự hiểu đây là update vì category đã có ID)
        Category updatedCategory = categoryRepository.save(category);

        // 6. Trả về DTO
        return categoryMapper.toDto(updatedCategory);
    }
}
