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

// --- ADMIN API (Updated based on AdminController) ---
export const adminApi = {
    // GET /api/admin/users
    // Params: search (String), locked (Boolean), onlineStatus (String), pageable (page, size, sort)
    getUsers: (params) => api.get('/admin/users', { params }),

    // PUT /api/admin/users/{id}/lock
    lockUser: (id) => api.put(`/admin/users/${id}/lock`),

    // PUT /api/admin/users/{id}/unlock
    unlockUser: (id) => api.put(`/admin/users/${id}/unlock`),

    // GET /api/admin/stats
    getStats: () => api.get('/admin/stats'),

    // GET /api/admin/notifications/{adminId}
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