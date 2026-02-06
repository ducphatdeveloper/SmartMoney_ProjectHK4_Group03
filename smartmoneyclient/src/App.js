import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import 'bootstrap/dist/css/bootstrap.min.css';

import Login from './components/Login';
import Register from './components/Register';
import AdminDashboard from './components/AdminDashboard';
import DashBoard from  './components/Dashboard';

// Thành phần bảo vệ Route cho Admin
const AdminRoute = ({ children }) => {
    const user = JSON.parse(localStorage.getItem('user'));
    const token = localStorage.getItem('accessToken');

    const authorizedRoles = ["Quản trị viên", "ROLE_ADMIN", "ADMIN_SYSTEM_ALL"];
    const isAdmin = token && authorizedRoles.includes(user?.roleName);


    if (isAdmin) return children;
    return <Navigate to="/login" replace />;
};

function App() {
    return (
        <Router>
            <div className="App">
                <Routes>
                    <Route path="/login" element={<Login />} />
                    <Route path="/register" element={<Register />} />
                    <Route path="/dashboard" element={<DashBoard />} />


                    {/* Bảo vệ khu vực Admin 🔐 */}
                    <Route
                        path="/admin/*"
                        element={
                            <AdminRoute>
                                <AdminDashboard />
                            </AdminRoute>
                        }
                    />

                    <Route path="/" element={<Navigate to="/login" />} />
                    <Route path="*" element={<Navigate to="/login" />} />
                </Routes>
            </div>
        </Router>
    );
}

export default App;