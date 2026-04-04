import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { authApi } from '../server/api';

const Login = () => {
    const [formData, setFormData] = useState({
        username: 'admin@smartmoney.vn',
        password: 'Test@123',
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
        <div className="container-fluid d-flex justify-content-center align-items-center vh-100" 
             style={{ 
                 background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                 fontFamily: "'Inter', sans-serif" 
             }}>
            <style>{`
                .login-card {
                    background: rgba(255, 255, 255, 0.95);
                    backdrop-filter: blur(10px);
                    border-radius: 24px;
                    border: 1px solid rgba(255, 255, 255, 0.3);
                    transition: transform 0.3s ease;
                }
                .form-control {
                    border-radius: 12px;
                    padding: 12px 15px 12px 45px;
                    border: 1px solid #e2e8f0;
                    background-color: #f8fafc;
                }
                .form-control:focus {
                    box-shadow: 0 0 0 4px rgba(102, 126, 234, 0.1);
                    border-color: #667eea;
                }
                .input-group-icon {
                    position: absolute;
                    left: 15px;
                    top: 50%;
                    transform: translateY(-50%);
                    z-index: 10;
                    color: #94a3b8;
                }
                .btn-login {
                    border-radius: 12px;
                    padding: 12px;
                    background: linear-gradient(to right, #667eea, #764ba2);
                    border: none;
                    letter-spacing: 1px;
                    transition: all 0.3s ease;
                }
                .btn-login:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 10px 20px rgba(0,0,0,0.15);
                }
            `}</style>

            <div className="card login-card shadow-lg p-4 p-md-5" style={{ width: '100%', maxWidth: '420px' }}>
                <div className="text-center mb-4">
                    <div className="d-inline-block p-3 rounded-circle bg-primary bg-opacity-10 mb-3">
                        <i className="bi bi-wallet2 fs-1 text-primary"></i>
                    </div>
                    <h3 className="fw-bold text-dark">SmartMoney</h3>
                    <p className="text-muted small">Quản lý tài chính thông minh & hiệu quả</p>
                </div>

                {generalError && <div className="alert alert-danger border-0 small text-center py-2 rounded-3 mb-3">{generalError}</div>}

                <form onSubmit={handleSubmit}>
                    <div className="mb-3 position-relative">
                        <i className="bi bi-person input-group-icon"></i>
                        <input
                            type="text"
                            className={`form-control ${errors.username ? 'is-invalid' : ''}`}
                            value={formData.username}
                            onChange={(e) => { setFormData({...formData, username: e.target.value}); if (errors.username) setErrors({...errors, username: ''}); }}
                            placeholder="Email hoặc số điện thoại"
                        />
                        {errors.username && <div className="invalid-feedback">{errors.username}</div>}
                    </div>
                    <div className="mb-4 position-relative">
                        <i className="bi bi-lock input-group-icon"></i>
                        <input
                            type="password"
                            className={`form-control ${errors.password ? 'is-invalid' : ''}`}
                            value={formData.password}
                            onChange={(e) => { setFormData({...formData, password: e.target.value}); if (errors.password) setErrors({...errors, password: ''}); }}
                            placeholder="Mật khẩu"
                        />
                        {errors.password && <div className="invalid-feedback">{errors.password}</div>}
                    </div>
                    
                    <button type="submit" className="btn btn-primary btn-login w-100 fw-bold text-white shadow-sm" disabled={isLoading}>
                        {isLoading ? <span><span className="spinner-border spinner-border-sm me-2"></span>Xử lý...</span> : "ĐĂNG NHẬP"}
                    </button>
                    
                    <div className="text-center mt-4">
                        <Link to="/forgot-password" className="text-decoration-none small">Quên mật khẩu?</Link>
                    </div>
                    <div className="text-center mt-2 small">
                        <span className="text-muted">Chưa có tài khoản?</span>{" "}
                        <Link to="/register" className="text-decoration-none fw-bold text-primary">Đăng ký ngay</Link>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default Login;