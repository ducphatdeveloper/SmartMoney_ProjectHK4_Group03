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
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class ContactRequestServiceImpl implements ContactRequestService {

    private final ContactRequestRepository contactRequestRepository;
    private final ContactRequestMapper      contactRequestMapper;
    private final AccountRepository         accountRepository;
    private final NotificationService       notificationService;

    private AdminService adminService;
    @org.springframework.context.annotation.Lazy
    @org.springframework.beans.factory.annotation.Autowired
    public void setAdminService(AdminService adminService) {
        this.adminService = adminService;
    }

    @Override
    @Transactional
    public ContactRequestResponse createRequest(int accId, ContactRequestCreateRequest request) {
        Account targetAccount = null;

        // 1. Xác định Account dựa trên login hoặc thông tin cung cấp (nếu là guest)
        if (accId > 0) {
            targetAccount = accountRepository.findById(accId)
                    .orElseThrow(() -> new IllegalArgumentException("Account does not exist."));
        } else {
            // Guest mode: Tìm account dựa trên email hoặc phone cung cấp trong form
            if (request.contactEmail() != null && !request.contactEmail().isBlank()) {
                targetAccount = accountRepository.findByAccEmail(request.contactEmail()).orElse(null);
            }
            if (targetAccount == null && request.contactPhone() != null && !request.contactPhone().isBlank()) {
                targetAccount = accountRepository.findByAccPhone(request.contactPhone()).orElse(null);
            }
        }

        boolean hasPhone = request.contactPhone() != null && !request.contactPhone().isBlank();
        boolean hasEmail = request.contactEmail() != null && !request.contactEmail().isBlank();
        if (!hasPhone && !hasEmail) {
            throw new IllegalArgumentException("Provide at least a phone number or email.");
        }

        ContactRequest entity = contactRequestMapper.toEntity(request);
        entity.setAccount(targetAccount); // Có thể vẫn null nếu không tìm thấy account nào khớp
        entity.setRequestStatus(ContactRequestStatus.PENDING);

        if (request.fullname() != null && !request.fullname().isBlank()) {
            entity.setFullname(request.fullname());
        } else if (targetAccount != null) {
            entity.setFullname(targetAccount.getFullname() != null ? targetAccount.getFullname() : targetAccount.getAccEmail());
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

        // Thông báo cho Admin
        List<Account> admins = accountRepository.findByRole_RoleCode("ROLE_ADMIN");
        String priorityPrefix = saved.getRequestPriority() == ContactRequestPriority.URGENT ? "🚨 [URGENT] " : "📋 ";
        for (Account admin : admins) {
            notificationService.createNotification(
                admin, 
                priorityPrefix + "New support request",
                "Type: " + rType + " from " + entity.getFullname() + (targetAccount == null ? " (Guest)" : "") + ". Ticket #" + saved.getId(), 
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
        if (newStatus == ContactRequestStatus.PENDING) throw new IllegalArgumentException("Cannot revert to PENDING status.");

        ContactRequest entity = contactRequestRepository.findById(requestId).orElseThrow(() -> new IllegalArgumentException("Ticket not found."));
        Account admin = accountRepository.findById(adminId).orElseThrow(() -> new IllegalArgumentException("Admin does not exist."));

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

        contactRequestRepository.saveAndFlush(entity);

        if (newStatus == ContactRequestStatus.APPROVED && entity.getAccount() != null) {
            if (entity.getRequestType() == ContactRequestType.ACCOUNT_LOCK) {
                adminService.lockAccount(entity.getAccount().getId());
            } else if (entity.getRequestType() == ContactRequestType.ACCOUNT_UNLOCK) {
                adminService.unlockAccount(entity.getAccount().getId());
            }
        }

        if (entity.getAccount() != null) {
            String statusLabel = (newStatus == ContactRequestStatus.APPROVED) ? "has been ACCEPTED" : 
                                (newStatus == ContactRequestStatus.REJECTED) ? "has been REJECTED" : "is being PROCESSED";
            notificationService.createNotification(
                entity.getAccount(), 
                "Support request update", 
                "Your request '" + entity.getTitle() + "' " + statusLabel + ". Admin note: " + (entity.getAdminNote() != null ? entity.getAdminNote() : "None."), 
                NotificationType.SYSTEM, 
                entity.getId().longValue(), 
                LocalDateTime.now()
            );
        }

        return contactRequestMapper.toResponse(entity);
    }

    @Override
    @Transactional(readOnly = true)
    public ContactRequestResponse getRequestById(int requestId, int adminId) {
        ContactRequest entity = contactRequestRepository.findById(requestId).orElseThrow(() -> new IllegalArgumentException("Ticket not found."));
        return contactRequestMapper.toResponse(entity);
    }

    @Override
    @Transactional
    public ContactRequest createSuspiciousRequest(int accId, String description) {
        Account user = accountRepository.findById(accId).orElseThrow(() -> new IllegalArgumentException("User does not exist."));
        ContactRequest entity = ContactRequest.builder()
                .account(user)
                .requestType(ContactRequestType.SUSPICIOUS_TX)
                .requestPriority(ContactRequestPriority.URGENT)
                .title("Suspicious transaction")
                .requestDescription(description)
                .fullname(user.getFullname() != null ? user.getFullname() : user.getAccEmail())
                .contactPhone(user.getAccPhone())
                .contactEmail(user.getAccEmail())
                .requestStatus(ContactRequestStatus.PENDING)
                .build();
        return contactRequestRepository.save(entity);
    }

    @Override
    @Transactional
    public void handleSecurityAction(Integer accountId, String action, String note) {
        List<ContactRequest> pendingRequests = contactRequestRepository.findAllByFilters(
                ContactRequestStatus.PENDING, 
                ContactRequestType.SUSPICIOUS_TX, 
                null
        ).stream()
        .filter(r -> r.getAccount() != null && r.getAccount().getId().equals(accountId))
        .toList();

        if (pendingRequests.isEmpty()) return;

        for (ContactRequest ticket : pendingRequests) {
            ticket.setRequestStatus(ContactRequestStatus.APPROVED);
            ticket.setAdminNote("[Automatic system] " + note);
            ticket.setResolvedAt(LocalDateTime.now());
        }
        
        contactRequestRepository.saveAll(pendingRequests);
    }
}
