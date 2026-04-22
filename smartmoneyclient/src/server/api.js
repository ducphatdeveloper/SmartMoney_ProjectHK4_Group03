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

// --- CLOUDINARY UTILS ---
export const CLOUDINARY_BASE = 'https://res.cloudinary.com/drd2hsocc/image/upload/f_auto,q_auto';

/**
 * Slugify: Chuyển tiếng Việt có dấu thành không dấu, thay ký tự đặc biệt bằng 1 dấu gạch ngang duy nhất.
 */
const slugify = (str) => {
    if (!str) return '';
    return str.normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '') // Loại bỏ dấu
        .toLowerCase()
        .replace(/đ/g, 'd')
        .replace(/[^a-z0-9]/g, ' ') // Thay ký tự không phải chữ/số bằng khoảng trắng
        .trim()
        .replace(/\s+/g, '-'); // Nén khoảng trắng thành 1 dấu gạch ngang
};

/**
 * Bản dịch danh mục (Từ Tiếng Anh sang Tiếng Việt)
 * Dùng để hiển thị khi người dùng chọn ngôn ngữ VN nhưng tên gốc là Tiếng Anh (hoặc slug).
 */
export const CATEGORY_TRANSLATIONS = {
    // --- NHÓM CHI TIÊU ---
    "food-beverage": "Ăn uống",
    "insurance": "Bảo hiểm",
    "other-expenses": "Các chi phí khác",
    "investment": "Đầu tư",
    "transportation": "Di chuyển",
    "family": "Gia đình",
    "entertainment": "Giải trí",
    "education": "Giáo dục",
    "bills-utilities": "Hoá đơn & Tiện ích",
    "shopping": "Mua sắm",
    "gifts-donations": "Quà tặng & Quyên góp",
    "health": "Sức khỏe",
    "health-fitness": "Sức khỏe",
    "outgoing-transfer": "Tiền chuyển đi",
    "interest-pay": "Trả lãi",
    "interest-paid": "Trả lãi",
    "lending": "Cho vay",
    "debt-repayment": "Trả nợ",

    // --- NHÓM THU NHẬP ---
    "salary": "Lương",
    "interest-receive": "Thu lãi",
    "interest-received": "Thu lãi",
    "other-income": "Thu nhập khác",
    "incoming-transfer": "Tiền chuyển đến",
    "borrowing": "Đi vay",
    "debt-collection": "Thu nợ",

    // --- DANH MỤC CON ---
    "vehicle-maintenance": "Bảo dưỡng xe",
    "home-services": "Dịch vụ gia đình",
    "home-renovation": "Sửa & trang trí nhà",
    "pets": "Vật nuôi",
    "online-services": "Dịch vụ trực tuyến",
    "travel-leisure": "Vui - chơi",
    "electricity-bill": "Hoá đơn điện",
    "phone-bill": "Hoá đơn điện thoại",
    "gas-bill": "Hoá đơn gas",
    "internet-bill": "Hoá đơn internet",
    "water-bill": "Hoá đơn nước",
    "other-utility-bills": "Hoá đơn tiện ích khác",
    "television-bill": "Hoá đơn TV",
    "rent": "Thuê nhà",
    "personal-items": "Đồ dùng cá nhân",
    "home-appliances": "Đồ gia dụng",
    "beauty": "Làm đẹp",
    "medical-checkup": "Khám sức khoẻ",
    "sports": "Thể dục thể thao"
};

/**
 * Hàm lấy tên danh mục theo ngôn ngữ.
 * Identifier có thể là tên danh mục gốc (Tiếng Anh/Tiếng Việt) hoặc slug.
 */
export const getCategoryName = (identifier, lang = 'vi') => {
    if (!identifier) return '';
    
    // Nếu chọn Tiếng Anh -> Trả về identifier (hoặc slugify nếu cần chuẩn hóa)
    if (lang === 'en') return identifier;

    // Nếu chọn Tiếng Việt -> Tra cứu trong CATEGORY_TRANSLATIONS dựa trên slug
    const slug = slugify(identifier);
    return CATEGORY_TRANSLATIONS[slug] || identifier;
};

/**
 * Mapping từ tên danh mục (tiếng Việt hoặc English slug) sang filename icon trên Cloudinary.
 */
const ICON_MAPPING = {
    // --- ENGLISH SLUGS (Khớp với SQL DB System) ---
    "food-beverage": "icon_food.png",
    "transportation": "icon_transport.png",
    "shopping": "icon_shopping.png",
    "salary": "icon_salary.png",
    "investment": "icon_invest.png",
    "education": "icon_education.png",
    "health-fitness": "icon_health.png",
    "entertainment": "icon_entertainment.png",
    "family": "icon_family.png",
    "gifts-donations": "icon_gift.png",
    "insurance": "icon_insurance.png",
    "borrowing": "icon_loan_in.png",
    "lending": "icon_loan_out.png",
    "debt-repayment": "icon_debt_repayment.png",
    "debt-collection": "icon_debt_collection.png",
    "phone-bill": "icon_phone_bill.png",
    "electricity-bill": "icon_electricity.png",
    "water-bill": "icon_water.png",
    "internet-bill": "icon_internet.png",
    "gas-bill": "icon_gas.png",
    "television-bill": "icon_tv.png",
    "bills-utilities": "icon_utilities.png",
    "other-utility-bills": "icon_other_bill.png",
    "rent": "icon_rent.png",
    "beauty": "icon_beauty.png",
    "sports": "icon_sport.png",
    "medical-checkup": "icon_medical.png",
    "personal-items": "icon_personal_item.png",
    "home-appliances": "icon_home_appliance.png",
    "pets": "icon_pets.png",
    "vehicle-maintenance": "icon_car_repair.png",
    "online-services": "icon_online_service.png",
    "home-services": "icon_home_service.png",
    "home-renovation": "icon_home_decor.png",
    "incoming-transfer": "icon_transfer_in.png",
    "outgoing-transfer": "icon_transfer_out.png",
    "interest-received": "icon_interest_receive.png",
    "interest-paid": "icon_interest_pay.png",
    "other-income": "icon_other_income.png",
    "other-expenses": "icon_other_expense.png",
    "travel-leisure": "icon_travel.png",

    // --- VIETNAMESE SLUGS (Hỗ trợ fallback) ---
    "an-uong": "icon_food.png",
    "di-chuyen": "icon_transport.png",
    "mua-sam": "icon_shopping.png",
    "luong": "icon_salary.png",
    "dau-tu": "icon_invest.png",
    "giao-duc": "icon_education.png",
    "suc-khoe": "icon_health.png",
    "giai-tri": "icon_entertainment.png",
    "gia-dinh": "icon_family.png",
    "qua-tang-quyen-gop": "icon_gift.png",
    "bao-hiem": "icon_insurance.png",
    "di-vay": "icon_loan_in.png",
    "cho-vay": "icon_loan_out.png",
    "tra-no": "icon_debt_repayment.png",
    "thu-no": "icon_debt_collection.png",
    "hoa-don-dien-thoai": "icon_phone_bill.png",
    "hoa-don-dien": "icon_electricity.png",
    "hoa-don-nuoc": "icon_water.png",
    "hoa-don-internet": "icon_internet.png",
    "hoa-don-gas": "icon_gas.png",
    "hoa-don-tv": "icon_tv.png",
    "hoa-don-tien-ich": "icon_utilities.png",
    "hoa-don-tien-ich-khac": "icon_other_bill.png",
    "thue-nha": "icon_rent.png",
    "lam-dep": "icon_beauty.png",
    "the-duc-the-thao": "icon_sport.png",
    "kham-suc-khoe": "icon_medical.png",
    "do-dung-ca-nhan": "icon_personal_item.png",
    "do-gia-dung": "icon_home_appliance.png",
    "vat-nuoi": "icon_pets.png",
    "bao-duong-xe": "icon_car_repair.png",
    "dich-vu-truc-tuyen": "icon_online_service.png",
    "dich-vu-gia-dinh": "icon_home_service.png",
    "sua-trang-tri-nha": "icon_home_decor.png",
    "tien-chuyen-den": "icon_transfer_in.png",
    "tien-chuyen-di": "icon_transfer_out.png",
    "thu-lai": "icon_interest_receive.png",
    "tra-lai": "icon_interest_pay.png",
    "thu-nhap-khac": "icon_other_income.png",
    "cac-chi-phi-khac": "icon_other_expense.png",
    "vui-choi": "icon_travel.png"
};

/**
 * Hàm lấy URL Icon đồng bộ với logic Flutter (IconHelper.buildCloudinaryUrl)
 */
export const getIconUrl = (identifier) => {
    if (!identifier) return null;

    // 1. Nếu đã là URL đầy đủ (startsWith 'http') -> giữ nguyên
    if (identifier.startsWith('http')) return identifier;

    let publicId;
    
    // 2. Nếu identifier chứa dấu chấm (e.g., 'icon_beauty.png', 'bill.png') -> dùng trực tiếp làm publicId
    if (identifier.includes('.')) {
        publicId = identifier;
    } else {
        // 3. Xử lý logic mapping tên tiếng Việt/Anh
        const slug = slugify(identifier);
        
        // Thử tìm trong mapping
        if (ICON_MAPPING[slug]) {
            publicId = ICON_MAPPING[slug];
        } else {
            // Fallback: icon_[slug].png (thay '-' bằng '_' để khớp với convention Cloudinary)
            const underscoreSlug = slug.replace(/-/g, '_');
            publicId = `icon_${underscoreSlug}.png`;
        }
    }

    // Nối với base URL (có transformations f_auto,q_auto)
    return `${CLOUDINARY_BASE}/${publicId}`;
};

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
    markAsRead: (id) => api.put(`/notifications/${id}/read`),
    markAllAsRead: () => api.put('/notifications/read-all'),
    delete: (id) => api.delete(`/notifications/${id}`),
};

export const utilApi = {
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
    getAllLiveOnlineUsers: () => api.get('/admin/users/online-live'),
    getSystemTransactionStats: (params) => api.get('/admin/system/transaction-stats', {
        params: cleanParams(params)
    }),
    handleAutoLogout: () => api.post('/admin/system/auto-logout'),
    getAdminNotifications: () => api.get('/admin/notifications'),
    markAdminAsRead: (id) => api.put(`/admin/notifications/${id}/read`),
    markAllAdminAsRead: () => api.put('/admin/notifications/read-all'),
    getAllContactRequests: (params) => api.get('/admin/contact-requests', { params: cleanParams(params) }),
    getContactRequestById: (id) => api.get(`/admin/contact-requests/${id}`),
    resolveContactRequest: (id, data) => api.patch(`/admin/contact-requests/${id}/resolve`, data),
};

export const iconApi = {
    getAll: () => api.get('/icons'),
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
    getSummaryReport: (params) => api.get('/transactions/report/summary', { params: cleanParams(params) }),
    getFinancialReport: (params) => api.get('/transactions/report/financial', { params: cleanParams(params) }),
    getTrend: (params) => api.get('/transactions/report/trend', { params: cleanParams(params) }), 
    getById: (id) => api.get(`/transactions/${id}`),
    create: (data) => api.post('/transactions', data),
    update: (id, data) => api.put(`/transactions/${id}`, data),
    delete: (id) => api.delete(`/transactions/${id}`),
    search: (request) => api.post('/transactions/search', request),
    getAll: (params) => api.get('/transactions', { params }),
};
