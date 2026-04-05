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

    // =================================================================================
    // 1. USER — Gửi yêu cầu mới
    // =================================================================================

    @Override
    @Transactional
    public ContactRequestResponse createRequest(int accId, ContactRequestCreateRequest request) {

        // [1] Lấy thông tin User
        Account currentUser = accountRepository.findById(accId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại."));

        // [2] Validate: phải có ít nhất phone HOẶC email liên hệ
        boolean hasPhone = request.contactPhone() != null && !request.contactPhone().isBlank();
        boolean hasEmail = request.contactEmail() != null && !request.contactEmail().isBlank();
        if (!hasPhone && !hasEmail) {
            throw new IllegalArgumentException(
                    "Vui lòng cung cấp ít nhất một số điện thoại hoặc địa chỉ email để liên hệ.");
        }

        // [3] Map DTO → Entity
        ContactRequest entity = contactRequestMapper.toEntity(request);
        entity.setAccount(currentUser);
        entity.setRequestStatus(ContactRequestStatus.PENDING);

        // [4] Set fullname: ưu tiên user tự nhập, fallback về account.fullname
        if (request.fullname() != null && !request.fullname().isBlank()) {
            entity.setFullname(request.fullname());
        } else if (currentUser.getFullname() != null && !currentUser.getFullname().isBlank()) {
            entity.setFullname(currentUser.getFullname());
        } else {
            entity.setFullname(currentUser.getAccEmail()); // fallback tối thiểu
        }

        // [5] Set priority theo rule database:
        //     URGENT : SUSPICIOUS_TX, EMERGENCY
        //     HIGH   : ACCOUNT_LOCK, ACCOUNT_UNLOCK, DATA_LOSS
        //     NORMAL : BUG_REPORT, DATA_RECOVERY, GENERAL, FORGOT_PASSWORD
        ContactRequestType rType = request.requestType();
        if (rType == ContactRequestType.SUSPICIOUS_TX || rType == ContactRequestType.EMERGENCY) {
            entity.setRequestPriority(ContactRequestPriority.URGENT);
        } else if (rType == ContactRequestType.ACCOUNT_LOCK
                || rType == ContactRequestType.ACCOUNT_UNLOCK
                || rType == ContactRequestType.DATA_LOSS) {
            entity.setRequestPriority(ContactRequestPriority.HIGH);
        } else {
            entity.setRequestPriority(ContactRequestPriority.NORMAL);
        }

        // [6] Lưu vào DB
        ContactRequest saved = contactRequestRepository.save(entity);

        // [7] Gửi thông báo cho tất cả Admin: "Có yêu cầu mới cần xử lý"
        List<Account> admins = accountRepository.findByRole_RoleCode("ROLE_ADMIN");
        for (Account admin : admins) {
            notificationService.createNotification(
                    admin,
                    "Yêu cầu hỗ trợ mới",
                    "Có yêu cầu [" + request.requestType() + "] từ "
                            + entity.getFullname() + " cần xử lý.",
                    NotificationType.SYSTEM,
                    saved.getId().longValue(),
                    null
            );
        }

        return contactRequestMapper.toResponse(saved);
    }

    // =================================================================================
    // 2. USER — Xem lịch sử yêu cầu
    // =================================================================================

    @Override
    @Transactional(readOnly = true)
    public List<ContactRequestResponse> getMyRequests(int accId) {
        List<ContactRequest> requests = contactRequestRepository.findAllByAccountId(accId);
        return contactRequestMapper.toResponseList(requests);
    }

    // =================================================================================
    // 3. ADMIN — Xem tất cả yêu cầu (filter)
    // =================================================================================

    @Override
    @Transactional(readOnly = true)
    public List<ContactRequestResponse> getAllRequests(String status, String type) {
        // Parse enum từ String, null nếu không truyền
        ContactRequestStatus statusEnum = null;
        ContactRequestType typeEnum = null;

        if (status != null && !status.isBlank()) {
            statusEnum = ContactRequestStatus.valueOf(status.toUpperCase());
        }
        if (type != null && !type.isBlank()) {
            typeEnum = ContactRequestType.valueOf(type.toUpperCase());
        }

        List<ContactRequest> requests = contactRequestRepository.findAllByFilters(statusEnum, typeEnum);
        return contactRequestMapper.toResponseList(requests);
    }

    // =================================================================================
    // 4. ADMIN — Duyệt / Từ chối yêu cầu
    // =================================================================================

    @Override
    @Transactional
    public ContactRequestResponse resolveRequest(int adminId, int requestId,
                                                 ContactRequestResolveRequest request) {

        // [1] Validate status chỉ chấp nhận PROCESSING | APPROVED | REJECTED
        ContactRequestStatus newStatus = request.requestStatus();
        if (newStatus == ContactRequestStatus.PENDING) {
            throw new IllegalArgumentException(
                    "Không thể đặt trạng thái về PENDING. Chỉ chấp nhận: PROCESSING, APPROVED, REJECTED.");
        }

        // [2] Tìm yêu cầu
        ContactRequest entity = contactRequestRepository.findById(requestId)
                .orElseThrow(() -> new IllegalArgumentException(
                        "Không tìm thấy yêu cầu hỗ trợ với ID: " + requestId));

        // [3] Lấy thông tin Admin
        Account admin = accountRepository.findById(adminId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản Admin không tồn tại."));

        // [4] Cập nhật trạng thái
        entity.setRequestStatus(newStatus);
        if (request.adminNote() != null) {
            entity.setAdminNote(request.adminNote());
        }

        // [5] Nếu chuyển sang PROCESSING → set processedAt
        if (newStatus == ContactRequestStatus.PROCESSING && entity.getProcessedAt() == null) {
            entity.setProcessedAt(LocalDateTime.now());
        }

        // [6] Nếu chuyển sang APPROVED hoặc REJECTED → set resolvedBy + resolvedAt
        if (newStatus == ContactRequestStatus.APPROVED || newStatus == ContactRequestStatus.REJECTED) {
            entity.setResolvedBy(admin);
            entity.setResolvedAt(LocalDateTime.now());
            // Nếu chưa ai nhận xử lý → Admin vừa nhận vừa duyệt luôn
            if (entity.getProcessedAt() == null) {
                entity.setProcessedAt(LocalDateTime.now());
            }
        }

        // [7] Xử lý nghiệp vụ đặc biệt khi APPROVED
        if (newStatus == ContactRequestStatus.APPROVED && entity.getAccount() != null) {
            if (entity.getRequestType() == ContactRequestType.ACCOUNT_LOCK) {
                adminService.lockAccount(entity.getAccount().getId());
            }
            if (entity.getRequestType() == ContactRequestType.ACCOUNT_UNLOCK) {
                adminService.unlockAccount(entity.getAccount().getId());
            }
        }

        // [8] Lưu vào DB
        ContactRequest saved = contactRequestRepository.save(entity);

        // [9] Gửi thông báo cho User (nếu có account — guest không nhận được)
        if (entity.getAccount() != null) {
            String statusLabel = switch (newStatus) {
                case PROCESSING -> "đang được xử lý";
                case APPROVED   -> "đã được chấp nhận";
                case REJECTED   -> "đã bị từ chối";
                default         -> "đã được cập nhật";
            };
            notificationService.createNotification(
                    entity.getAccount(),
                    "Cập nhật yêu cầu hỗ trợ",
                    "Yêu cầu \"" + entity.getTitle() + "\" " + statusLabel + ".",
                    NotificationType.SYSTEM,
                    saved.getId().longValue(),
                    null
            );
        }

        return contactRequestMapper.toResponse(saved);
    }

    // =================================================================================
    // 5. INTERNAL — Tạo ticket giao dịch bất thường (gọi từ TransactionService)
    // =================================================================================

    @Override
    @Transactional
    public ContactRequest createSuspiciousRequest(int accId, String description) {

        Account user = accountRepository.findById(accId)
                .orElseThrow(() -> new IllegalArgumentException("Tài khoản không tồn tại."));

        // fullname: ưu tiên fullname của account, fallback về email
        String displayName = (user.getFullname() != null && !user.getFullname().isBlank())
                ? user.getFullname() : user.getAccEmail();

        ContactRequest entity = ContactRequest.builder()
                .account(user)
                .requestType(ContactRequestType.SUSPICIOUS_TX)
                .requestPriority(ContactRequestPriority.URGENT)
                .title("Hệ thống phát hiện giao dịch bất thường")
                .requestDescription(description)
                .fullname(displayName)
                .contactPhone(user.getAccPhone())
                .contactEmail(user.getAccEmail())
                .requestStatus(ContactRequestStatus.PENDING)
                .build();

        // Trả về entity đã lưu để TransactionService lấy ID làm related_id cho notification Admin
        // KHÔNG gửi notification ở đây — TransactionService tự gửi cho User VÀ tất cả Admin.
        return contactRequestRepository.save(entity);
    }
}

