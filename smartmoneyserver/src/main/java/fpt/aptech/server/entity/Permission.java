package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "tPermissions")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Permission {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "per_code", unique = true, nullable = false, length = 50)
    private String perCode;

    @Column(name = "per_name", unique = true, nullable = false, length = 100)
    private String perName;

    @Column(name = "module_group", nullable = false, length = 50)
    private String moduleGroup;
}