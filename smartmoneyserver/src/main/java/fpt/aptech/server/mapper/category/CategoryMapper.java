package fpt.aptech.server.mapper.category;

import fpt.aptech.server.dto.category.CategoryRequest;
import fpt.aptech.server.dto.category.CategoryResponse;
import fpt.aptech.server.entity.Category;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface CategoryMapper {

    // Ánh xạ parent.id sang parentId.
    // MapStruct tự động ánh xạ vì có cùng tên và kiểu.
    @Mapping(source = "parent.id", target = "parentId")
    CategoryResponse toDto(Category category);

    // MapStruct sẽ tự động áp dụng toDto cho từng phần tử trong list.
    List<CategoryResponse> toDtoList(List<Category> categories);

    // Khi chuyển từ Request -> Entity, bỏ qua các trường không có trong Request.
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "account", ignore = true)
    @Mapping(target = "children", ignore = true)
    @Mapping(target = "parent", ignore = true)
    @Mapping(target = "deleted", ignore = true)   // Soft delete — giữ @Builder.Default = false
    @Mapping(target = "deletedAt", ignore = true) // Soft delete — giữ null mặc định
    Category toEntity(CategoryRequest request);
}