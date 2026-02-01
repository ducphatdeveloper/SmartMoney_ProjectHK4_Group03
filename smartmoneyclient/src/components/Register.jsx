import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { authApi } from '../server/api';

const Register = () => {
    const [formData, setFormData] = useState({
        accEmail: '',       // Khớp accEmail trong Java
        accPhone: '',       // Khớp accPhone trong Java
        password: '',       // Khớp password trong Java
        confirmPassword: '' // Khớp confirmPassword trong Java
    });
    const [error, setError] = useState('');
    const navigate = useNavigate();

    const handleRegister = async (e) => {
        e.preventDefault();

        // Kiểm tra sơ bộ phía client trước khi gửi request
        if (formData.password !== formData.confirmPassword) {
            setError('Mật khẩu xác nhận không khớp');
            return;
        }

        try {
            await authApi.register(formData);
            alert('Đăng ký thành công!');
            navigate('/login');
        } catch (err) {
            // Hiển thị lỗi từ backend (nếu có)
            const errMsg = err.response?.data?.message || 'Lỗi: Email hoặc số điện thoại đã tồn tại.';
            setError(errMsg);
        }
    };

    return (
        <div className="container d-flex justify-content-center align-items-center vh-100">
            <div className="card shadow-lg p-4 border-0" style={{ width: '420px', borderRadius: '1rem' }}>
                <h3 className="text-center fw-bold mb-4">Tạo tài khoản</h3>
                {error && <div className="alert alert-danger py-2 small text-center">{error}</div>}

                <form onSubmit={handleRegister}>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Email</label>
                        <input
                            type="email"
                            className="form-control bg-light border-0"
                            placeholder="example@mail.com"
                            onChange={(e) => setFormData({...formData, accEmail: e.target.value})}
                        />
                    </div>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Số điện thoại</label>
                        <input
                            type="text"
                            className="form-control bg-light border-0"
                            placeholder="0123456789"
                            onChange={(e) => setFormData({...formData, accPhone: e.target.value})}
                        />
                    </div>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Mật khẩu</label>
                        <input
                            type="password"
                            className="form-control bg-light border-0"
                            placeholder="••••••••"
                            required
                            onChange={(e) => setFormData({...formData, password: e.target.value})}
                        />
                    </div>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Xác nhận mật khẩu</label>
                        <input
                            type="password"
                            className="form-control bg-light border-0"
                            placeholder="••••••••"
                            required
                            onChange={(e) => setFormData({...formData, confirmPassword: e.target.value})}
                        />
                    </div>
                    <button type="submit" className="btn btn-success w-100 py-2 fw-bold shadow-sm mt-2">ĐĂNG KÝ</button>
                    <div className="text-center mt-3 small">
                        Đã có tài khoản? <Link to="/login" className="text-decoration-none fw-bold">Đăng nhập</Link>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default Register;