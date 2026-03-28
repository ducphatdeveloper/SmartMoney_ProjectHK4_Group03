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
    getByUser: (accId) => api.get(`/notifications/user/${accId}`),
    markAsSent: (id) => api.put(`/notifications/${id}/sent`),
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
    // 1. Quản lý người dùng
    getUsers: (params) => api.get('/admin/users', { params }), 

    // 2. Khóa/Mở khóa
    lockAccount: (id) => api.put(`/admin/users/${id}/lock`),
    unlockAccount: (id) => api.put(`/admin/users/${id}/unlock`),

    // 4. Thống kê tổng quan
    getStats: () => api.get('/admin/stats'),

    // 5. Online Users
    getOnlineUsers: () => api.get('/admin/analytics/online-users'),
    
    // 5.1 Toàn bộ danh sách người dùng đang trực tuyến
    getAllLiveOnlineUsers: () => api.get('/admin/analytics/live-online-users'),

    // 6. Biểu đồ giao dịch
    getSystemTransactionStats: (rangeMode = "MONTHLY") => api.get('/admin/system/transaction-stats', {
        params: { rangeMode }
    }),

    // 7. Giao dịch bất thường
    notifyAbnormalTransactions: (threshold) => api.post('/admin/system/notify-abnormal', null, {
        params: { threshold }
    }),
    getAbnormalUsers: (threshold) => api.get('/admin/system/abnormal-users', {
        params: { threshold }
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

export const transactionApi = {
    getRecent: (limit = 5) => api.get(`/transactions/recent?limit=${limit}`),
    getAll: (params) => api.get('/transactions', { params }),
    create: (data) => api.post('/transactions', data),
    getChartData: (period) => api.get(`/transactions/chart?period=${period}`),
};