package fpt.aptech.server.api.category;

import fpt.aptech.server.dto.category.CategoryResponse;
import fpt.aptech.server.dto.response.ApiResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.service.category.CategoryService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/categories")
public class CategoryController {

    @Autowired
    private CategoryService categoryService;

    @GetMapping
    //1. PreAuthorize là để phân quyền ai được dùng controller này.
    @PreAuthorize("hasAuthority('USER_STANDARD_MANAGE')") // USER_STANDARD_MANAGE là quyền có sẵn trong câu lệnh insert gốc của database
    //2.
    // Trong ApplicationConfig.java đã cấu hình UserDetailsService trả về đối tượng Account (Entity).
    // Vì vậy, Principal trong SecurityContext chính là một object Account.
    // Sử dụng annotation @AuthenticationPrincipal để lấy thông tin User đang đăng nhập từ Token.
    public ResponseEntity<ApiResponse<List<CategoryResponse>>> getUserCategories(@AuthenticationPrincipal Account currentUser) {

        //3. Lấy ID thật từ user đang đăng nhập
        Integer userId = currentUser.getId();

        //4. Đổ về một list CategoryResponse
        List<CategoryResponse> result = categoryService.getCategoriesForAccount(userId);

        //5. Bọc trong ApiResponse.success() để JSON trả về chuẩn chung.
        return ResponseEntity.ok(ApiResponse.success(result));
    }
}