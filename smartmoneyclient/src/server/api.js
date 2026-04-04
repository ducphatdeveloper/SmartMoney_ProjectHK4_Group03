import axios from 'axios';

// 1. Cấu hình cơ sở cho Axios
const api = axios.create({
    baseURL: 'http://localhost:9999/api',
    headers: {
        'Content-Type': 'application/json',
    },
});

// Thêm interceptor để tự động gắn token vào header (Bắt buộc cho @PreAuthorize)
api.interceptors.request.use((config) => {
    const token = localStorage.getItem('accessToken');
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
}, (error) => Promise.reject(error));

// 2. Các hàm gọi API
export const authApi = {
    login: (credentials) => api.post('/auth/login', credentials),
    register: (registerData) => api.post('/auth/register', registerData),
    forgotPassword: (data) => api.post('/auth/forgot-password', data),
    resetPassword: (data) => api.post('/auth/reset-password', data),
    logout: (deviceToken) => api.post('/auth/logout', null, {
        params: { deviceToken }
    }),
};

export const notificationApi = {
    // Sửa path từ /notifications/user/${accId} thành /notifications/${accId} để tránh lỗi 404
    getByUser: (accId) => api.get(`/notifications/${accId}`),
    markAsRead: (id) => api.put(`/notifications/${id}/read`),
    markAllAsRead: (accId) => api.put(`/notifications/user/${accId}/read-all`),
};

export const permissionApi = {
    getAll: () => api.get('/permissions'),
    getByGroup: (groupName) => api.get(`/permissions/group/${groupName}`),
};

export const categoryApi = {
    getByGroup: (group) => api.get('/categories', { params: { group } }),
};

// --- ADMIN API (Updated based on latest AdminController) ---
export const adminApi = {
    // 1. Quản lý người dùng - Lấy danh sách & Lọc (search, locked, onlineStatus, pageable)
    getUsers: (params) => api.get('/admin/users', { params: cleanParams(params) }),

    // 2 & 3. Khóa/Mở khóa tài khoản
    lockAccount: (id) => api.put(`/admin/users/${id}/lock`),
    unlockAccount: (id) => api.put(`/admin/users/${id}/unlock`),

    // 3.1 Xem chỉ số tài chính chi tiết của một User (Read-only)
    getUserFinancialInsights: (id) => api.get(`/admin/users/${id}/insights`),

    // 3.2 Xem lịch sử giao dịch chi tiết của một User cụ thể (Backend default size: 5)
    getUserTransactions: (id, pageable) => api.get(`/admin/users/${id}/transactions`, { params: cleanParams(pageable) }),

    // 3.3 Lấy toàn bộ giao dịch của User (không phân trang) - Dùng cho xuất file
    getAllUserTransactions: (id) => api.get(`/admin/users/${id}/transactions/all`),

    // 4. Widget tổng quan (Dashboard Overview)
    getStats: () => api.get('/admin/stats'), 

    // 5. Chi tiết số lượng Online Users
    getOnlineUsers: () => api.get('/admin/analytics/online-users'),

    // 5.1 Toàn bộ danh sách người dùng đang trực tuyến (Live View)
    getAllLiveOnlineUsers: () => api.get('/admin/analytics/live-online-users'),

    // 6. Phân tích tài chính hệ thống (rangeMode: DAILY, WEEKLY, MONTHLY, YEARLY)
    getSystemTransactionStats: (rangeMode = "MONTHLY") => api.get('/admin/system/transaction-stats', {
        params: cleanParams({ rangeMode })
    }),

    // 7. Bảo mật: Kích hoạt quét và cảnh báo giao dịch bất thường 
    // Backend sử dụng @RequestParam nên threshold được truyền qua params thay vì body
    notifyAbnormalTransactions: (threshold) => api.post('/admin/system/notify-abnormal', null, { 
        params: cleanParams({ threshold }) 
    }),

    // 7.1 Lấy danh sách người dùng có giao dịch bất thường
    getAbnormalUsers: (threshold) => api.get('/admin/system/abnormal-users', { 
        params: cleanParams({ threshold }) 
    }),

    // 7.2 Thu hồi phiên đăng nhập quá hạn
    handleAutoLogout: () => api.post('/admin/system/auto-logout'),

    // 8. Thông báo Admin
    getAdminNotifications: (adminId) => api.get(`/admin/notifications/${adminId}`),
};

// --- USER API ---
export const userApi = {
    getProfile: () => api.get('/users/profile'),
    updateProfile: (data) => api.put('/users/profile', data),
    getDashboardStats: () => api.get('/users/dashboard/stats'),
};

// Helper function để loại bỏ các params rỗng/null tránh lỗi 400 khi parse Enum/Date ở Backend
const cleanParams = (params) => {
    const cleaned = {};
    if (!params) return cleaned;
    Object.keys(params).forEach(key => {
        const value = params[key];
        // Nếu value là undefined, null hoặc chuỗi rỗng thì bỏ qua
        if (value !== undefined && value !== null && value !== '') {
            cleaned[key] = value;
        }
    });
    return cleaned;
};

export const transactionApi = {
    // Nhóm API xem danh sách & Nhật ký
    // Sử dụng cleanParams để tránh gửi startDate/endDate rỗng gây lỗi 400
    getJournal: (params) => api.get('/transactions/journal', { params: cleanParams(params) }),
    getGrouped: (params) => api.get('/transactions/grouped', { params: cleanParams(params) }),

    // Nhóm API Báo cáo & Biểu đồ
    getSummary: (params) => api.get('/transactions/report/summary', { params: cleanParams(params) }),
    getCategoryReport: (params) => api.get('/transactions/report/category', { params: cleanParams(params) }),
    getFinancialReport: (params) => api.get('/transactions/report/financial', { params: cleanParams(params) }),
    getTrend: (params) => api.get('/transactions/report/trend', { params: cleanParams(params) }), // Dữ liệu thực tế cho biểu đồ thu chi

    // Nhóm API Hành động
    getById: (id) => api.get(`/transactions/${id}`),
    create: (data) => api.post('/transactions', data),
    update: (id, data) => api.put(`/transactions/${id}`, data),
    delete: (id) => api.delete(`/transactions/${id}`),
    search: (request) => api.post('/transactions/search', request),
    
    // Giữ lại getAll cho mục đích chung nếu cần
    getAll: (params) => api.get('/transactions', { params }),
};