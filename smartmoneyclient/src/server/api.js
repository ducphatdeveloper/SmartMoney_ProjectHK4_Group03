import axios from 'axios';

// 1. Cấu hình cơ sở cho Axios
const api = axios.create({
    baseURL: 'http://localhost:9999/api', // Cổng 9999 từ file properties của bạn ⚙️
    headers: {
        'Content-Type': 'application/json',
    },
});

// 2. Các hàm gọi API
export const authApi = {
    // Đăng nhập 🔑
    login: (loginData) => api.post('/auth/login', loginData),

    // Đăng ký 📝
    register: (registerData) => api.post('/auth/register', registerData),

    // Đăng xuất 🚪
    logout: (deviceToken) => api.post(`/auth/logout?deviceToken=${deviceToken}`),
};

export const notificationApi = {
    // Lấy thông báo theo ID tài khoản 🔔
    getByUser: (accId) => api.get(`/notifications/user/${accId}`),

    // Đánh dấu đã gửi/đọc ✅
    markAsSent: (id) => api.put(`/notifications/${id}/sent`),
};

export const permissionApi = {
    // Lấy tất cả quyền 🛡️
    getAll: () => api.get('/permissions'),

    // Lấy quyền theo nhóm 📋
    getByGroup: (groupName) => api.get(`/permissions/group/${groupName}`),
};

