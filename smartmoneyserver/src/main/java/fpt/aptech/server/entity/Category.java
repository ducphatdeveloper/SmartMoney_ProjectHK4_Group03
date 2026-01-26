package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "tCategories")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Category {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "acc_id")
    private Account account;

    @ManyToOne
    @JoinColumn(name = "parent_id")
    private Category parent;

    @Column(name = "ctg_name", nullable = false, length = 100)
    private String ctgName;

    @Column(name = "ctg_type", nullable = false)
    private Boolean ctgType; // false: Chi tiêu | true: Thu nhập

    @Column(name = "ctg_icon_url", length = 2048)
    private String ctgIconUrl;
}