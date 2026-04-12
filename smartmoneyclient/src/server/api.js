import axios from 'axios';

const api = axios.create({
    baseURL: 'http://localhost:9999/api',
    headers: {
        'Content-Type': 'application/json',
    },
});

api.interceptors.request.use((config) => {
    const token = localStorage.getItem('accessToken');
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
}, (error) => Promise.reject(error));

export const authApi = {
    login: (credentials) => api.post('/auth/login', credentials),
    register: (registerData) => api.post('/auth/register', registerData),
    forgotPassword: (data) => api.post('/auth/forgot-password', data),
    resetPassword: (data) => api.post('/auth/reset-password', data),
    logout: (deviceToken) => api.post('/auth/logout', null, {
        params: { deviceToken }
    }),
};

export const userApi = {
    getProfile: () => api.get('/users/profile'),
    updateProfile: (data) => api.put('/users/profile', data),
    getDashboardStats: () => api.get('/users/dashboard/stats'),
    createContactRequest: (data) => api.post('/contact-requests', data),
    getMyContactRequests: () => api.get('/contact-requests/my'),
};

export const notificationApi = {
    getNotifications: () => api.get('/notifications'),
    getAdminSystemNotifications: () => api.get('/notifications/admin/system'),
    markAsRead: (id) => api.put(`/notifications/${id}/read`),
    markAllAsRead: () => api.put('/notifications/read-all'),
    delete: (id) => api.delete(`/notifications/${id}`),
};

export const utilApi = {
    // Lấy danh sách các khoảng thời gian để vẽ thanh trượt (DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY)
    getDateRanges: (mode, past = 24) => api.get('/utils/date-ranges', {
        params: { mode, past }
    }),
};

// --- ADMIN API ---
export const adminApi = {
    getUsers: (params) => api.get('/admin/users', { params: cleanParams(params) }),
    lockAccount: (id) => api.put(`/admin/users/${id}/lock`),
    unlockAccount: (id) => api.put(`/admin/users/${id}/unlock`),
    getUserFinancialInsights: (id) => api.get(`/admin/users/${id}/insights`),
    getUserTransactions: (id, params) => api.get(`/admin/users/${id}/transactions`, { 
        params: cleanParams(params) 
    }),
    getAllUserTransactions: (id, params) => api.get(`/admin/users/${id}/transactions/all`, {
        params: cleanParams(params)
    }),
    getGlobalDeletedTransactions: () => api.get('/admin/transactions/deleted-global'),
    restoreTransaction: (id) => api.patch(`/admin/transactions/${id}/restore`),
    restoreAllUserTransactions: (userId) => api.patch(`/admin/users/${userId}/transactions/restore-all`),
    getStats: () => api.get('/admin/stats'), 
    getOnlineUsers: () => api.get('/admin/analytics/online-users'),
    getAllLiveOnlineUsers: () => api.get('/admin/analytics/live-online-users'),
    getSystemTransactionStats: (params) => api.get('/admin/system/transaction-stats', {
        params: cleanParams(params)
    }),
    // notifyAbnormalTransactions: (threshold) => api.post('/admin/system/notify-abnormal', null, {
    //     params: { threshold: threshold?.toString() }
    // }),
    // getAbnormalUsers: (threshold) => api.get('/admin/system/abnormal-users', {
    //     params: { threshold: threshold?.toString() }
    // }),
    handleAutoLogout: () => api.post('/admin/system/auto-logout'),
    getAdminNotifications: (adminId) => api.get(`/admin/notifications/${adminId}`),
    getAllContactRequests: (params) => api.get('/admin/contact-requests', { params: cleanParams(params) }),
    getContactRequestById: (id) => api.get(`/admin/contact-requests/${id}`),
    resolveContactRequest: (id, data) => api.patch(`/admin/contact-requests/${id}/resolve`, data),
};

const cleanParams = (params) => {
    const cleaned = {};
    if (!params) return cleaned;
    Object.keys(params).forEach(key => {
        const value = params[key];
        if (value !== undefined && value !== null && value !== '') {
            cleaned[key] = value;
        }
    });
    return cleaned;
};

export const transactionApi = {
    getJournal: (params) => api.get('/transactions/journal', { params: cleanParams(params) }),
    getGrouped: (params) => api.get('/transactions/grouped', { params: cleanParams(params) }),
    getSummary: (params) => api.get('/transactions/report/summary', { params: cleanParams(params) }),
    getCategoryReport: (params) => api.get('/transactions/report/category', { params: cleanParams(params) }),
    getFinancialReport: (params) => api.get('/transactions/report/financial', { params: cleanParams(params) }),
    getTrend: (params) => api.get('/transactions/report/trend', { params: cleanParams(params) }), 
    getById: (id) => api.get(`/transactions/${id}`),
    create: (data) => api.post('/transactions', data),
    update: (id, data) => api.put(`/transactions/${id}`, data),
    delete: (id) => api.delete(`/transactions/${id}`),
    search: (request) => api.post('/transactions/search', request),
    getAll: (params) => api.get('/transactions', { params }),
};
