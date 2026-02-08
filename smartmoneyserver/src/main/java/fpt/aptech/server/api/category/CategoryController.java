package fpt.aptech.server.api.category;

import fpt.aptech.server.dto.category.CategoryRequest;
import fpt.aptech.server.dto.category.CategoryResponse;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.category.CategoryService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/categories")
public class CategoryController {

    @Autowired
    private CategoryService categoryService;

    /// API lấy danh sách danh mục cho 3 tab UI.
    @GetMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<CategoryResponse>>> getCategoriesByGroup(
            @RequestParam(defaultValue = "expense") String group,
            @AuthenticationPrincipal Account currentUser) {

        Integer userId = currentUser.getId();
        List<CategoryResponse> result = categoryService.getCategoriesByGroup(userId, group);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    /// API tìm kiếm toàn cục, trả về tất cả nếu không có từ khóa.
    @GetMapping("/search")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<CategoryResponse>>> searchAllCategories(
            // required = false: Cho phép không cần truyền tham số 'name'
            @RequestParam(name = "name", required = false) String name,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        List<CategoryResponse> result = categoryService.searchAllCategories(userId, name);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    /// API lấy danh sách danh mục cha, lọc theo loại (Thu/Chi).
    @GetMapping("/parents")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<List<CategoryResponse>>> getParentCategories(
            @RequestParam("type") Boolean ctgType,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        List<CategoryResponse> result = categoryService.getParentCategories(userId, ctgType);
        return ResponseEntity.ok(ApiResponse.success(result));
    }

    /// API tạo danh mục mới.
    @PostMapping
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<CategoryResponse>> createCategory(
            @Valid @RequestBody CategoryRequest request,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        CategoryResponse newCategory = categoryService.createCategory(request, userId);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(newCategory, "Tạo danh mục thành công"));
    }

    /// API cập nhật danh mục.
    @PutMapping("/{categoryId}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<CategoryResponse>> updateCategory(
            @PathVariable Integer categoryId,
            @Valid @RequestBody CategoryRequest request,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        CategoryResponse updatedCategory = categoryService.updateCategory(categoryId, request, userId);
        return ResponseEntity.ok(ApiResponse.success(updatedCategory, "Cập nhật danh mục thành công"));
    }

    /// API xóa danh mục.
    @DeleteMapping("/{categoryId}")
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')")
    public ResponseEntity<ApiResponse<Void>> deleteCategory(
            @PathVariable Integer categoryId,
            @AuthenticationPrincipal Account currentUser) {
        
        Integer userId = currentUser.getId();
        categoryService.deleteCategory(categoryId, userId);
        return ResponseEntity.ok(ApiResponse.success("Xóa danh mục thành công"));
    }
}