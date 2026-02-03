package fpt.aptech.server.service.category;

import fpt.aptech.server.dto.category.CategoryResponse;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.mapper.category.CategoryMapper; // Đã sửa import
import fpt.aptech.server.repos.CategoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class CategoryServiceImpl implements CategoryService {

    private final CategoryRepository categoryRepository;
    private final CategoryMapper categoryMapper; // Inject Mapper vào

    @Override
    public List<CategoryResponse> getCategoriesForAccount(Integer accountId) {
        // 1. Lấy danh sách Entity từ Database
        // (Bao gồm danh mục hệ thống + danh mục riêng của user này)
        List<Category> entities = categoryRepository.findSystemAndUserCategoriesByAccount_Id(accountId);

        // 2. Dùng MapStruct chuyển đổi sang DTO.
        return categoryMapper.toDtoList(entities);
    }
}