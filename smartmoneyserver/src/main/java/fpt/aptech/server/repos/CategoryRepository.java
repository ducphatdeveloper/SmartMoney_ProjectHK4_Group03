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

    // =================================================================================
    // CÁC HÀM CHO 3 TAB CHÍNH (API: /api/categories?group=...)
    // =================================================================================

    /// [VIEW] Lấy danh sách cho tab "KHOẢN CHI" (loại trừ các mục nợ), sắp xếp theo cha-con.
    @Query("SELECT c FROM Category c LEFT JOIN c.parent p WHERE (c.account.id IS NULL OR c.account.id = :accountId) AND c.ctgType = false AND c.ctgName NOT IN :excludedNames " +
           "ORDER BY COALESCE(p.ctgName, c.ctgName) ASC, (CASE WHEN c.parent IS NULL THEN 0 ELSE 1 END) ASC, c.ctgName ASC")
    List<Category> findAllExpenseCategories(@Param("accountId") Integer accountId, @Param("excludedNames") List<String> excludedNames);

    /// [VIEW] Lấy danh sách cho tab "KHOẢN THU" (loại trừ các mục nợ), sắp xếp theo cha-con.
    @Query("SELECT c FROM Category c LEFT JOIN c.parent p WHERE (c.account.id IS NULL OR c.account.id = :accountId) AND c.ctgType = true AND c.ctgName NOT IN :excludedNames " +
           "ORDER BY COALESCE(p.ctgName, c.ctgName) ASC, (CASE WHEN c.parent IS NULL THEN 0 ELSE 1 END) ASC, c.ctgName ASC")
    List<Category> findAllIncomeCategories(@Param("accountId") Integer accountId, @Param("excludedNames") List<String> excludedNames);

    /// [VIEW] Lấy danh sách cho tab "ĐI VAY / CHO VAY", sắp xếp theo tên (tab này không có cha-con).
    @Query("SELECT c FROM Category c WHERE c.account.id IS NULL AND c.ctgName IN :debtNames ORDER BY c.ctgName ASC")
    List<Category> findDebtAndLoanCategories(@Param("debtNames") List<String> debtNames);


    // =================================================================================
    // CÁC HÀM CHO CHỨC NĂNG "CHỌN NHÓM CHA" (API: /api/categories/parents?type=...)
    // =================================================================================

    /// [VIEW] Lấy danh sách cha cho KHOẢN THU (chỉ lấy 'Lương' và phải là danh mục gốc).
    @Query("SELECT c FROM Category c WHERE (c.account.id IS NULL OR c.account.id = :accountId) AND c.ctgType = true AND c.ctgName = :incomeName AND c.parent IS NULL")
    List<Category> findIncomeParents(@Param("accountId") Integer accountId, @Param("incomeName") String incomeName);

    /// [VIEW] Lấy danh sách cha cho KHOẢN CHI (loại trừ một số danh mục và phải là danh mục gốc).
    @Query("SELECT c FROM Category c WHERE (c.account.id IS NULL OR c.account.id = :accountId) AND c.ctgType = false AND c.ctgName NOT IN :excludedNames AND c.parent IS NULL")
    List<Category> findExpenseParents(@Param("accountId") Integer accountId, @Param("excludedNames") List<String> excludedNames);


    // =================================================================================
    // CÁC HÀM KIỂM TRA (VALIDATE) TRƯỚC KHI TẠO/SỬA
    // =================================================================================

    /// [CREATE/UPDATE] Kiểm tra xem User này đã có danh mục GỐC nào trùng tên chưa.
    boolean existsByCtgNameAndAccount_IdAndParentIsNull(String ctgName, Integer accountId);

    /// [CREATE/UPDATE] Kiểm tra xem User này đã có danh mục CON nào trùng tên TRONG CÙNG MỘT CHA chưa.
    boolean existsByCtgNameAndParent_IdAndAccount_Id(String ctgName, Integer parentId, Integer accountId);

    /// [CREATE] Kiểm tra xem một danh mục GỐC của HỆ THỐNG có tồn tại theo tên không.
    boolean existsByCtgNameAndAccountIsNullAndParentIsNull(String ctgName);
    
    // =================================================================================
    // HÀM TÌM KIẾM TOÀN CỤC (API: /api/categories/search?name=...)
    // =================================================================================
    
    /// [SEARCH] Tìm tất cả danh mục (hệ thống + người dùng) theo tên (không phân biệt hoa/thường).
    @Query("SELECT c FROM Category c LEFT JOIN c.parent p WHERE (c.account.id IS NULL OR c.account.id = :accountId) AND LOWER(c.ctgName) LIKE LOWER(:searchTerm) " +
           "ORDER BY COALESCE(p.ctgName, c.ctgName) ASC, (CASE WHEN c.parent IS NULL THEN 0 ELSE 1 END) ASC, c.ctgName ASC")
    List<Category> searchAllUserAndSystemCategories(@Param("accountId") Integer accountId, @Param("searchTerm") String searchTerm);

    /// [VIEW] Lấy tất cả danh mục (hệ thống + người dùng) khi không có từ khóa tìm kiếm.
    @Query("SELECT c FROM Category c LEFT JOIN c.parent p WHERE (c.account.id IS NULL OR c.account.id = :accountId) " +
           "ORDER BY COALESCE(p.ctgName, c.ctgName) ASC, (CASE WHEN c.parent IS NULL THEN 0 ELSE 1 END) ASC, c.ctgName ASC")
    List<Category> findAllSystemAndUserCategories(@Param("accountId") Integer accountId);

    // =================================================================================
    // HÀM CHO NGÂN SÁCH (BUDGET)
    // =================================================================================

    /// [BUDGET] Expand cha → con an toàn đa user:
    /// Chỉ lấy con hệ thống (account=null) HOẶC con của chính user đó
    @Query("SELECT c FROM Category c " +
           "WHERE c.parent.id = :parentId " +
           "  AND (c.account IS NULL OR c.account.id = :accountId)")
    List<Category> findChildrenForBudget(
            @Param("parentId") Integer parentId,
            @Param("accountId") Integer accountId);

    // =================================================================================
    // HÀM CHO XÓA DANH MỤC (DELETE)
    // =================================================================================
    
    /// [DELETE] Kiểm tra xem danh mục cha có danh mục con nào không.
    /// Lưu ý: parent là @ManyToOne relationship, nên dùng parent_Id (dấu gạch dưới để truy cập ID của parent).
    /// Thêm filter account_id để security: chỉ check con của chính user đó hoặc danh mục hệ thống.
    @Query("SELECT CASE WHEN COUNT(c) > 0 THEN true ELSE false END FROM Category c " +
           "WHERE c.parent.id = :parentId " +
           "  AND (c.account IS NULL OR c.account.id = :accountId)")
    boolean existsByParent_Id(@Param("parentId") Integer parentId, @Param("accountId") Integer accountId);

    /// [DELETE] Lấy tất cả danh mục con của một danh mục cha (dùng cho CASCADE DELETE).
    /// Chỉ lấy con của chính user đó hoặc danh mục hệ thống.
    @Query("SELECT c FROM Category c " +
           "WHERE c.parent.id = :parentId " +
           "  AND (c.account IS NULL OR c.account.id = :accountId)")
    List<Category> findByParent_IdAndAccount_Id(@Param("parentId") Integer parentId, @Param("accountId") Integer accountId);
}
