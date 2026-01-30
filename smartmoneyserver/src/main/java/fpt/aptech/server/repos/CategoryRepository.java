package fpt.aptech.server.repos;

import fpt.aptech.server.entity.Category;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CategoryRepository extends JpaRepository<Category, Integer> {

    /**
     * Lấy tất cả danh mục của HỆ THỐNG (acc_id IS NULL) và
     * tất cả danh mục của một người dùng cụ thể (acc_id = ?).
     * Đây là phương thức cốt lõi cho chức năng "View".
     */
    @Query("SELECT c FROM Category c WHERE c.account.id IS NULL OR c.account.id = :accountId")
    List<Category> findSystemAndUserCategoriesByAccount_Id(@Param("accountId") Integer accountId);

    /**
     * Tìm một danh mục theo ID và đảm bảo nó thuộc quyền sở hữu của người dùng.
     * Rất quan trọng cho việc Update và Delete để tránh sửa/xóa dữ liệu của người khác.
     */
    Optional<Category> findByIdAndAccount_Id(Integer categoryId, Integer accountId);

    /**
     * Kiểm tra xem một danh mục con có tồn tại với cùng tên, cùng cha, và cùng người sở hữu không.
     * Dùng để ngăn tạo trùng lặp.
     */
    boolean existsByParent_IdAndCtgNameAndAccount_Id(Integer parentId, String ctgName, Integer accountId);

    /**
     * Tương tự như trên nhưng cho danh mục cha (không có parent_id).
     */
    boolean existsByParent_IdIsNullAndCtgNameAndAccount_Id(String ctgName, Integer accountId);
}
