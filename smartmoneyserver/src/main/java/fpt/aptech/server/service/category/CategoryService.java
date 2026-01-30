package fpt.aptech.server.service.category;

import fpt.aptech.server.dto.category.CategoryResponse;

import java.util.List;

public interface CategoryService {
    // Lấy danh sách danh mục theo Account ID
    List<CategoryResponse> getCategoriesForAccount(Integer accountId);
}
