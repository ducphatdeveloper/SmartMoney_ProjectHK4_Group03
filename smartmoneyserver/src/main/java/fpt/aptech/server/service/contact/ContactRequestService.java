package fpt.aptech.server.service.contact;

import fpt.aptech.server.dto.contact.ContactRequestCreateRequest;
import fpt.aptech.server.dto.contact.ContactRequestResolveRequest;
import fpt.aptech.server.dto.contact.ContactRequestResponse;
import fpt.aptech.server.entity.ContactRequest;

import java.util.List;

public interface ContactRequestService {
    ContactRequestResponse createRequest(int accId, ContactRequestCreateRequest request);
    List<ContactRequestResponse> getMyRequests(int accId);

    // Cập nhật để hỗ trợ lọc theo Priority
    List<ContactRequestResponse> getAllRequests(String status, String type, String priority);

    ContactRequestResponse resolveRequest(int adminId, int requestId, ContactRequestResolveRequest request);
    ContactRequestResponse getRequestById(int requestId, int adminId);
    ContactRequest createSuspiciousRequest(int accId, String description);
}
