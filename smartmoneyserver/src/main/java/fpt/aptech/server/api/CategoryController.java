package fpt.aptech.server.api;

import fpt.aptech.server.dto.category.CategoryResponse;
import fpt.aptech.server.service.category.CategoryService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
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
    public ResponseEntity<List<CategoryResponse>> getUserCategories() {
        // TODO: Sau này sẽ lấy ID từ Token của user đang đăng nhập (SecurityContext)
        // Hiện tại hardcode ID = 2 (User mẫu có dữ liệu trong DB) để test chức năng View
        Integer mockUserId = 2;

        List<CategoryResponse> result = categoryService.getCategoriesForAccount(mockUserId);
        
        return ResponseEntity.ok(result);
    }
}