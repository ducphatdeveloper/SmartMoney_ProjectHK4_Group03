package fpt.aptech.server.dto.category;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class CategoryResponse {
    // ID định danh của danh mục
    private Integer id;

    // Tên hiển thị (VD: Ăn uống, Lương...)
    private String ctgName;

    // Loại danh mục: true = Thu nhập, false = Chi tiêu
    private Boolean ctgType;

    // URL hoặc tên file icon (VD: icon_food.svg)
    private String ctgIconUrl;

    // ID danh mục cha (nếu có). Null nếu là danh mục gốc.
    private Integer parentId;
}
