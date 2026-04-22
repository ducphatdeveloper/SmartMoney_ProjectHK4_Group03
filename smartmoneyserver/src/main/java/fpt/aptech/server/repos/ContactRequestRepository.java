package fpt.aptech.server.repos;

import fpt.aptech.server.entity.ContactRequest;
import fpt.aptech.server.enums.contact.ContactRequestPriority;
import fpt.aptech.server.enums.contact.ContactRequestStatus;
import fpt.aptech.server.enums.contact.ContactRequestType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ContactRequestRepository extends JpaRepository<ContactRequest, Integer> {

    List<ContactRequest> findAllByAccountId(Integer accId);

    @Query("SELECT cr FROM ContactRequest cr WHERE " +
           "(:status IS NULL OR cr.requestStatus = :status) AND " +
           "(:type IS NULL OR cr.requestType = :type) AND " +
           "(:priority IS NULL OR cr.requestPriority = :priority) " +
           "ORDER BY cr.createdAt DESC, cr.id DESC")
    List<ContactRequest> findAllByFilters(
            @Param("status") ContactRequestStatus status,
            @Param("type") ContactRequestType type,
            @Param("priority") ContactRequestPriority priority);

    Optional<ContactRequest> findFirstByAccountIdAndRequestTypeAndRequestStatusOrderByCreatedAtDescIdDesc(
            Integer accountId, ContactRequestType requestType, ContactRequestStatus requestStatus);

    @Query("SELECT cr FROM ContactRequest cr WHERE cr.account.id = :accountId AND cr.requestType IN :types ORDER BY cr.createdAt DESC, cr.id DESC")
    List<ContactRequest> findLatestRequests(
            @Param("accountId") Integer accountId, 
            @Param("types") List<ContactRequestType> types);

    default Optional<ContactRequest> findFirstByAccountIdAndRequestTypeInOrderByCreatedAtDescIdDesc(Integer accountId, List<ContactRequestType> types) {
        return findLatestRequests(accountId, types).stream().findFirst();
    }
}
