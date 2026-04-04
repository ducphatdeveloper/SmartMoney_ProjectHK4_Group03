package fpt.aptech.server.service.contact;

import fpt.aptech.server.dto.contact.ContactRequestCreateRequest;
import fpt.aptech.server.dto.contact.ContactRequestResolveRequest;
import fpt.aptech.server.dto.contact.ContactRequestResponse;

import java.util.List;

/**
 * Service xử lý yêu cầu hỗ trợ / liên hệ từ người dùng.
 */
public interface ContactRequestService {

    /**
     * User gửi yêu cầu hỗ trợ mới.
     * Tự động set priority=URGENT nếu type=SUSPICIOUS_TX.
     * Gửi thông báo cho Admin sau khi tạo.
     */
    ContactRequestResponse createRequest(int accId, ContactRequestCreateRequest request);

    /**
     * User xem lịch sử yêu cầu của mình.
     */
    List<ContactRequestResponse> getMyRequests(int accId);

    /**
     * Admin xem tất cả yêu cầu (lọc theo status, type).
     */
    List<ContactRequestResponse> getAllRequests(String status, String type);

    /**
     * Admin duyệt hoặc từ chối yêu cầu.
     * Nếu APPROVED + ACCOUNT_LOCK → gọi AdminService.lockAccount().
     * Nếu APPROVED + ACCOUNT_UNLOCK → gọi AdminService.unlockAccount().
     */
    ContactRequestResponse resolveRequest(int adminId, int requestId, ContactRequestResolveRequest request);

    /**
     * Tạo yêu cầu tự động khi hệ thống phát hiện giao dịch bất thường.
     * INTERNAL — gọi từ TransactionService, KHÔNG gửi notification ở đây.
     */
    void createSuspiciousRequest(int accId, String description);
}

