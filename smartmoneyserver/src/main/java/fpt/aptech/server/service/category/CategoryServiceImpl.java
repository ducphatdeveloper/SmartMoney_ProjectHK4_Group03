package fpt.aptech.server.service.category;

import fpt.aptech.server.dto.category.CategoryResponse;
import fpt.aptech.server.entity.Category;
import fpt.aptech.server.repos.CategoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CategoryServiceImpl implements CategoryService {

    //@Autowired
    private final CategoryRepository categoryRepository;

    @Override
    public List<CategoryResponse> getCategoriesForAccount(Integer accountId) {
        return List.of();
    }

//    @Override
//    public List<CategoryResponse> getCategoriesForAccount(Integer accountId) {
//        // 1. Gọi Repo lấy dữ liệu
//        List<Category> entities = categoryRepository.findSystemAndUserCategoriesByAccount_Id(accountId);
//
//        // 2. Convert sang DTO dùng hàm mapToDto bên dưới
//        return entities.stream()
//                .map(this::mapToDto)
//                .collect(Collectors.toList());
//    }
//
//    // --- Hàm helper chuyển đổi Entity sang DTO ---
//    private CategoryResponse mapToDto(Category entity) {
//        // Sử dụng Constructor rỗng (NoArgsConstructor)
//        CategoryResponse dto = new CategoryResponse();
//
//        // Map từng trường dữ liệu
//        dto.setId(entity.getId());
//        dto.setCtgName(entity.getCtgName());
//        dto.setCtgType(entity.getCtgType());
//        dto.setCtgIconUrl(entity.getCtgIconUrl());
//
//        // Xử lý Parent ID: Chỉ set nếu parent không null để tránh lỗi NullPointerException
//        if (entity.getParent() != null) {
//            dto.setParentId(entity.getParent().getId());
//        } else {
//            dto.setParentId(null); // Rõ ràng hơn, dù mặc định đã là null
//        }
//
//        return dto;
//    }


}