package fpt.aptech.server.service.category;

import fpt.aptech.server.dto.category.CategoryRequest;
import fpt.aptech.server.dto.category.CategoryResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.mapper.category.CategoryMapper;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.CategoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.Collections;
import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
public class CategoryServiceImpl implements CategoryService {

    // Chỉ lưu tên file mặc định
    private static final String DEFAULT_CATEGORY_ICON_FILENAME = "icon_default_category.svg";

    private final CategoryRepository categoryRepository;
    private final AccountRepository accountRepository;
    private final CategoryMapper categoryMapper;

    @Override
    @Transactional(readOnly = true)
    public List<CategoryResponse> getCategoriesByGroup(Integer accountId, String group) {
        List<Category> entities;
        switch (group.toLowerCase()) {
            case "expense":
                List<String> expenseExclusions = List.of("Cho vay", "Trả nợ");
                entities = categoryRepository.findAllExpenseCategories(accountId, expenseExclusions);
                break;
            case "income":
                List<String> incomeExclusions = List.of("Đi vay", "Thu nợ");
                entities = categoryRepository.findAllIncomeCategories(accountId, incomeExclusions);
                break;
            case "debt":
                List<String> debtNames = List.of("Cho vay", "Đi vay", "Thu nợ", "Trả nợ");
                entities = categoryRepository.findDebtAndLoanCategories(debtNames);
                break;
            default:
                throw new IllegalArgumentException("Nhóm danh mục không hợp lệ: " + group);
        }
        return categoryMapper.toDtoList(entities);
    }

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

    @Override
    @Transactional
    public CategoryResponse createCategory(CategoryRequest request, Integer accountId) {
        // 1. Validate trùng lặp
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

        // 2. Map các trường cơ bản từ DTO sang Entity
        Category category = categoryMapper.toEntity(request);

        // 3. Gán icon mặc định nếu user không chọn
        if (!StringUtils.hasText(request.ctgIconUrl())) {
            category.setCtgIconUrl(DEFAULT_CATEGORY_ICON_FILENAME);
        }

        // 4. Gán Account cho Category
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy tài khoản ID: " + accountId));
        category.setAccount(account);

        // 5. Xử lý danh mục cha (nếu có)
        if (request.parentId() != null) {
            Category parent = categoryRepository.findById(request.parentId())
                    .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy danh mục cha với ID: " + request.parentId()));

            if (parent.getAccount() != null && !parent.getAccount().getId().equals(accountId)) {
                throw new IllegalArgumentException("Không có quyền sử dụng danh mục cha này.");
            }
            category.setParent(parent);
        }

        // 6. Lưu xuống DB
        Category savedCategory = categoryRepository.save(category);

        // 7. Map ngược lại sang DTO để trả về
        return categoryMapper.toDto(savedCategory);
    }

    @Override
    @Transactional
    public CategoryResponse updateCategory(Integer categoryId, CategoryRequest request, Integer accountId) {
        // 1. Tìm danh mục cần cập nhật
        Category category = categoryRepository.findById(categoryId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy danh mục với ID: " + categoryId));

        // 2. Kiểm tra quyền sở hữu
        if (category.getAccount() == null || !category.getAccount().getId().equals(accountId)) {
            throw new IllegalArgumentException("Bạn không có quyền sửa danh mục này.");
        }

        // 3. Kiểm tra trùng tên (chỉ khi tên thay đổi)
        if (!Objects.equals(category.getCtgName(), request.ctgName())) {
            // TODO: Logic check trùng tên khi update cũng cần phân biệt Gốc/Con tương tự như Create
            if (categoryRepository.existsByCtgNameAndAccount_IdAndParentIsNull(request.ctgName(), accountId)) {
                throw new IllegalArgumentException("Tên danh mục '" + request.ctgName() + "' đã được sử dụng.");
            }
        }

        // 4. Cập nhật các trường từ request
        category.setCtgName(request.ctgName());
        category.setCtgType(request.ctgType());
        category.setCtgIconUrl(request.ctgIconUrl());

        // 5. Cập nhật danh mục cha (nếu có)
        if (request.parentId() != null) {
            Category parent = categoryRepository.findById(request.parentId())
                    .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy danh mục cha với ID: " + request.parentId()));

            // Kiểm tra quyền: Danh mục cha phải là của hệ thống (account=null) hoặc của chính user này.
            if (parent.getAccount() != null && !parent.getAccount().getId().equals(accountId)) {
                throw new IllegalArgumentException("Không có quyền sử dụng danh mục cha này.");
            }
            category.setParent(parent);
        } else {
            category.setParent(null); // Cho phép bỏ cha
        }

        // 6. Lưu lại (JPA tự hiểu đây là update vì category đã có ID)
        Category updatedCategory = categoryRepository.save(category);

        // 7. Trả về DTO
        return categoryMapper.toDto(updatedCategory);
    }

    @Override
    @Transactional
    public void deleteCategory(Integer categoryId, Integer accountId) {
        // 1. Tìm danh mục cần xóa
        Category category = categoryRepository.findById(categoryId)
                .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy danh mục với ID: " + categoryId));

        // 2. Kiểm tra quyền sở hữu (Không cho xóa danh mục hệ thống)
        if (category.getAccount() == null || !category.getAccount().getId().equals(accountId)) {
            throw new IllegalArgumentException("Bạn không có quyền xóa danh mục này.");
        }

        // 3. Kiểm tra ràng buộc (Ví dụ: có giao dịch nào đang dùng không?)
        // TODO: Cần thêm hàm trong TransactionRepository: boolean existsByCategory_Id(Integer categoryId);
        // if (transactionRepository.existsByCategory_Id(categoryId)) {
        //     throw new DataIntegrityViolationException("Không thể xóa danh mục đã có giao dịch.");
        // }

        // 4. Xóa (Hard Delete)
        categoryRepository.deleteById(categoryId);
    }
}