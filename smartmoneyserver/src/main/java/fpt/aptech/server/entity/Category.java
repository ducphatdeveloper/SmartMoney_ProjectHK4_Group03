package fpt.aptech.server.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;

import java.util.List;

/**
 * Bảng danh mục thu/chi.
 * Hỗ trợ cấu trúc cha-con và phân biệt giữa danh mục hệ thống và người dùng.
 */
@Entity
@Table(name = "tCategories")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Category {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // Danh mục của người dùng nào. NULL nếu là danh mục hệ thống.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "acc_id")
    private Account account;

    // Quan hệ tự tham chiếu: trỏ đến danh mục cha.
    // @JsonIgnore là bắt buộc để tránh lỗi vòng lặp JSON khi serialize.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_id")
    @JsonIgnore
    private Category parent;

    // Quan hệ ngược: danh sách các danh mục con.
    // LAZY fetch là cần thiết để tối ưu hiệu năng.
    @OneToMany(mappedBy = "parent", fetch = FetchType.LAZY)
    private List<Category> children;

    // Tên danh mục (VD: "Ăn uống")
    @Column(name = "ctg_name", nullable = false, length = 100)
    private String ctgName;

    // Loại danh mục: false (0) = Chi tiêu, true (1) = Thu nhập.
    @Column(name = "ctg_type", nullable = false)
    private Boolean ctgType;

    @Column(name = "ctg_icon_url", length = 2048)
    private String ctgIconUrl;
}