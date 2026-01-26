import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { authApi } from '../server/api';

const Register = () => {
    // Cập nhật các trường: email, password, phone theo RegisterRequest
    const [formData, setFormData] = useState({ email: '', password: '', phone: '' });
    const navigate = useNavigate();

    const handleRegister = async (e) => {
        e.preventDefault();
        try {
            await authApi.register(formData); //
            alert('Đăng ký thành công!');
            navigate('/login');
        } catch (err) {
            alert('Lỗi: Email hoặc số điện thoại đã được sử dụng.');
        }
    };

    return (
        <div className="container d-flex justify-content-center align-items-center vh-100">
            <div className="card shadow-lg p-4 border-0" style={{ width: '420px', borderRadius: '1rem' }}>
                <h3 className="text-center fw-bold mb-4">Tạo tài khoản</h3>
                <form onSubmit={handleRegister}>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Email</label>
                        <input type="email" className="form-control bg-light border-0" placeholder="example@mail.com" required
                               onChange={(e) => setFormData({...formData, email: e.target.value})} />
                    </div>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Số điện thoại</label>
                        <input type="text" className="form-control bg-light border-0" placeholder="0123 456 789" required
                               onChange={(e) => setFormData({...formData, phone: e.target.value})} />
                    </div>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Mật khẩu</label>
                        <input type="password" className="form-control bg-light border-0" placeholder="••••••••" required
                               onChange={(e) => setFormData({...formData, password: e.target.value})} />
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