import axios from 'axios';

// 1. Cấu hình cơ sở cho Axios
const api = axios.create({
    baseURL: 'http://localhost:9999/api',
    headers: {
        'Content-Type': 'application/json',
    },
});

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