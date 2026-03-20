import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { authApi } from '../server/api';

const ForgotPassword = () => {
    const [email, setEmail] = useState('');
    const [message, setMessage] = useState('');
    const [error, setError] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const navigate = useNavigate();

    const handleSubmit = async (e) => {
        e.preventDefault();
        setMessage('');
        setError('');

        if (!email) {
            setError('Vui lòng nhập email');
            return;
        }

        setIsLoading(true);
        try {
            await authApi.forgotPassword({ email });
            setMessage('Mã xác thực đã được gửi đến email của bạn.');
            // Chuyển hướng sang trang ResetPassword sau 2 giây
            setTimeout(() => {
                navigate('/reset-password', { state: { email } });
            }, 2000);
        } catch (err) {
            setError(err.response?.data?.message || 'Có lỗi xảy ra. Vui lòng thử lại.');
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="container d-flex justify-content-center align-items-center vh-100">
            <div className="card shadow-lg p-4 border-0" style={{ width: '400px', borderRadius: '1rem' }}>
                <h4 className="fw-bold text-center mb-4">Quên Mật Khẩu</h4>

                {message && <div className="alert alert-success small text-center">{message}</div>}
                {error && <div className="alert alert-danger small text-center">{error}</div>}

                <form onSubmit={handleSubmit}>
                    <div className="mb-3">
                        <label className="form-label small fw-bold">Email</label>
                        <input
                            type="email"
                            className="form-control"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            placeholder="Nhập email của bạn"
                        />
                    </div>

                    <button type="submit" className="btn btn-primary w-100 py-2 fw-bold" disabled={isLoading}>
                        {isLoading ? (
                            <span><span className="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>Đang xử lý...</span>
                        ) : (
                            "GỬI MÃ XÁC THỰC"
                        )}
                    </button>

                    <div className="text-center mt-3 small">
                        <Link to="/login" className="text-decoration-none">Quay lại đăng nhập</Link>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default ForgotPassword;