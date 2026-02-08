package fpt.aptech.server.service.category;

import fpt.aptech.server.dto.category.CategoryRequest;
import fpt.aptech.server.dto.category.CategoryResponse;

import java.util.List;

public interface CategoryService {
    
    // Lấy danh sách danh mục cho 3 tab UI (expense, income, debt)
    List<CategoryResponse> getCategoriesByGroup(Integer accountId, String group);

    // Tìm kiếm toàn cục trên tất cả danh mục
    List<CategoryResponse> searchAllCategories(Integer accountId, String searchTerm);

    // Lấy danh sách danh mục có thể làm cha, lọc theo loại (Thu/Chi)
    List<CategoryResponse> getParentCategories(Integer accountId, Boolean ctgType);

    // Tạo danh mục mới (Create)
    CategoryResponse createCategory(CategoryRequest request, Integer accountId);

    // Cập nhật danh mục (Update)
    CategoryResponse updateCategory(Integer categoryId, CategoryRequest request, Integer accountId);

    // Xóa danh mục (Delete)
    void deleteCategory(Integer categoryId, Integer accountId);
}