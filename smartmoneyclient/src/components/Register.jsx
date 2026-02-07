import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { authApi } from '../server/api';

const Register = () => {
    const [formData, setFormData] = useState({
        accPhone: '',
        accEmail: '',
        password: '',
        confirmPassword: ''
    });

    const [errors, setErrors] = useState({});
    const [generalError, setGeneralError] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const navigate = useNavigate();

    const validate = () => {
        const newErrors = {};
        const { accPhone, accEmail, password, confirmPassword } = formData;

        // 1. Validate Identity (Phải có ít nhất Phone hoặc Email)
        if (!accPhone?.trim() && !accEmail?.trim()) {
            newErrors.identity = "Vui lòng cung cấp ít nhất Số điện thoại hoặc Email";
        }

        // 2. Validate Phone Regex (Nếu có nhập)
        // ^(0\d{9,10})?$ : Bắt đầu bằng 0, theo sau là 9-10 chữ số
        if (accPhone && !/^(0\d{9,10})?$/.test(accPhone)) {
            newErrors.accPhone = "Số điện thoại phải bắt đầu bằng 0 và có 10-11 chữ số";
        }

        // 3. Validate Email (Nếu có nhập)
        if (accEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(accEmail)) {
            newErrors.accEmail = "Địa chỉ Email không hợp lệ";
        }

        // 4. Validate Password Length (6-50 chars)
        if (!password || password.length < 6 || password.length > 50) {
            newErrors.password = "Mật khẩu phải từ 6 đến 50 ký tự";
        }

        // 5. Validate Confirm Password
        if (password !== confirmPassword) {
            newErrors.confirmPassword = "Mật khẩu xác nhận không khớp";
        }

        return newErrors;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setErrors({});
        setGeneralError('');

        const validationErrors = validate();
        if (Object.keys(validationErrors).length > 0) {
            setErrors(validationErrors);
            return;
        }

        setIsLoading(true);
        try {
            await authApi.register(formData);
            alert("Đăng ký thành công! Vui lòng đăng nhập.");
            navigate('/login');
        } catch (err) {
            setGeneralError(err.response?.data?.message || 'Đăng ký thất bại. Vui lòng thử lại.');
        } finally {
            setIsLoading(false);
        }
    };

    const handleChange = (e) => {
        const { name, value } = e.target;
        setFormData({ ...formData, [name]: value });
        // Xóa lỗi của trường đang nhập
        if (errors[name]) {
            setErrors({ ...errors, [name]: '' });
        }
        // Xóa lỗi identity nếu người dùng bắt đầu nhập phone hoặc email
        if ((name === 'accPhone' || name === 'accEmail') && errors.identity) {
            setErrors({ ...errors, identity: '' });
        }
    };

    return (
        <div className="container d-flex justify-content-center align-items-center vh-100">
            <div className="card shadow-lg p-4 border-0" style={{ width: '450px', borderRadius: '1rem' }}>
                <h3 className="text-center fw-bold mb-4">Đăng Ký Tài Khoản 📝</h3>
                
                {generalError && <div className="alert alert-danger text-center py-2 small">{generalError}</div>}
                {errors.identity && <div className="alert alert-warning text-center py-2 small"><i className="bi bi-exclamation-triangle me-2"></i>{errors.identity}</div>}

                <form onSubmit={handleSubmit}>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Số điện thoại</label>
                        <input type="text" name="accPhone" className={`form-control ${errors.accPhone ? 'is-invalid' : ''}`} 
                            value={formData.accPhone} onChange={handleChange} placeholder="0xxxxxxxxx" />
                        {errors.accPhone && <div className="invalid-feedback">{errors.accPhone}</div>}
                    </div>

                    <div className="mb-3">
                        <label className="form-label small fw-bold">Email</label>
                        <input type="email" name="accEmail" className={`form-control ${errors.accEmail ? 'is-invalid' : ''}`} 
                            value={formData.accEmail} onChange={handleChange} placeholder="example@mail.com" />
                        {errors.accEmail && <div className="invalid-feedback">{errors.accEmail}</div>}
                    </div>

                    <div className="mb-3">
                        <label className="form-label small fw-bold">Mật khẩu</label>
                        <input type="password" name="password" className={`form-control ${errors.password ? 'is-invalid' : ''}`} 
                            value={formData.password} onChange={handleChange} placeholder="Tối thiểu 6 ký tự" />
                        {errors.password && <div className="invalid-feedback">{errors.password}</div>}
                    </div>

                    <div className="mb-3">
                        <label className="form-label small fw-bold">Xác nhận mật khẩu</label>
                        <input type="password" name="confirmPassword" className={`form-control ${errors.confirmPassword ? 'is-invalid' : ''}`} 
                            value={formData.confirmPassword} onChange={handleChange} placeholder="Nhập lại mật khẩu" />
                        {errors.confirmPassword && <div className="invalid-feedback">{errors.confirmPassword}</div>}
                    </div>

                    <button type="submit" className="btn btn-success w-100 py-2 fw-bold" disabled={isLoading}>
                        {isLoading ? "Đang xử lý..." : "ĐĂNG KÝ"}
                    </button>
                    
                    <div className="text-center mt-4 small">
                        Đã có tài khoản? <Link to="/login" className="text-decoration-none fw-bold">Đăng nhập ngay</Link>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default Register;