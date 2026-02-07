package fpt.aptech.server.mapper.category;

import fpt.aptech.server.dto.category.CategoryResponse;
import fpt.aptech.server.entity.Category;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface CategoryMapper {

    // Map trường 'parent.id' từ Entity sang 'parentId' của DTO
    @Mapping(source = "parent.id", target = "parentId")
    CategoryResponse toDto(Category category);

    // Map danh sách
    List<CategoryResponse> toDtoList(List<Category> categories);
}