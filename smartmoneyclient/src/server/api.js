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
    // axios tự động chuyển object thành JSON
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

// --- PHẦN BỔ SUNG ĐỂ SỬA LỖI ---
export const permissionApi = {
    // Lấy tất cả quyền 🛡️
    getAll: () => api.get('/permissions'),

    // Lấy quyền theo nhóm 📋
    getByGroup: (groupName) => api.get(`/permissions/group/${groupName}`),
};

export const adminApi = {
    // Quản lý người dùng (Admin) 👮
    // Params: search (string), locked (boolean), page (int), size (int), sort (string)
    getUsers: (params) => api.get('/admin/users', { params }),
    lockUser: (id) => api.put(`/admin/users/${id}/lock`),
    unlockUser: (id) => api.put(`/admin/users/${id}/unlock`),
    getStats: () => api.get('/admin/stats'),
};