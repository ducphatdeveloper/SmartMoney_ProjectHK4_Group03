import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { authApi } from '../server/api';

const Login = () => {
    const [formData, setFormData] = useState({
        username: '',
        password: '',
        deviceToken: 'web-browser', 
        deviceType: 'WEB',
        deviceName: 'Web Browser',
        ipAddress: '' 
    });

    // Hàm tự động nhận diện thiết bị và lấy IP
    useEffect(() => {
        const getClientSpecs = async () => {
            const ua = navigator.userAgent;
            let detectedName = "Web Browser";
            let detectedType = "WEB";

            // 1. Nhận diện Device Name & Type cơ bản từ User Agent
            if (/Windows/.test(ua)) detectedName = "Windows PC";
            else if (/Macintosh/.test(ua)) detectedName = "MacBook/iMac";
            else if (/iPhone/.test(ua)) { detectedName = "iPhone"; detectedType = "iOS"; }
            else if (/Android/.test(ua)) { detectedName = "Android Device"; detectedType = "Android"; }
            else if (/Linux/.test(ua)) detectedName = "Linux PC";

            // 2. Lấy Public IP Address thiết bị của người dùng
            try {
                const response = await fetch('https://api.ipify.org?format=json');
                const data = await response.json();
                
                setFormData(prev => ({
                    ...prev,
                    deviceType: detectedType,
                    deviceName: detectedName,
                    ipAddress: data.ip
                }));
            } catch (error) {
                console.error("Lấy Public IP Address thất bại:", error);
                // Fallback về địa chỉ IP mặc định nếu dịch vụ không khả dụng
                setFormData(prev => ({
                    ...prev,
                    deviceType: detectedType,
                    deviceName: detectedName,
                    ipAddress: "127.0.0.1"
                }));
            }
        };

        getClientSpecs();
    }, []);

    const [errors, setErrors] = useState({}); // Object chứa lỗi từng trường
    const [generalError, setGeneralError] = useState(''); // Lỗi chung (VD: Sai pass, lỗi mạng)
    const [isLoading, setIsLoading] = useState(false); // Trạng thái loading

    const navigate = useNavigate();

    const validate = () => {
        const newErrors = {};
        if (!formData.username.trim()) {
            newErrors.username = 'Vui lòng nhập Email hoặc Số điện thoại';
        }
        if (!formData.password) {
            newErrors.password = 'Vui lòng nhập mật khẩu';
        }
        return newErrors;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setGeneralError('');
        setErrors({});

        const validationErrors = validate();
        if (Object.keys(validationErrors).length > 0) {
            setErrors(validationErrors);
            return;
        }

        setIsLoading(true);
        try {
            const response = await authApi.login(formData);
            const serverData = response.data.data;

            if (serverData && serverData.accessToken) {
                localStorage.setItem('accessToken', serverData.accessToken);

                // Cập nhật cách lưu userData 💾
                // Vì server trả về roleId là "Quản trị viên" = 1, ta sẽ dùng chính nó để kiểm tra
                const userData = {
                    userId: serverData.userId,
                    accEmail: serverData.accEmail,
                    roleName: serverData.roleName, // Lưu lại giá trị tên role
                    roleId: serverData.roleId, // Lưu lại giá trị id là khóa chính của role
                };
                localStorage.setItem('user', JSON.stringify(userData));
                console.log("Role ID hiện tại:", serverData.roleId)

                // Các vai trò được phép truy cập trang admin
                const authorizedRoles = ["Quản trị viên", "ROLE_ADMIN", "ADMIN_SYSTEM_ALL"];

                // Kiểm tra điều kiện điều hướng ngay tại đây
                if (authorizedRoles.includes(serverData.roleName)) {
                    navigate('/admin');
                } else {
                    navigate('/dashboard');
                }
            }
        } catch (err) {
            // Lấy message lỗi từ server nếu có
            const message = err.response?.data?.message || 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.';
            setGeneralError(message);
        } finally {
            setIsLoading(false);
        }
    };
    return (
        <div className="container d-flex justify-content-center align-items-center vh-100">
            <div className="card shadow-lg p-4 border-0" style={{ width: '400px', borderRadius: '1rem' }}>
                <span className="navbar-brand fw-bold text-center">
                    <i className="bi bi-wallet2 me-2"></i>SmartMoney
                </span>

                {/* Hiển thị lỗi chung từ server */}
                {generalError && <div className="alert alert-danger py-2 small text-center">{generalError}</div>}

                <form onSubmit={handleSubmit}>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Email hoặc Số điện thoại</label>
                        <input
                            type="text"
                            className={`form-control ${errors.username ? 'is-invalid' : ''}`}
                            value={formData.username}
                            onChange={(e) => {
                                setFormData({...formData, username: e.target.value});
                                if (errors.username) setErrors({...errors, username: ''}); // Xóa lỗi khi gõ
                            }}
                            placeholder="Nhập email hoặc số điện thoại"
                        />
                        {errors.username && <div className="invalid-feedback">{errors.username}</div>}
                    </div>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Mật khẩu</label>
                        <input
                            type="password"
                            className={`form-control ${errors.password ? 'is-invalid' : ''}`}
                            value={formData.password}
                            onChange={(e) => {
                                setFormData({...formData, password: e.target.value});
                                if (errors.password) setErrors({...errors, password: ''});
                            }}
                            placeholder="Nhập mật khẩu"
                        />
                        {errors.password && <div className="invalid-feedback">{errors.password}</div>}
                    </div>
                    
                    <button type="submit" className="btn btn-primary w-100 py-2 fw-bold" disabled={isLoading}>
                        {isLoading ? (
                            <span><span className="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>Đang xử lý...</span>
                        ) : (
                            "ĐĂNG NHẬP"
                        )}
                    </button>
                    
                    <div className="text-center mt-3">
                        <Link to="/forgot-password" className="text-decoration-none small">Quên mật khẩu?</Link>
                    </div>

                    <div className="text-center mt-2 small">
                        Chưa có tài khoản? <Link to="/register" className="text-decoration-none fw-bold">Đăng ký ngay</Link>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default Login;