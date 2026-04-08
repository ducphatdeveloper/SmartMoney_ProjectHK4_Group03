package fpt.aptech.server.service.contact;

import fpt.aptech.server.dto.contact.ContactRequestCreateRequest;
import fpt.aptech.server.dto.contact.ContactRequestResolveRequest;
import fpt.aptech.server.dto.contact.ContactRequestResponse;
import fpt.aptech.server.entity.Account;
import fpt.aptech.server.entity.ContactRequest;
import fpt.aptech.server.enums.contact.ContactRequestPriority;
import fpt.aptech.server.enums.contact.ContactRequestStatus;
import fpt.aptech.server.enums.contact.ContactRequestType;
import fpt.aptech.server.enums.notification.NotificationType;
import fpt.aptech.server.mapper.contact.ContactRequestMapper;
import fpt.aptech.server.repos.AccountRepository;
import fpt.aptech.server.repos.ContactRequestRepository;
import fpt.aptech.server.service.Admin.AdminService;
import fpt.aptech.server.service.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ContactRequestServiceImpl implements ContactRequestService {

    private final ContactRequestRepository contactRequestRepository;
    private final ContactRequestMapper      contactRequestMapper;
    private final AccountRepository         accountRepository;
    private final NotificationService       notificationService;
    private final AdminService              adminService;

    @Override
    @Transactional
    public ContactRequestResponse createRequest(int accId, ContactRequestCreateRequest request) {
        Account currentUser = accountRepository.findById(accId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại."));

        boolean hasPhone = request.contactPhone() != null && !request.contactPhone().isBlank();
        boolean hasEmail = request.contactEmail() != null && !request.contactEmail().isBlank();
        if (!hasPhone && !hasEmail) {
            throw new IllegalArgumentException("Cung cấp ít nhất SĐT hoặc Email.");
        }

        ContactRequest entity = contactRequestMapper.toEntity(request);
        entity.setAccount(currentUser);
        entity.setRequestStatus(ContactRequestStatus.PENDING);

        if (request.fullname() != null && !request.fullname().isBlank()) {
            entity.setFullname(request.fullname());
        } else {
            entity.setFullname(currentUser.getFullname() != null ? currentUser.getFullname() : currentUser.getAccEmail());
        }

        ContactRequestType rType = request.requestType();
        if (rType == ContactRequestType.SUSPICIOUS_TX || rType == ContactRequestType.EMERGENCY) {
            entity.setRequestPriority(ContactRequestPriority.URGENT);
        } else if (rType == ContactRequestType.ACCOUNT_LOCK || rType == ContactRequestType.ACCOUNT_UNLOCK || rType == ContactRequestType.DATA_LOSS) {
            entity.setRequestPriority(ContactRequestPriority.HIGH);
        } else {
            entity.setRequestPriority(ContactRequestPriority.NORMAL);
        }

        ContactRequest saved = contactRequestRepository.save(entity);

        // Thông báo cho tất cả Admin về yêu cầu mới (PHẦN 1.1 + 1.2 trong txt)
        List<Account> admins = accountRepository.findByRole_RoleCode("ROLE_ADMIN");
        String priorityPrefix = saved.getRequestPriority() == ContactRequestPriority.URGENT ? "🚨 [URGENT] " : "📋 ";
        for (Account admin : admins) {
            notificationService.createNotification(
                admin, 
                priorityPrefix + "Yêu cầu hỗ trợ mới", 
                "Loại: " + rType + " từ " + entity.getFullname() + ". Ticket #" + saved.getId(), 
                NotificationType.SYSTEM, 
                saved.getId().longValue(), 
                LocalDateTime.now()
            );
        }

        return contactRequestMapper.toResponse(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public List<ContactRequestResponse> getMyRequests(int accId) {
        return contactRequestMapper.toResponseList(contactRequestRepository.findAllByAccountId(accId));
    }

    @Override
    @Transactional(readOnly = true)
    public List<ContactRequestResponse> getAllRequests(String status, String type, String priority) {
        ContactRequestStatus statusEnum = (status != null && !status.isBlank()) ? ContactRequestStatus.valueOf(status.toUpperCase()) : null;
        ContactRequestType typeEnum = (type != null && !type.isBlank()) ? ContactRequestType.valueOf(type.toUpperCase()) : null;
        ContactRequestPriority priorityEnum = (priority != null && !priority.isBlank()) ? ContactRequestPriority.valueOf(priority.toUpperCase()) : null;

        return contactRequestMapper.toResponseList(contactRequestRepository.findAllByFilters(statusEnum, typeEnum, priorityEnum));
    }

    @Override
    @Transactional
    public ContactRequestResponse resolveRequest(int adminId, int requestId, ContactRequestResolveRequest request) {
        ContactRequestStatus newStatus = request.requestStatus();
        if (newStatus == ContactRequestStatus.PENDING) throw new IllegalArgumentException("Không thể về PENDING.");

        ContactRequest entity = contactRequestRepository.findById(requestId).orElseThrow(() -> new IllegalArgumentException("Không thấy ticket."));
        Account admin = accountRepository.findById(adminId).orElseThrow(() -> new IllegalArgumentException("Admin không tồn tại."));

        entity.setRequestStatus(newStatus);
        if (request.adminNote() != null) entity.setAdminNote(request.adminNote());

        if (newStatus == ContactRequestStatus.PROCESSING && entity.getProcessedAt() == null) {
            entity.setProcessedAt(LocalDateTime.now());
        }

        if (newStatus == ContactRequestStatus.APPROVED || newStatus == ContactRequestStatus.REJECTED) {
            entity.setResolvedBy(admin);
            entity.setResolvedAt(LocalDateTime.now());
            if (entity.getProcessedAt() == null) entity.setProcessedAt(LocalDateTime.now());
        }

        // Tự động Khóa/Mở khóa tài khoản khi Admin APPROVED (PHẦN 2 trong txt)
        if (newStatus == ContactRequestStatus.APPROVED && entity.getAccount() != null) {
            if (entity.getRequestType() == ContactRequestType.ACCOUNT_LOCK) adminService.lockAccount(entity.getAccount().getId());
            if (entity.getRequestType() == ContactRequestType.ACCOUNT_UNLOCK) adminService.unlockAccount(entity.getAccount().getId());
        }

        ContactRequest saved = contactRequestRepository.save(entity);

        // Thông báo cập nhật cho User (PHẦN 3 & 5 trong txt)
        if (entity.getAccount() != null) {
            String statusLabel = (newStatus == ContactRequestStatus.APPROVED) ? "đã được CHẤP NHẬN" : 
                                (newStatus == ContactRequestStatus.REJECTED) ? "đã bị TỪ CHỐI" : "đang được XỬ LÝ";
            notificationService.createNotification(
                entity.getAccount(), 
                "Cập nhật yêu cầu hỗ trợ", 
                "Yêu cầu '" + entity.getTitle() + "' của bạn " + statusLabel + ". Ghi chú admin: " + (entity.getAdminNote() != null ? entity.getAdminNote() : "Không có."), 
                NotificationType.SYSTEM, 
                saved.getId().longValue(), 
                LocalDateTime.now()
            );
        }

        return contactRequestMapper.toResponse(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public ContactRequestResponse getRequestById(int requestId, int adminId) {
        ContactRequest entity = contactRequestRepository.findById(requestId).orElseThrow(() -> new IllegalArgumentException("Không thấy ticket."));
        return contactRequestMapper.toResponse(entity);
    }

    @Override
    @Transactional
    public ContactRequest createSuspiciousRequest(int accId, String description) {
        Account user = accountRepository.findById(accId).orElseThrow(() -> new IllegalArgumentException("User không tồn tại."));
        ContactRequest entity = ContactRequest.builder()
                .account(user)
                .requestType(ContactRequestType.SUSPICIOUS_TX)
                .requestPriority(ContactRequestPriority.URGENT)
                .title("Giao dịch bất thường")
                .requestDescription(description)
                .fullname(user.getFullname() != null ? user.getFullname() : user.getAccEmail())
                .contactPhone(user.getAccPhone())
                .contactEmail(user.getAccEmail())
                .requestStatus(ContactRequestStatus.PENDING)
                .build();
        return contactRequestRepository.save(entity);
    }
}
