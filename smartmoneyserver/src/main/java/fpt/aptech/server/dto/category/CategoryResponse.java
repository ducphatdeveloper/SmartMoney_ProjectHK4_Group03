package fpt.aptech.server.dto.category;

import lombok.Builder;

/**
 * DTO trả về thông tin danh mục cho Client.
 * Sử dụng Java Record (Java 14+) để tạo object bất biến, hiệu năng cao.
 */
@Builder
public record CategoryResponse(
    Integer id,
    String ctgName,
    Boolean ctgType,
    String ctgIconUrl,
    Integer parentId
) {}