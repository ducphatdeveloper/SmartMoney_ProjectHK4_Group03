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
            newErrors.identity = "Please provide at least Phone number or Email";
        }

        // 2. Validate Phone Regex (Nếu có nhập)
        // ^(0\d{9,10})?$ : Bắt đầu bằng 0, theo sau là 9-10 chữ số
        if (accPhone && !/^(0\d{9,10})?$/.test(accPhone)) {
            newErrors.accPhone = "Phone number must start with 0 and have 10-11 digits";
        }

        // 3. Validate Email (Nếu có nhập)
        if (accEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(accEmail)) {
            newErrors.accEmail = "Invalid email address";
        }

        // 4. Validate Password Length (6-50 chars)
        if (!password || password.length < 6 || password.length > 50) {
            newErrors.password = "Password must be between 6 and 50 characters;"
        }

        // 5. Validate Confirm Password
        if (password !== confirmPassword) {
            newErrors.confirmPassword = "Passwords do not match";
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
            alert("Registration successful! Please log in.");
            navigate('/login');
        } catch (err) {
            setGeneralError(err.response?.data?.message || 'Registration failed. Please try again.');
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
        <div className="container-fluid d-flex justify-content-center align-items-center vh-100" 
             style={{ 
                 background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                 fontFamily: "'Inter', sans-serif" 
             }}>
            <style>{`
                .register-card {
                    background: rgba(255, 255, 255, 0.95);
                    backdrop-filter: blur(10px);
                    border-radius: 24px;
                    border: 1px solid rgba(255, 255, 255, 0.3);
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
                .btn-register {
                    border-radius: 12px;
                    padding: 12px;
                    background: linear-gradient(to right, #667eea, #764ba2);
                    border: none;
                    letter-spacing: 1px;
                    transition: all 0.3s ease;
                }
                .btn-register:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 10px 20px rgba(0,0,0,0.15);
                }
            `}</style>

            <div className="card register-card shadow-lg p-4 p-md-5" style={{ width: '100%', maxWidth: '480px' }}>
                <div className="text-center mb-4">
                    <div className="d-inline-block p-3 rounded-circle bg-primary bg-opacity-10 mb-3">
                        <i className="bi bi-person-plus fs-1 text-primary"></i>
                    </div>
                    <h3 className="fw-bold text-dark">Create account</h3>
                    <p className="text-muted small">Start managing your finances smartly with SmartMoney</p>
                </div>

                {generalError && <div className="alert alert-danger border-0 small text-center py-2 rounded-3 mb-3">{generalError}</div>}
                {errors.identity && (
                    <div className="alert alert-warning border-0 small text-center py-2 rounded-3 mb-3">
                        <i className="bi bi-exclamation-triangle me-2"></i>{errors.identity}
                    </div>
                )}

                <form onSubmit={handleSubmit}>
                    <div className="mb-3 position-relative">
                        <i className="bi bi-telephone input-group-icon"></i>
                        <input type="text" name="accPhone" 
                            className={`form-control ${errors.accPhone ? 'is-invalid' : ''}`} 
                            value={formData.accPhone} onChange={handleChange} placeholder="Phone number" />
                        {errors.accPhone && <div className="invalid-feedback">{errors.accPhone}</div>}
                    </div>

                    <div className="mb-3 position-relative">
                        <i className="bi bi-envelope input-group-icon"></i>
                        <input type="email" name="accEmail" 
                            className={`form-control ${errors.accEmail ? 'is-invalid' : ''}`} 
                            value={formData.accEmail} onChange={handleChange} placeholder="Email address" />
                        {errors.accEmail && <div className="invalid-feedback">{errors.accEmail}</div>}
                    </div>

                    <div className="mb-3 position-relative">
                        <i className="bi bi-lock input-group-icon"></i>
                        <input type="password" name="password" 
                            className={`form-control ${errors.password ? 'is-invalid' : ''}`} 
                            value={formData.password} onChange={handleChange} placeholder="Password (minimum 6 characters)" />
                        {errors.password && <div className="invalid-feedback">{errors.password}</div>}
                    </div>

                    <div className="mb-4 position-relative">
                        <i className="bi bi-shield-check input-group-icon"></i>
                        <input type="password" name="confirmPassword" 
                            className={`form-control ${errors.confirmPassword ? 'is-invalid' : ''}`} 
                            value={formData.confirmPassword} onChange={handleChange} placeholder="Confirm password" />
                        {errors.confirmPassword && <div className="invalid-feedback">{errors.confirmPassword}</div>}
                    </div>

                    <button type="submit" className="btn btn-primary btn-register w-100 fw-bold text-white shadow-sm" disabled={isLoading}>
                        {isLoading ? <span><span className="spinner-border spinner-border-sm me-2"></span>Processing...</span> : "SIGN UP NOW"}
                    </button>
                    
                    <div className="text-center mt-4 small">
                        <span className="text-muted">Already have an account?</span>{" "}
                        <Link to="/login" className="text-decoration-none fw-bold text-primary">Log in now</Link>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default Register;