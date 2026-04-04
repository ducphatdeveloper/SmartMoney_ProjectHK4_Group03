package fpt.aptech.server.repos;

import fpt.aptech.server.entity.ContactRequest;
import fpt.aptech.server.enums.contact.ContactRequestStatus;
import fpt.aptech.server.enums.contact.ContactRequestType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ContactRequestRepository extends JpaRepository<ContactRequest, Integer> {

    /**
     * [a] Tìm tất cả yêu cầu của 1 user, sắp xếp mới nhất trước.
     */
    @Query("SELECT cr FROM ContactRequest cr WHERE cr.account.id = :accId ORDER BY cr.createdAt DESC")
    List<ContactRequest> findAllByAccountId(@Param("accId") Integer accId);

    /**
     * [b] Tìm tất cả yêu cầu theo status + priority (Admin dashboard).
     * Nếu status hoặc priority là null thì bỏ qua điều kiện đó.
     */
    @Query("SELECT cr FROM ContactRequest cr " +
            "WHERE (:status IS NULL OR cr.requestStatus = :status) " +
            "AND (:type IS NULL OR cr.requestType = :type) " +
            "ORDER BY cr.requestPriority ASC, cr.createdAt DESC")
    List<ContactRequest> findAllByFilters(
            @Param("status") ContactRequestStatus status,
            @Param("type") ContactRequestType type);

    /**
     * [c] Tìm theo request_type + status (thống kê).
     */
    @Query("SELECT cr FROM ContactRequest cr " +
            "WHERE cr.requestType = :type AND cr.requestStatus = :status " +
            "ORDER BY cr.createdAt DESC")
    List<ContactRequest> findByTypeAndStatus(
            @Param("type") ContactRequestType type,
            @Param("status") ContactRequestStatus status);
}

