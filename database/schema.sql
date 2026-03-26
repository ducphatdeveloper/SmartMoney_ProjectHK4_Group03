-- ================================================================================================================================
-- DATABASE: SmartMoney
-- AUTHOR DATABASE: Phạm Đức Phát 
-- CREATED: 2026 
-- VERSION: 1.0 (Standardized)
-- DESCRIPTION: Quản lý tài chính cá nhân với AI Assistant - Thu/Chi/Ngân sách/Sổ Nợ/Tiết kiệm/Hóa Đơn/Giao dịch định kỳ/Sự kiện
-- =================================================================================================================================
-- =======================================================================================================
-- DỰ ÁN: SMARTMONEY - QUY TẮC PHÁT TRIỂN & TỪ ĐIỂN KỸ THUẬT
-- VERSION: 1.0 | TEAM: Phát - Nhật - Nam | THỜI GIAN: 4 Tuần
-- VERSION: 1.1 Có dữ liệu mẫu
-- =======================================================================================================
-- 📌 LƯU Ý: Đây là guideline tham khảo để nhóm dễ research, không bắt buộc áp dụng 100%

-- 1. QUY CHUẨN KIỂU DỮ LIỆU
--    Tiền tệ: DECIMAL(18,2)    | Ngày: DATE       | Time: DATETIME
--    Status: BIT/TINYINT        | ID: INT IDENTITY | Password: VARCHAR(255) (Bcrypt)

-- 2. QUY TẮC ĐẶT TÊN
--    Table: tTableName     | View: vViewName     | Index: idx_Table_Columns
--    Trigger: trg_Table_Action | FK: FK_Child_Parent | Constraint: CHK_Table_Field

-- 3. BẢO MẬT & QUYỀN TRUY CẬP (BẮT BUỘC)
--    □ Mọi query phải có WHERE acc_id = ? (Row-level security)
--    □ Hash password: Bcrypt cost 12 | JWT: 15 phút + Refresh 7 ngày
--    □ Admin: Chỉ Lock/Unlock account, không xóa Account/Role/Currency

-- 4. QUAN HỆ DATABASE
--    ┌────────────┬─────────────────┬───────────────────────────────────┐
--    │ LOẠI       │ VÍ DỤ           │ CÁCH NHẬN BIẾT                   │
--    ├────────────┼─────────────────┼───────────────────────────────────┤
--    │ 1-1        │ Chat ↔ Hóa đơn  │ PK = FK (tReceipts.id = tAIConv.id)│
--    │ 1-N        │ User → Wallets  │ FK từ con trỏ về cha              │
--    │ N-N        │ Roles ↔ Perms   │ Bảng trung gian (2 FK)            │
--    │ SELF-REF   │ Categories      │ parent_id → id (cùng bảng)        │
--    └────────────┴─────────────────┴───────────────────────────────────┘

-- 5. THUẬT NGỮ KỸ THUẬT
--    ┌─────────────────┬─────────────────────────────────────────────┐
--    │ THUẬT NGỮ      │ Ý NGHĨA & VÍ DỤ                            │
--    ├─────────────────┼─────────────────────────────────────────────┤
--    │ CONSTANTS      │ Giá trị cố định DB (CHECK constraint)       │
--    │                 │ VD: CHECK (source_type BETWEEN 1 AND 5)    │
--    ├─────────────────┼─────────────────────────────────────────────┤
--    │ ENUM (Java)    │ Hằng số Backend (package: com.smartmoney.enum)│
--    │                 │ VD: TransactionType.INCOME (DB value = 1)  │
--    ├─────────────────┼─────────────────────────────────────────────┤
--    │ BITMASK        │ Lưu nhiều option vào 1 INT (lũy thừa 2)     │
--    │                 │ VD: T2=1,T3=2,T4=4 → T2+T4 = 5 (1+4)       │
--    ├─────────────────┼─────────────────────────────────────────────┤
--    ├─────────────────┼─────────────────────────────────────────────┤
--    │ DTO            │ Data Transfer Object - Chỉ trả data cần    │
--    │                 │ VD: TransactionDTO (không trả Entity JPA)  │
--    └─────────────────┴─────────────────────────────────────────────┘

-- 6. QUY TẮC XỬ LÝ ĐẶC BIỆT
--    □ Xóa danh mục: Chuyển transaction sang danh mục khác hoặc xóa
--    □ Số dư âm: Cho phép (hiển thị màu đỏ + cảnh báo)

-- 7. TRIGGER - TỰ ĐỘNG HÓA
--    □ Tự cộng/trừ số dư ví khi có giao dịch mới/xóa
--    □ Tự cập nhật updated_at khi record thay đổi
--    □ Tự update current_amount của SavingGoals
--    -- Lưu ý: Trigger đơn giản, logic phức tạp xử lý ở Backend

-- 8. INDEX TỐI ƯU HIỆU NĂNG
--    □ Luôn có acc_id đầu trong composite index
--    □ Dùng INCLUDE cho column thường SELECT
--    VD: CREATE INDEX idx_trans_active ON tTransactions(acc_id, deleted) 
--        INCLUDE (amount, trans_date)

-- 9. QUY TRÌNH PHÁT TRIỂN
--    1. Đọc business rules (mục 3,6) trước khi code
--    2. Check constants/enum trong DB và Java
--    3. Mọi API phải validate acc_id của user đang login
--    4. Test với ít nhất 2 user (đảm bảo data isolation)

-- 10. COMMON MISTAKES CẦN TRÁNH
--     ❌ SELECT * (dùng column cụ thể)  ❌ N+1 query (dùng JOIN FETCH)
--     ❌ Hardcode số (dùng constant)    ❌ Không validate ownership
--     ❌ Gửi raw Entity ra API (dùng DTO) ❌ Quên WHERE acc_id = ?

-- 11. AI INTEGRATION NOTES
--     □ Chat Intent: 1=add_trans, 2=report, 3=budget, 4=chat, 5=remind
--     □ OCR Receipt: Google Vision API (free tier)
--     □ Voice: Google Speech-to-Text
--     □ AI Model: Ưu tiên Gemini API (free), backup OpenAI

-- 12. SECURITY CHECKLIST
--     □ Password hash với Bcrypt (cost 12) □ JWT expiration hợp lý
--     □ Input validation (SQL injection)   □ Rate limiting API login
--     □ HTTPS only                         □ CORS configuration

-- =======================================================================================================
-- 🎯 PHÂN CÔNG MODULE & TRÁCH NHIỆM
-- =======================================================================================================
-- MODULE 1: WEB/AUTH (Nam phụ trách)
--   Bảng: tAccounts, tRoles, tPermissions, tRolePermissions, tUserDevices, tNotifications
--   Nhiệm vụ:
--     - JWT Authentication & Spring Security
--     - Dashboard / Admin Frontend với biểu đồ thống kê
--     - Hệ thống nhận thông báo (tNotifications) trên thiết bị đã login lưu token của thiết bị pc, laptop, đt
--     - Quản lý đa thiết bị đăng nhập (tUserDevices)
--     - Frontend Admin Dashboard (React)
-- 
-- MODULE 2: BASIC CRUD (Nhật phụ trách)
--   Bảng: tWallets, tSavingGoals, tEvents, tBudgets, tBudgetCategories, tCurrencies
--   Nhiệm vụ:
--     - CRUDS cơ bản cho các bảng trên ( cả tWallet và tSavingGoals thực chất cũng là ví nhưng mục đích sử dụng khác nhau )
--     - Cung cấp API để Module 3 có cơ sở xử lý backend phần giao dịch
--     - Frontend EndUser cơ bản (React)
-- 
-- MODULE 3: TRANSACTION CORE (Phát - Leader phụ trách)
--   Bảng: tTransactions, tPlannedTransactions, tCategories, tDebts
--   Nhiệm vụ:
--     - Thiết kế database & Quản lý tổng thể
--     - Viết tài liệu dự án & Hướng dẫn nhóm
--     - Xử lý logic giao dịch phức tạp (thu/chi, định kỳ, nợ)
--     - Quản lý danh mục (tCategories) - cả system và user
-- 
-- MODULE 4: APP CLIENT (Cả nhóm cùng làm SAU KHI hoàn thành 3 module trên)
--   Nhiệm vụ:
--     - Ứng dụng di động
--     - Mobile UI/UX, Push Notifications
-- 
-- MODULE 5: AI INTEGRATION (Cả nhóm cùng làm SAU KHI hoàn thành 3 module trên)
--   Bảng: tAIConversations, tReceipts
--   Nhiệm vụ:
--     - AI Chat (text/voice)
--     - OCR xử lý hóa đơn
--     - Voice Processing
------------------------------------------------------------------------------------------
-- =======================================================================================================
-- 📌 LƯU Ý: Đây là guideline tham khảo, không bắt buộc áp dụng 100%
-- 📌 LƯU Ý: Nếu viết view, trigger, mọi chỉnh sửa vào database phải thông báo trước cho nhóm không tự ý thay đổi.
-- =======================================================================================================
GO

USE master;
GO

-- Xóa database cũ nếu tồn tại
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'SmartMoney')
BEGIN
    ALTER DATABASE SmartMoney SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SmartMoney;
END
GO
-- TẠO DATABASE
CREATE DATABASE SmartMoney;
GO
USE SmartMoney
GO

-- ======================================================================
-- XÓA BẢNG THEO THỨ TỰ NGƯỢC (CON TRƯỚC, CHA SAU)
-- ======================================================================
DROP TABLE IF EXISTS tBudgetCategories;        -- [1]  Bảng trung gian (N-N) giữa tBudgets và tCategories
DROP TABLE IF EXISTS tPlannedTransactions;     -- [2]  Con của tAccounts(1-N) + tWallets(1-N) + tCategories(1-N)
DROP TABLE IF EXISTS tTransactions;            -- [3]  Con của tAccounts(1-N) + tWallets(1-N) + tCategories(1-N)
DROP TABLE IF EXISTS tReceipts;                -- [4]  Con của tAIConversations (quan hệ 1-1: PK = FK)
DROP TABLE IF EXISTS tAIConversations;         -- [5]  Con của tAccounts (1-N)
DROP TABLE IF EXISTS tNotifications;           -- [6]  Con của tAccounts (1-N)
DROP TABLE IF EXISTS tDebts;                   -- [7]  Con của tAccounts (1-N)
DROP TABLE IF EXISTS tBudgets;                 -- [8]  Con của tAccounts(1-N) + tWallets(1-N)
DROP TABLE IF EXISTS tSavingGoals;             -- [9]  Con của tAccounts (1-N)
DROP TABLE IF EXISTS tEvents;                  -- [10] Con của tAccounts (1-N)
DROP TABLE IF EXISTS tWallets;                 -- [11] Con của tAccounts(1-N) + tCurrencies(1-N)
DROP TABLE IF EXISTS tCategories;              -- [12] Con của tAccounts(1-N) + Tự tham chiếu chính nó
DROP TABLE IF EXISTS tUserDevices;             -- [13] Con của tAccounts (1-N)
DROP TABLE IF EXISTS tAccounts;                -- [14] Cha chính - Con của tRoles(1-N) và tCurrencies(1-N)
DROP TABLE IF EXISTS tRolePermissions;         -- [15] Bảng trung gian (N-N) giữa tRoles và tPermissions
DROP TABLE IF EXISTS tRoles;                   -- [16] Master data - Không phụ thuộc bảng nào
DROP TABLE IF EXISTS tPermissions;             -- [17] Master data - Không phụ thuộc bảng nào
DROP TABLE IF EXISTS tCurrencies;              -- [18] Master data - Xóa cuối cùng
GO
-- ======================================================================
-- 1. BẢNG QUYỀN HỆ THỐNG
-- ======================================================================
CREATE TABLE tPermissions(
    -- PRIMARY KEY
	id INT PRIMARY KEY IDENTITY(1,1),

    -- DATA COLUMNS
	per_code VARCHAR(50) UNIQUE NOT NULL,   -- Mã quyền động từ (VD: "USER_STANDARD_MANAGE", "ADMIN_SYSTEM_ALL")
	per_name NVARCHAR(100) UNIQUE NOT NULL, -- Tên hiển thị
	module_group NVARCHAR(50) NOT NULL      -- Nhóm module (USER_CORE, ADMIN_CORE)
);
GO
-- Index: Tối ưu tìm kiếm quyền theo nhóm module cho Admin UI
CREATE INDEX idx_permissions_group ON tPermissions(module_group) INCLUDE (per_code, per_name);
GO

-- DỮ LIỆU MẪU: Quyền hệ thống
INSERT INTO tPermissions (per_code, per_name, module_group) VALUES 
('ADMIN_SYSTEM_ALL',     N'Toàn quyền quản trị hệ thống và người dùng', 'ADMIN_CORE'),
('USER_STANDARD_MANAGE', N'Toàn quyền quản lý tài chính cá nhân cơ bản', 'USER_CORE');
GO

-- ======================================================================
-- 2. BẢNG VAI TRÒ
-- ======================================================================
CREATE TABLE tRoles(
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    -- DATA COLUMNS
    role_code VARCHAR(50) UNIQUE NOT NULL,       -- Mã role cho code check (VD: "ROLE_USER", "ROLE_ADMIN")
    role_name NVARCHAR(100) UNIQUE NOT NULL      -- Tên role hiển thị UI (VD: "Quản trị viên", "Người dùng")
)
GO

-- Index: Tối ưu check role từ Backend
CREATE INDEX idx_role_code ON tRoles(role_code) INCLUDE (role_name);
GO

-- DỮ LIỆU MẪU: Vai trò
INSERT INTO tRoles (role_code, role_name) VALUES 
('ROLE_ADMIN', N'Quản trị viên'),
('ROLE_USER', N'Người dùng tiêu chuẩn');
GO

-- ======================================================================
-- 3. BẢNG TRUNG GIAN ROLE - PERMISSION (N-N)
-- ======================================================================
CREATE TABLE tRolePermissions(
    -- PRIMARY KEY (Composite)
    role_id INT NOT NULL,                        -- FK -> tRoles (N-N)
    per_id INT NOT NULL,                         -- FK -> tPermissions (N-N)
	PRIMARY KEY (role_id, per_id),               -- Composite PK

    -- FOREIGN KEYS
	CONSTRAINT FK_Role FOREIGN KEY (role_id) REFERENCES tRoles(id),
	CONSTRAINT FK_Permission FOREIGN KEY (per_id) REFERENCES tPermissions(id)
)
GO

-- Index: Tối ưu load quyền theo Role (dùng khi nạp Security Context)
CREATE INDEX idx_roleper_role ON tRolePermissions(role_id) INCLUDE (per_id);
GO

INSERT INTO tRolePermissions (role_id, per_id) VALUES 
(1, 1),  -- Admin có quyền toàn quyền hệ thống
(2, 2);  -- User có quyền quản lý tài chính cá nhân
GO

-- ======================================================================
-- 4. BẢNG TIỀN TỆ
-- ======================================================================
CREATE TABLE tCurrencies (
    -- PRIMARY KEY
    currency_code VARCHAR(10) PRIMARY KEY,       -- Mã tiền tệ (VD: VND, USD, EUR)
    
    -- DATA COLUMNS
    currency_name NVARCHAR(100) UNIQUE NOT NULL, -- Tên đầy đủ (VD: "Việt Nam Đồng")
    symbol NVARCHAR(10) NOT NULL,                -- Ký hiệu (VD: "₫", "$", "€")
    flag_url VARCHAR(500) UNIQUE NOT NULL        -- URL cờ quốc gia (dùng CDN)
);
GO

-- DỮ LIỆU MẪU: Tiền tệ
INSERT INTO tCurrencies (currency_code, currency_name, symbol, flag_url) VALUES 
-- Cường quốc & Chiến hữu
('VND', N'Việt Nam Đồng', N'₫', 'https://flagcdn.com/w40/vn.png'),
('CNY', N'Nhân dân tệ', N'¥', 'https://flagcdn.com/w40/cn.png'),
('RUB', N'Rúp Nga', N'₽', 'https://flagcdn.com/w40/ru.png'),
('CUP', N'Peso Cuba', N'₱', 'https://flagcdn.com/w40/cu.png'),
('KPW', N'Won Triều Tiên', N'₩', 'https://flagcdn.com/w40/kp.png'),
('AOA', N'Kwanza Angola', N'Kz', 'https://flagcdn.com/w40/ao.png'),

-- Khu vực Đông Á
('HKD', N'Đô la Hồng Kông', N'$', 'https://flagcdn.com/w40/hk.png'),
('MOP', N'Pataca Macao', N'MOP$', 'https://flagcdn.com/w40/mo.png'),
('TWD', N'Đô la Đài Loan', N'$', 'https://flagcdn.com/w40/tw.png'),
('JPY', N'Yên Nhật', N'¥', 'https://flagcdn.com/w40/jp.png'),
('KRW', N'Won Hàn Quốc', N'₩', 'https://flagcdn.com/w40/kr.png'),

-- Đông Âu & Trung Á
('UAH', N'Hryvnia Ukraina', N'₴', 'https://flagcdn.com/w40/ua.png'),
('BYN', N'Rúp Belarus', N'Br', 'https://flagcdn.com/w40/by.png'),
('KZT', N'Tenge Kazakhstan', N'₸', 'https://flagcdn.com/w40/kz.png'),
('PLN', N'Zloty Ba Lan', N'zł', 'https://flagcdn.com/w40/pl.png'),

-- Phương Tây
('USD', N'Đô la Mỹ', N'$', 'https://flagcdn.com/w40/us.png'),
('EUR', N'Euro (Khối EU)', N'€', 'https://flagcdn.com/w40/eu.png'),
('GBP', N'Bảng Anh', N'£', 'https://flagcdn.com/w40/gb.png'),
('CHF', N'Franc Thụy Sĩ', N'CHF', 'https://flagcdn.com/w40/ch.png'),
('CAD', N'Đô la Canada', N'$', 'https://flagcdn.com/w40/ca.png'),
('AUD', N'Đô la Úc', N'$', 'https://flagcdn.com/w40/au.png'),

-- Nam Mỹ & Nam Á
('ARS', N'Peso Argentina', N'$', 'https://flagcdn.com/w40/ar.png'),
('BRL', N'Real Brazil', N'R$', 'https://flagcdn.com/w40/br.png'),
('INR', N'Rupee Ấn Độ', N'₹', 'https://flagcdn.com/w40/in.png'),

-- Trung Đông & Châu Phi
('SAR', N'Riyal Saudi Arabia', N'﷼', 'https://flagcdn.com/w40/sa.png'),
('AED', N'Dirham UAE', N'د.إ', 'https://flagcdn.com/w40/ae.png'),
('ILS', N'Shekel Israel', N'₪', 'https://flagcdn.com/w40/il.png'),
('EGP', N'Bảng Ai Cập', N'E£', 'https://flagcdn.com/w40/eg.png'),
('NGN', N'Naira Nigeria', N'₦', 'https://flagcdn.com/w40/ng.png'),
('ZAR', N'Rand Nam Phi', N'R', 'https://flagcdn.com/w40/za.png'),

-- Đông Nam Á (ASEAN)
('LAK', N'Kip Lào', N'₭', 'https://flagcdn.com/w40/la.png'),
('KHR', N'Riel Campuchia', N'៛', 'https://flagcdn.com/w40/kh.png'),
('THB', N'Baht Thái Lan', N'฿', 'https://flagcdn.com/w40/th.png'),
('SGD', N'Đô la Singapore', N'$', 'https://flagcdn.com/w40/sg.png'),
('MYR', N'Ringgit Malaysia', N'RM', 'https://flagcdn.com/w40/my.png'),
('IDR', N'Rupiah Indonesia', N'Rp', 'https://flagcdn.com/w40/id.png'),
('PHP', N'Peso Philippines', N'₱', 'https://flagcdn.com/w40/ph.png'),
('MMK', N'Kyat Myanmar', N'K', 'https://flagcdn.com/w40/mm.png'),
('BND', N'Đô la Brunei', N'$', 'https://flagcdn.com/w40/bn.png');
GO

-- ======================================================================
-- 5. BẢNG TÀI KHOẢN NGƯỜI DÙNG
-- ======================================================================
CREATE TABLE tAccounts (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    role_id INT NOT NULL,                        -- FK -> tRoles (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1) Tiền tệ mặc định
    
    -- DATA COLUMNS
    acc_phone VARCHAR(20) NULL,                  -- Số điện thoại (NULL nếu đăng ký bằng email)
    acc_email VARCHAR(100) NULL,                 -- Email (NULL nếu đăng ký bằng SĐT)
    hash_password VARCHAR(255) NOT NULL,         -- Mật khẩu đã hash (BCrypt/Argon2)
    avatar_url VARCHAR(2048) NULL,               -- URL avatar (upload hoặc CDN)
    locked BIT DEFAULT 0 NOT NULL,            -- 0: Active | 1: Locked (không thể login)
    
    -- METADATA
    created_at DATETIME DEFAULT GETDATE() NOT NULL,
    updated_at DATETIME DEFAULT GETDATE(),
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Account_Identity CHECK (acc_phone IS NOT NULL OR acc_email IS NOT NULL), -- Bắt buộc có 1 trong 2

    CONSTRAINT FK_Account_Role FOREIGN KEY (role_id) REFERENCES tRoles(id),
    CONSTRAINT FK_Account_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: Unique cho Phone (chặn trùng lặp)
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_acc_phone ON tAccounts(acc_phone) 
WHERE acc_phone IS NOT NULL;

-- Index: Unique cho Email (chặn trùng lặp)
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_acc_email ON tAccounts(acc_email) 
WHERE acc_email IS NOT NULL;

-- Index: Tối ưu Admin search User theo status và role
CREATE INDEX idx_accounts_admin ON tAccounts(locked, role_id, created_at DESC) 
INCLUDE (acc_phone, acc_email, avatar_url, currency);

-- Index: Tối ưu lọc User theo tiền tệ cho thống kê
CREATE INDEX idx_accounts_currency ON tAccounts(currency, created_at DESC);
GO

-- DỮ LIỆU MẪU: Tài khoản
INSERT INTO tAccounts (role_id, acc_phone, acc_email, hash_password, avatar_url, currency, locked) VALUES 
(1, '0901234567', 'admin@smartmoney.vn', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=AdminPRO', 'VND', 0),
(2, '0912345678', 'mai.tran@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Mai', 'VND', 1),
(2, '0987654321', 'nam.le@yahoo.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Nam', 'VND', 0),
(2, '0987654332', 'test3@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', NULL, 'VND', 0),
(1, '0909876543', 'huong.nguyen@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Huong', 'VND', 0),
(2, '0923456789', 'minh.pham@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Minh', 'VND', 0),
(2, '0934567890', 'linhvo@yahoo.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Linh', 'VND', 1),
(2, '0945678901', 'quanhoang@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Quan', 'VND', 0),
(2, '0956789012', 'thaodang@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', NULL, 'VND', 0),
(2, '0967890123', 'khanhbui@outlook.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Khanh', 'VND', 0),
(2, '0978901234', 'anhtruong@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Anh', 'VND', 1),
(2, '0989012345', 'ducdo@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Duc', 'VND', 0),
(2, '0911223344', 'hoanguyen@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Hoa', 'VND', 0),
(2, '0922334455', 'tuanvu@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Tuan', 'VND', 0),
(2, '0933445566', 'lanphan@yahoo.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', NULL, 'VND', 1),
(2, '0944556677', 'hung.ngo@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Hung', 'VND', 0),
(2, '0955667788', 'my.tran@outlook.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=My', 'VND', 0),
(2, '0966778899', 'son.le@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Son', 'VND', 0),
(2, '0977889900', 'thu.hoang@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', NULL, 'VND', 1),
(2, '0988990011', 'long.dang@gmail.com', '$2a$10$tF5hUn6YqBEMNkVi/0SlhOKYXEIzQwoGMXY1wIcRqRWSiG2Z.Id5K', 'https://api.dicebear.com/7.x/avataaars/svg?seed=Long', 'VND', 0);
GO

-- ======================================================================
-- 6. BẢNG THIẾT BỊ NGƯỜI DÙNG (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tUserDevices (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    device_token VARCHAR(500) NOT NULL,          -- Firebase/APNs token (UNIQUE)

    refresh_token VARCHAR(512) NULL,             -- JWT Refresh Token (hash)
    refresh_token_expired_at DATETIME NULL,      -- Thời hạn Refresh Token

    device_type VARCHAR(50) NOT NULL,            -- VD: "iOS", "Android", "Chrome_Windows"
    device_name NVARCHAR(100) NULL,              -- VD: "iPhone 15 Pro", "Samsung S24"
    ip_address VARCHAR(45) NULL,                 -- IPv4/IPv6 cuối cùng (cảnh báo đăng nhập lạ)
    logged_in BIT DEFAULT 1 NOT NULL,         -- 0: Đã logout | 1: Còn session
    last_active DATETIME DEFAULT GETDATE() NOT NULL, -- Thời gian cuối active (dùng tính Online)
    
    -- CONSTRAINTS
    CONSTRAINT FK_UserDevices_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id)     
);
GO
/* CÔNG THỨC CHECK ONLINE (Dành cho Dev Backend/Frontend):
  Online = (logged_in == 1) AND (CurrentTime - last_active < 5 phút)
  
  Lý do: logged_in chỉ cho biết User chưa bấm "Đăng xuất". 
  Còn last_active mới cho biết User có thực sự đang cầm máy hay không.
*/

--  Index: Unique cho Device Token (chặn trùng lặp)
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_device_token ON tUserDevices(device_token) WHERE device_token IS NOT NULL;
-- Index: Tối ưu validate Refresh Token nhanh
CREATE INDEX idx_devices_refresh ON tUserDevices(refresh_token, refresh_token_expired_at) WHERE refresh_token IS NOT NULL;
-- Index: Tối ưu query danh sách thiết bị Online của User
CREATE INDEX idx_devices_presence ON tUserDevices(acc_id, logged_in, last_active DESC) INCLUDE (device_name, device_type);
-- Index: Tối ưu Worker dọn token hết hạn
CREATE INDEX idx_devices_expired_token ON tUserDevices(refresh_token_expired_at) WHERE refresh_token IS NOT NULL;
GO
-- ======================================================================
-- DỮ LIỆU MẪU: Thiết bị người dùng (tUserDevices)
-- ======================================================================
-- PHÂN BỔ: 26 rows cho 20 users
-- TEST CASES: Multi-device, Online/Offline, Token hết hạn, Đa nền tảng
-- ======================================================================

INSERT INTO tUserDevices (
    acc_id, device_token, refresh_token, refresh_token_expired_at,
    device_type, device_name, ip_address, logged_in, last_active
) VALUES

-- ══════════════════════════════════════════════════════════════════════
-- USER 1 (Admin) - 2 thiết bị (PC + Mobile)
-- ══════════════════════════════════════════════════════════════════════
(1, 'fcm_admin_desktop_token_001', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.admin.pc', 
 DATEADD(DAY, 7, GETDATE()), 
 'Chrome_Windows', N'PC Dell XPS 15', '192.168.1.100', 1, DATEADD(MINUTE, -2, GETDATE())),
 -- ☑️ ONLINE (logged_in=1, last_active < 5 phút)

(1, 'fcm_admin_mobile_token_002', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.admin.iphone', 
 DATEADD(DAY, 5, GETDATE()), 
 'iOS', N'iPhone 15 Pro Max', '42.118.225.134', 1, DATEADD(HOUR, -3, GETDATE())),
 -- ☑️ OFFLINE (logged_in=1 nhưng last_active > 5 phút)

-- ══════════════════════════════════════════════════════════════════════
-- USER 2 (Mai) - LOCKED account - 1 thiết bị cũ
-- ══════════════════════════════════════════════════════════════════════
(2, 'fcm_mai_android_token_003', NULL, NULL, 
 'Android', N'Samsung Galaxy S23', '103.56.158.92', 0, DATEADD(DAY, -15, GETDATE())),
 -- ☑️ LOGGED OUT (logged_in=0) - Account bị lock

-- ══════════════════════════════════════════════════════════════════════
-- USER 3 (Nam) - 3 thiết bị (test multi-device)
-- ══════════════════════════════════════════════════════════════════════
(3, 'fcm_nam_iphone_token_004', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.nam.iphone', 
 DATEADD(DAY, 6, GETDATE()), 
 'iOS', N'iPhone 14', '115.78.34.201', 1, GETDATE()),
 -- ☑️ ONLINE (vừa mới active)

(3, 'fcm_nam_laptop_token_005', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.nam.macbook', 
 DATEADD(DAY, 3, GETDATE()), 
 'Safari_macOS', N'MacBook Pro 2023', '192.168.1.105', 1, DATEADD(MINUTE, -4, GETDATE())),
 -- ☑️ ONLINE (trong 5 phút)

(3, 'fcm_nam_ipad_token_006', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.nam.ipad', 
 DATEADD(DAY, -2, GETDATE()), 
 'iOS', N'iPad Air 5', '115.78.34.201', 1, DATEADD(DAY, -1, GETDATE())),
 -- ☑️ TOKEN HẾT HẠN + OFFLINE

-- ══════════════════════════════════════════════════════════════════════
-- USER 4 (test3) - 1 thiết bị Android
-- ══════════════════════════════════════════════════════════════════════
(4, 'fcm_test3_xiaomi_token_007', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test3.xiaomi', 
 DATEADD(DAY, 4, GETDATE()), 
 'Android', N'Xiaomi Redmi Note 12', '171.244.56.123', 1, DATEADD(MINUTE, -30, GETDATE())),
 -- ☑️ OFFLINE (30 phút trước)

-- ══════════════════════════════════════════════════════════════════════
-- USER 5 (Hương - Admin) - 2 thiết bị
-- ══════════════════════════════════════════════════════════════════════
(5, 'fcm_huong_desktop_token_008', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.huong.desktop', 
 DATEADD(DAY, 7, GETDATE()), 
 'Edge_Windows', N'PC HP EliteBook', '192.168.10.50', 1, DATEADD(MINUTE, -1, GETDATE())),
 -- ☑️ ONLINE

(5, 'fcm_huong_android_token_009', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.huong.oppo', 
 DATEADD(DAY, 5, GETDATE()), 
 'Android', N'OPPO Find X6 Pro', '113.161.78.45', 1, DATEADD(HOUR, -2, GETDATE())),
 -- ☑️ OFFLINE

-- ══════════════════════════════════════════════════════════════════════
-- USER 6 (Minh) - 1 thiết bị iPhone
-- ══════════════════════════════════════════════════════════════════════
(6, 'fcm_minh_iphone13_token_010', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.minh.iphone', 
 DATEADD(DAY, 6, GETDATE()), 
 'iOS', N'iPhone 13 Pro', '14.231.187.92', 1, DATEADD(MINUTE, -10, GETDATE())),
 -- ☑️ OFFLINE

-- ══════════════════════════════════════════════════════════════════════
-- USER 7 (Linh) - LOCKED - 1 thiết bị cũ
-- ══════════════════════════════════════════════════════════════════════
(7, 'fcm_linh_vivo_token_011', NULL, NULL, 
 'Android', N'Vivo V29', '125.235.10.88', 0, DATEADD(DAY, -20, GETDATE())),
 -- ☑️ LOGGED OUT - Account locked

-- ══════════════════════════════════════════════════════════════════════
-- USER 8 (Quân) - 2 thiết bị (Web + Mobile)
-- ══════════════════════════════════════════════════════════════════════
(8, 'fcm_quan_chrome_token_012', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.quan.chrome', 
 DATEADD(DAY, 7, GETDATE()), 
 'Chrome_Linux', N'Ubuntu Desktop 22.04', '118.70.186.45', 1, DATEADD(SECOND, -30, GETDATE())),
 -- ☑️ ONLINE (30s trước)

(8, 'fcm_quan_realme_token_013', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.quan.realme', 
 DATEADD(DAY, 4, GETDATE()), 
 'Android', N'Realme GT Neo 5', '118.70.186.45', 1, DATEADD(DAY, -1, GETDATE())),
 -- ☑️ OFFLINE (1 ngày trước)

-- ══════════════════════════════════════════════════════════════════════
-- USER 9 (Thảo) - 1 thiết bị Samsung
-- ══════════════════════════════════════════════════════════════════════
(9, 'fcm_thao_samsung_token_014', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.thao.samsung', 
 DATEADD(DAY, 5, GETDATE()), 
 'Android', N'Samsung Galaxy A54', '171.224.178.90', 1, DATEADD(MINUTE, -3, GETDATE())),
 -- ☑️ ONLINE

-- ══════════════════════════════════════════════════════════════════════
-- USER 10 (Khánh) - 2 thiết bị (PC + iOS)
-- ══════════════════════════════════════════════════════════════════════
(10, 'fcm_khanh_firefox_token_015', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.khanh.firefox', 
 DATEADD(DAY, 6, GETDATE()), 
 'Firefox_Windows', N'PC Acer Aspire', '192.168.2.88', 1, DATEADD(MINUTE, -15, GETDATE())),
 -- ☑️ OFFLINE

(10, 'fcm_khanh_iphone_token_016', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.khanh.iphone12', 
 DATEADD(DAY, -1, GETDATE()), 
 'iOS', N'iPhone 12 Mini', '42.112.89.156', 1, DATEADD(HOUR, -10, GETDATE())),
 -- ☑️ TOKEN HẾT HẠN + OFFLINE

-- ══════════════════════════════════════════════════════════════════════
-- USER 11 (Anh) - LOCKED - Đã logout
-- ══════════════════════════════════════════════════════════════════════
(11, 'fcm_anh_oneplus_token_017', NULL, NULL, 
 'Android', N'OnePlus 11', '113.185.42.78', 0, DATEADD(DAY, -10, GETDATE())),
 -- ☑️ LOGGED OUT

-- ══════════════════════════════════════════════════════════════════════
-- USER 12 (Đức) - 1 thiết bị Android
-- ══════════════════════════════════════════════════════════════════════
(12, 'fcm_duc_pixel_token_018', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.duc.pixel', 
 DATEADD(DAY, 7, GETDATE()), 
 'Android', N'Google Pixel 8 Pro', '171.250.166.34', 1, DATEADD(MINUTE, -2, GETDATE())),
 -- ☑️ ONLINE

-- ══════════════════════════════════════════════════════════════════════
-- USER 13 (Hoa) - 1 thiết bị Web
-- ══════════════════════════════════════════════════════════════════════
(13, 'fcm_hoa_brave_token_019', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.hoa.brave', 
 DATEADD(DAY, 5, GETDATE()), 
 'Brave_macOS', N'MacBook Air M2', '192.168.5.120', 1, DATEADD(HOUR, -1, GETDATE())),
 -- ☑️ OFFLINE

-- ══════════════════════════════════════════════════════════════════════
-- USER 14 (Tuấn) - 1 thiết bị iPhone
-- ══════════════════════════════════════════════════════════════════════
(14, 'fcm_tuan_iphone14_token_020', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.tuan.iphone14', 
 DATEADD(DAY, 6, GETDATE()), 
 'iOS', N'iPhone 14 Plus', '27.72.98.156', 1, DATEADD(MINUTE, -4, GETDATE())),
 -- ☑️ ONLINE

-- ══════════════════════════════════════════════════════════════════════
-- USER 15 (Lan) - LOCKED - Không còn session
-- ══════════════════════════════════════════════════════════════════════
(15, 'fcm_lan_huawei_token_021', NULL, NULL, 
 'Android', N'Huawei Nova 11', '14.177.234.89', 0, DATEADD(DAY, -25, GETDATE())),
 -- ☑️ LOGGED OUT

-- ══════════════════════════════════════════════════════════════════════
-- USER 16 (Hưng) - 1 thiết bị Android
-- ══════════════════════════════════════════════════════════════════════
(16, 'fcm_hung_note20_token_022', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.hung.note20', 
 DATEADD(DAY, 4, GETDATE()), 
 'Android', N'Samsung Note 20 Ultra', '113.172.45.201', 1, DATEADD(MINUTE, -8, GETDATE())),
 -- ☑️ OFFLINE

-- ══════════════════════════════════════════════════════════════════════
-- USER 17 (Mỹ) - 2 thiết bị (PC + Mobile)
-- ══════════════════════════════════════════════════════════════════════
(17, 'fcm_my_opera_token_023', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.my.opera', 
 DATEADD(DAY, 7, GETDATE()), 
 'Opera_Windows', N'PC Lenovo ThinkPad', '192.168.8.45', 1, GETDATE()),
 -- ☑️ ONLINE (vừa mới active)

(17, 'fcm_my_asus_token_024', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.my.asus', 
 DATEADD(DAY, 3, GETDATE()), 
 'Android', N'ASUS Zenfone 10', '171.255.89.123', 1, DATEADD(HOUR, -6, GETDATE())),
 -- ☑️ OFFLINE

-- ══════════════════════════════════════════════════════════════════════
-- USER 18 (Sơn) - 1 thiết bị iOS
-- ══════════════════════════════════════════════════════════════════════
(18, 'fcm_son_iphone13pro_token_025', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.son.iphone', 
 DATEADD(DAY, 5, GETDATE()), 
 'iOS', N'iPhone 13 Pro Max', '42.119.167.88', 1, DATEADD(MINUTE, -20, GETDATE())),
 -- ☑️ OFFLINE

-- ══════════════════════════════════════════════════════════════════════
-- USER 19 (Thu) - LOCKED - Đã logout
-- ══════════════════════════════════════════════════════════════════════
(19, 'fcm_thu_tablet_token_026', NULL, NULL, 
 'Android', N'Samsung Galaxy Tab S9', '113.168.234.77', 0, DATEADD(DAY, -30, GETDATE())),
 -- ☑️ LOGGED OUT - Account locked

-- ══════════════════════════════════════════════════════════════════════
-- USER 20 (Long) - 1 thiết bị Web
-- ══════════════════════════════════════════════════════════════════════
(20, 'fcm_long_chromium_token_027', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.long.chromium', 
 DATEADD(DAY, 6, GETDATE()), 
 'Chromium_Linux', N'Linux Mint Desktop', '118.69.78.156', 1, DATEADD(MINUTE, -3, GETDATE()));
 -- ☑️ ONLINE

GO

-- ======================================================================
-- THỐNG KÊ DỮ LIỆU ĐÃ CHÈN
-- ======================================================================
-- Total Rows: 27 devices
-- Users có >1 thiết bị: User 1, 3, 5, 8, 10, 17 (6 users)
-- Devices ONLINE (logged_in=1, last_active < 5 min): 10 devices
-- Devices OFFLINE: 11 devices
-- Devices LOGGED OUT (logged_in=0): 6 devices (users bị lock)
-- Tokens hết hạn: 2 devices (user 3, user 10)
-- Nền tảng: iOS (8), Android (13), Windows (4), macOS (2), Linux (2)
-- ======================================================================
PRINT '✅ Đã chèn 27 rows vào tUserDevices thành công!';
PRINT 'Phân bổ: 20 users, 10 online, 11 offline, 6 logged out';
GO

-- ======================================================================
-- 7. BẢNG DANH MỤC THU/CHI (Tự tham chiếu: 1-N với chính nó)
-- ======================================================================
-- Nếu người dùng muốn xóa danh mục thì sẽ có 2 hướng ( Xóa hẳn và gồm lịch sử giao dịch hoặc chọn gộp sang một danh mục khác và xóa danh mục này )
CREATE TABLE tCategories (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NULL,                             -- FK -> tAccounts (N-1) | NULL = System Category
    parent_id INT NULL,                          -- FK -> tCategories (1-N) | NULL = Root Category
    
    -- DATA COLUMNS
    ctg_name NVARCHAR(100) NOT NULL,             -- Tên danh mục (VD: "Ăn uống", "Lương")
    ctg_type BIT NOT NULL,                       -- 0: Chi tiêu | 1: Thu nhập
    ctg_icon_url VARCHAR(2048) NULL,             -- Icon SVG hoặc URL (VD: "icon_food.png")
    
    -- CONSTRAINTS
    CONSTRAINT FK_Categories_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Categories_Parent FOREIGN KEY (parent_id) REFERENCES tCategories(id) -- Tự tham chiếu
);
GO

-- Index: Tối ưu Backend check danh mục System
CREATE INDEX idx_system_category_check ON tCategories(ctg_name) WHERE acc_id IS NULL AND parent_id IS NULL;
-- Index: Tối ưu query danh mục theo User và Parent
CREATE INDEX idx_categories_lookup ON tCategories(acc_id, parent_id, ctg_type) INCLUDE (ctg_name, ctg_icon_url);
-- Chặn User tạo 2 mục con (vd: "Tiền trà đá", "Tiền trà đá") trong cùng một mục cha.
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_sub_category ON tCategories(acc_id, parent_id, ctg_name, ctg_type) WHERE parent_id IS NOT NULL;
-- Chặn User tạo 2 mục cha (vd: "Ăn uống", "Ăn uống").
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_user_root ON tCategories(acc_id, ctg_name, ctg_type) 
WHERE parent_id IS NULL AND acc_id IS NOT NULL;
-- Index Unique: Bảo vệ danh mục gốc System không bị trùng
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_root_category ON tCategories(ctg_name, ctg_type) 
WHERE parent_id IS NULL AND acc_id IS NULL;
-- Index Unique: Bảo vệ danh mục con System không bị trùng
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_system_sub_category ON tCategories(parent_id, ctg_name, ctg_type) WHERE parent_id IS NOT NULL AND acc_id IS NULL;
-- Ngăn User tạo danh mục Gốc trùng tên với danh mục Gốc của Hệ thống ( viết trong backend )

/* HƯỚNG DẪN CHO BACKEND hoặc dùng trigger (IMPORTANT):
   - ĐIỀU KIỆN: "User không được tạo danh mục Gốc trùng tên với System".
   - BACKEND CẦN CHECK: Trước khi lưu danh mục Gốc cho User, hãy kiểm tra xem 'ctg_name' 
     đã tồn tại trong các dòng (acc_id IS NULL AND parent_id IS NULL) chưa. 
     Nếu có -> Báo lỗi cho người dùng không được tạo trùng danh mục hệ thống
*/

GO
-- Chèn danh mục hệ thống (acc_id = NULL)
-- ==========================================================
-- BƯỚC 1: CHÈN CÁC NHÓM CHA (ROOT) - ĐỊNH DANH CẤP CAO NHẤT
-- ==========================================================
-- 1.1 NHÓM CHI TIÊU (EXPENSE = 0)
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url) VALUES  
 (NULL, NULL, N'Ăn uống', 0, 'icon_food.png')
,(NULL, NULL, N'Bảo hiểm', 0, 'icon_insurance.png')
,(NULL, NULL, N'Các chi phí khác', 0, 'icon_other_expense.png')
,(NULL, NULL, N'Đầu tư', 0, 'icon_invest.png')
,(NULL, NULL, N'Di chuyển', 0, 'icon_transport.png')
,(NULL, NULL, N'Gia đình', 0, 'icon_family.png')
,(NULL, NULL, N'Giải trí', 0, 'icon_entertainment.png')
,(NULL, NULL, N'Giáo dục', 0, 'icon_education.png')
,(NULL, NULL, N'Hoá đơn & Tiện ích', 0, 'icon_utilities.png')
,(NULL, NULL, N'Mua sắm', 0, 'icon_shopping.png')
,(NULL, NULL, N'Quà tặng & Quyên góp', 0, 'icon_gift.png')
,(NULL, NULL, N'Sức khỏe', 0, 'icon_health.png')
,(NULL, NULL, N'Tiền chuyển đi', 0, 'icon_transfer_out.png')
,(NULL, NULL, N'Trả lãi', 0, 'icon_interest_pay.png');

-- 1.2 NHÓM THU NHẬP (INCOME = 1)
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url) VALUES  
 (NULL, NULL, N'Lương', 1, 'icon_salary.png')
,(NULL, NULL, N'Thu lãi', 1, 'icon_interest_receive.png')
,(NULL, NULL, N'Thu nhập khác', 1, 'icon_other_income.png')
,(NULL, NULL, N'Tiền chuyển đến', 1, 'icon_transfer_in.png');

-- 1.3 NHÓM VAY / NỢ
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url) VALUES  
 (NULL, NULL, N'Cho vay', 0, 'icon_loan_out.png')
,(NULL, NULL, N'Đi vay', 1, 'icon_loan_in.png')
,(NULL, NULL, N'Thu nợ', 1, 'icon_debt_collection.png')
,(NULL, NULL, N'Trả nợ', 0, 'icon_debt_repayment.png');
GO -- Kết thúc phiên làm việc 1 để SQL lưu ID các nhóm Cha

-- ==========================================================
-- BƯỚC 2: CHÈN CÁC NHÓM CON (SUB-CATEGORIES) - LIÊN KẾT CHA
-- ==========================================================
-- Chèn con cho nhóm CHI TIÊU
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url)
SELECT NULL, p.id, v.new_name, p.ctg_type, v.icon
FROM (VALUES  
    (N'Di chuyển', N'Bảo dưỡng xe', 'icon_car_repair.png'),
    (N'Gia đình', N'Dịch vụ gia đình', 'icon_home_service.png'),
    (N'Gia đình', N'Sửa & trang trí nhà', 'icon_home_decor.png'),
    (N'Gia đình', N'Vật nuôi', 'icon_pets.png'),
    (N'Giải trí', N'Dịch vụ trực tuyến', 'icon_online_service.png'),
    (N'Giải trí', N'Vui - chơi', 'icon_travel.png'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn điện', 'icon_electricity.png'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn điện thoại', 'icon_phone_bill.png'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn gas', 'icon_gas.png'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn internet', 'icon_internet.png'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn nước', 'icon_water.png'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn tiện ích khác', 'icon_other_bill.png'),
    (N'Hoá đơn & Tiện ích', N'Hoá đơn TV', 'icon_tv.png'),
    (N'Hoá đơn & Tiện ích', N'Thuê nhà', 'icon_rent.png'),
    (N'Mua sắm', N'Đồ dùng cá nhân', 'icon_personal_item.png'),
    (N'Mua sắm', N'Đồ gia dụng', 'icon_home_appliance.png'),
    (N'Mua sắm', N'Làm đẹp', 'icon_beauty.png'),
    (N'Sức khỏe', N'Khám sức khoẻ', 'icon_medical.png'),
    (N'Sức khỏe', N'Thể dục thể thao', 'icon_sport.png')
) AS v(parent_name, new_name, icon)
JOIN tCategories p ON p.ctg_name = v.parent_name AND p.parent_id IS NULL;
GO

-- ======================================================================
-- 8. BẢNG VÍ (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tWallets (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1)
    -- them anh con thieu
     goal_image_url VARCHAR(2048) NULL,           -- Hình ảnh ví
    -- DATA COLUMNS
    wallet_name NVARCHAR(100) NOT NULL,          -- VD: "Tiền mặt", "Vietcombank", "Momo"
    balance DECIMAL(18,2) DEFAULT 0,             -- Số dư hiện tại (tự động tính từ Transactions)
    notified BIT DEFAULT 1 NOT NULL,          -- 0: Tắt thông báo | 1: Bật thông báo
    reportable BIT DEFAULT 1 NOT NULL,        -- 0: Không tính vào báo cáo | 1: Tính vào Dashboard
    
    -- CONSTRAINTS
    CONSTRAINT FK_Wallets_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Wallets_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: Tối ưu load danh sách Ví của User
CREATE INDEX idx_wallets_user ON tWallets(acc_id, reportable) INCLUDE (wallet_name, balance, currency, notified);
GO

-- DỮ LIỆU MẪU: Ví
INSERT INTO tWallets (acc_id, wallet_name, balance, currency, notified, reportable, goal_image_url) VALUES 
(1, N'Tiền mặt', 5000000, 'VND', 1, 1, 'wallet.png'),
(1, N'Vietcombank', 15000000, 'VND', 1, 1, 'wallet.png'),
(2, N'Ví MoMo', 2500000, 'VND', 1, 1, 'wallet.png'),
(2, N'Techcombank', 8000000, 'VND', 1, 1, 'wallet.png'),
(3, N'Tiền mặt', 3200000, 'VND', 1, 1, 'wallet.png'),
(3, N'BIDV', 12000000, 'VND', 1, 1, 'wallet.png'),
(19, N'ZaloPay', 1800000, 'VND', 1, 1, 'wallet.png'),
(4, N'Agribank', 20000000, 'VND', 1, 1, 'wallet.png'),
(5, N'Ví tiết kiệm', 50000000, 'VND', 0, 0, 'wallet.png'),
(6, N'MB Bank', 6500000, 'VND', 1, 1, 'wallet.png'),
(6, N'VNPay', 900000, 'VND', 1, 1, 'wallet.png'),
(7, N'ACB', 18000000, 'VND', 1, 1, 'wallet.png'),
(20, N'Ví du lịch', 10000000, 'VND', 1, 1, 'wallet.png'),
(20, N'VPBank', 7200000, 'VND', 1, 1, 'wallet.png'),
(9, N'Tiền mặt', 4500000, 'VND', 1, 1, 'wallet.png'),
(10, N'SHB', 9800000, 'VND', 1, 1, 'wallet.png'),
(10, N'Ví mua sắm', 3000000, 'VND', 1, 1, 'wallet.png'),
(11, N'TPBank', 11000000, 'VND', 1, 1, 'wallet.png'),
(12, N'Ví khẩn cấp', 5000000, 'VND', 0, 0, 'wallet.png'),
(12, N'Sacombank', 14500000, 'VND', 1, 1, 'wallet.png'),
(8, N'Tiền mặt', 2800000, 'VND', 1, 1, 'wallet.png'),
(14, N'HDBank', 16000000, 'VND', 1, 1, 'wallet.png'),
(15, N'Ví học phí', 25000000, 'VND', 1, 1, 'wallet.png'),
(16, N'OCB', 8500000, 'VND', 1, 1, 'wallet.png'),
(17, N'Ví đầu tư', 30000000, 'VND', 0, 0, 'wallet.png'),
(18, N'VietinBank', 13200000, 'VND', 1, 1, 'wallet.png');
GO

-- ======================================================================
-- 9. BẢNG MỤC TIÊU TIẾT KIỆM (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tSavingGoals (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1)
    
    -- DATA COLUMNS
    goal_name NVARCHAR(200) NOT NULL,            -- VD: "Mua iPhone 15 Pro Max", "Quỹ khẩn cấp"
    target_amount DECIMAL(18,2) NOT NULL,        -- Số tiền mục tiêu
    current_amount DECIMAL(18,2) DEFAULT 0,      -- Số tiền đã tiết kiệm
    goal_image_url VARCHAR(2048) NULL,           -- Hình ảnh mục tiêu (VD: ảnh iPhone)
    begin_date DATE DEFAULT GETDATE(),           -- Ngày bắt đầu
    end_date DATE NOT NULL,                      -- Ngày kết thúc
    goal_status TINYINT DEFAULT 1 NOT NULL,        -- 1: Active | 2: Completed | 3: Cancelled | 4: OVERDUE ( quá hạn )
    notified BIT DEFAULT 1 NOT NULL,          -- 0: Tắt thông báo | 1: Bật thông báo
    reportable BIT DEFAULT 1 NOT NULL,        -- 0: Không tính vào báo cáo | 1: Tính vào Dashboard
    finished BIT DEFAULT 0,                   -- 0: Đang diễn ra | 1: Đã kết thúc
    
    -- CONSTRAINTS
    CONSTRAINT CHK_SavingGoals_Amount CHECK (target_amount > 0 AND current_amount >= 0),
    CONSTRAINT CHK_SavingGoals_Progress CHECK (current_amount <= target_amount),
    CONSTRAINT CHK_SavingGoals_Dates CHECK (end_date >= begin_date),
    CONSTRAINT CHK_SavingGoals_Status CHECK (goal_status IN (1, 2, 3, 4)),

    CONSTRAINT FK_SavingGoals_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_SavingGoals_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: Tối ưu Dashboard và Báo cáo tổng quát
CREATE INDEX idx_saving_reportable ON tSavingGoals(acc_id, reportable, goal_status, finished) INCLUDE (current_amount, target_amount, end_date, currency);
-- Index: Tối ưu hiển thị mục tiêu đang Active
CREATE INDEX idx_saving_active ON tSavingGoals(acc_id, goal_status, finished) INCLUDE (goal_name, current_amount, target_amount, end_date);
GO

-- DỮ LIỆU MẪU: Mục tiêu tiết kiệm
INSERT INTO tSavingGoals (acc_id, goal_name, target_amount, current_amount, begin_date, end_date, goal_status, notified, reportable, finished, goal_image_url, currency) VALUES 
(1, N'Quỹ khẩn cấp', 50000000, 30000000, '2024-01-15', '2026-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(1, N'Mua nhà', 2000000000, 500000000, '2023-06-01', '2028-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(2, N'Mua iPhone 15', 25000000, 5000000, '2025-03-10', '2027-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(2, N'Du lịch Nhật Bản', 40000000, 15000000, '2025-01-20', '2026-06-30', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(3, N'Heo đất màu vàng', 10000000, 8500000, '2024-08-01', '2026-08-01', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(3, N'Tiền khám bệnh', 15000000, 12000000, '2024-05-15', '2026-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(5, N'Mua xe máy SH', 90000000, 45000000, '2024-11-01', '2026-10-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(5, N'Quỹ cưới', 200000000, 80000000, '2024-02-14', '2027-02-14', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(6, N'Mua laptop Dell XPS 15', 45000000, 25000000, '2025-02-01', '2026-05-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(7, N'Tiết kiệm học tập', 30000000, 18000000, '2024-09-01', '2027-06-30', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(8, N'Mua đất', 500000000, 150000000, '2024-01-01', '2029-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(9, N'Quỹ khẩn cấp', 40000000, 25000000, '2024-07-01', '2026-06-30', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(10, N'Mua nhẫn cưới', 50000000, 35000000, '2024-12-01', '2026-11-30', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(10, N'Kỳ nghỉ Châu Âu', 80000000, 30000000, '2025-01-01', '2027-05-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(11, N'Mua ô tô', 400000000, 120000000, '2024-03-15', '2028-03-15', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(12, N'Quỹ sửa nhà', 100000000, 45000000, '2024-10-01', '2026-09-30', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(13, N'Mua iPad Pro', 28000000, 10000000, '2025-04-01', '2026-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(14, N'Tiền sinh nhật con', 20000000, 15000000, '2024-06-01', '2026-08-15', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(15, N'Học Thạc sĩ', 150000000, 60000000, '2024-01-10', '2028-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(16, N'Mua AirPods Pro', 6000000, 4500000, '2025-03-01', '2026-03-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(17, N'Đầu tư chứng khoán', 100000000, 70000000, '2024-02-01', '2027-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(18, N'Mua đồng hồ', 45000000, 20000000, '2025-01-05', '2026-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(19, N'Quỹ khởi nghiệp', 200000000, 50000000, '2024-04-01', '2027-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(20, N'Mua máy ảnh', 55000000, 35000000, '2024-11-15', '2026-06-30', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(4, N'Quỹ hưu trí', 500000000, 100000000, '2023-01-01', '2030-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(4, N'Quỹ giáo dục con', 300000000, 150000000, '2023-09-01', '2028-08-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(11, N'Khóa học AWS Solutions Architect', 18000000, 8000000, '2025-02-10', '2026-08-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(13, N'Chuyến du ngoạn Maldives', 65000000, 22000000, '2025-03-15', '2026-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(15, N'Quỹ phát triển kỹ năng lập trình', 25000000, 12000000, '2024-10-01', '2027-03-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(17, N'Mua MacBook Pro M3', 52000000, 28000000, '2025-01-20', '2026-09-30', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(6, N'Quỹ đăng ký ChatGPT Plus & Claude Pro', 12000000, 3500000, '2025-01-01', '2026-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(8, N'Quỹ mua license JetBrains', 8000000, 4200000, '2024-11-01', '2026-06-30', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(12, N'Quỹ nâng cấp VPS & Domain', 15000000, 6800000, '2024-08-15', '2027-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(14, N'Quỹ sức khỏe tinh thần (sau khi bị AI thay thế)', 30000000, 8000000, '2024-06-01', '2028-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(16, N'Quỹ học chuyển nghề (phòng thân)', 50000000, 15000000, '2024-09-01', '2027-06-30', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(18, N'Quỹ mua API credits (OpenAI, Anthropic)', 20000000, 9500000, '2025-02-01', '2026-12-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
-- ══════════════════════════════════════════════════════════════════════
-- STATUS 2: Completed (Đã hoàn thành)
-- Logic: current_amount = target_amount, finished = 1, end_date đã qua
-- ══════════════════════════════════════════════════════════════════════
(1,  N'Mua iPhone 14 Pro',          20000000, 20000000, '2024-01-01', '2024-12-31', 2, 1, 1, 1, 'savinggoal.png',   'VND'),
-- ✅ Đã tiết kiệm đủ 20tr, hoàn thành trước hạn

(3,  N'Mua xe đạp thể thao',         8000000,  8000000, '2024-03-01', '2025-06-30', 2, 1, 1, 1, 'savinggoal.png',    'VND'),
-- ✅ Đã đạt mục tiêu, finished

(8,  N'Quỹ du lịch Thái Lan',       25000000, 25000000, '2024-05-01', '2025-12-31', 2, 1, 1, 1, 'savinggoal.png',   'VND'),
-- ✅ Hoàn thành đúng hạn

(12, N'Mua máy ảnh Sony A7III',      40000000, 40000000, '2023-06-01', '2025-01-31', 2, 1, 1, 1, 'savinggoal.png',       'VND'),
-- ✅ Hoàn thành sớm

(20, N'Học khóa Flutter nâng cao',    5000000,  5000000, '2025-01-01', '2025-08-31', 2, 1, 1, 1, 'savinggoal.png',    'VND'),
-- ✅ Hoàn thành

-- ══════════════════════════════════════════════════════════════════════
-- STATUS 3: Cancelled (Đã hủy)
-- Logic: finished = 1, current_amount < target_amount (bỏ dở giữa chừng)
-- ══════════════════════════════════════════════════════════════════════
(2,  N'Mua PS5',                     16000000,  4500000, '2024-02-01', '2025-03-31', 3, 0, 0, 1, 'savinggoal.png',        'VND'),
-- ❌ Hủy vì đổi ý không mua nữa, đã rút tiền ra

(5,  N'Du lịch Hàn Quốc',           60000000, 12000000, '2024-06-01', '2025-12-31', 3, 0, 0, 1, 'savinggoal.png',      'VND'),
-- ❌ Hủy vì kế hoạch thay đổi

(9,  N'Mua tủ lạnh side-by-side',   18000000,  3000000, '2024-09-01', '2025-06-30', 3, 0, 0, 1, 'savinggoal.png',     'VND'),
-- ❌ Hủy vì mượn được tiền người thân

(16, N'Mua SmartTV 65 inch',        22000000,  8000000, '2024-04-01', '2025-09-30', 3, 0, 1, 1, 'savinggoal.png',         'VND'),
-- ❌ Hủy vì mua loại khác rẻ hơn

-- ══════════════════════════════════════════════════════════════════════
-- STATUS 4 OVERDUE: Để status=1, end_date trong QUÁ KHỨ
-- → Scheduler sẽ tự động detect và chuyển sang status=4
-- ══════════════════════════════════════════════════════════════════════

-- CASE A: Sẽ bị Scheduler đóng (finished sẽ = 1 sau khi scheduler chạy)
(1,  N'Quỹ sửa xe ô tô',            15000000,  6000000, '2024-08-01', '2025-12-31', 1, 1, 1, 0, 'savinggoal.png',    'VND'),
(7,  N'Quỹ học IELTS',              12000000,  5000000, '2024-07-01', '2025-11-30', 1, 1, 1, 0, 'savinggoal.png',     'VND'),
(18, N'Mua ghế gaming DXRacer',      9000000,  4000000, '2025-02-01', '2026-02-28', 1, 1, 1, 0, 'savinggoal.png',    'VND'),

-- CASE B: Quá hạn nhưng user vẫn muốn tiếp tục (finished = 0 giữ nguyên)
-- → Scheduler detect ra, chuyển status=4 nhưng KHÔNG set finished=1
(4,  N'Mua máy lọc không khí',       8000000,  2500000, '2024-10-01', '2025-10-31', 1, 1, 1, 0, 'savinggoal.png', 'VND'),
(10, N'Mua bàn làm việc ergonomic',  6000000,  1800000, '2025-01-01', '2025-12-31', 1, 1, 1, 0, 'savinggoal.png',      'VND'),
(13, N'Quỹ đám cưới bạn thân',      10000000,  3000000, '2025-03-01', '2026-01-31', 1, 1, 1, 0, 'savinggoal.png',    'VND');
GO

-- ======================================================================
-- 10. BẢNG SỰ KIỆN (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tEvents (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1)
    
    -- DATA COLUMNS
    event_name NVARCHAR(200) NOT NULL,           -- VD: "Đám cưới", "Du lịch Đà Lạt"
    event_icon_url NVARCHAR(2048) DEFAULT 'icon_event_default.png',
    begin_date DATE DEFAULT GETDATE(),           -- Ngày bắt đầu sự kiện
    end_date DATE NOT NULL,                      -- Ngày kết thúc sự kiện
    finished BIT DEFAULT 0,                   -- 0: Đang diễn ra | 1: Đã kết thúc
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Events_Dates CHECK (end_date >= begin_date),
    CONSTRAINT FK_Events_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id) ON DELETE CASCADE,
    CONSTRAINT FK_Events_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: Tối ưu tìm kiếm sự kiện đang chạy để gán vào giao dịch
CREATE INDEX idx_events_active ON tEvents(acc_id, finished, currency) 
INCLUDE (event_name, begin_date, end_date);

-- Index: Tối ưu hiển thị danh sách tất cả sự kiện ở màn quản lý
CREATE INDEX idx_events_all ON tEvents(acc_id, begin_date DESC) 
INCLUDE (event_name, finished, event_icon_url);
GO

-- DỮ LIỆU MẪU: Sự kiện
INSERT INTO tEvents (acc_id, event_name, begin_date, end_date, finished, event_icon_url, currency) VALUES 
(1, N'Du lịch Đà Lạt', '2025-12-20', '2025-12-25', 0, 'icon_event_default.png', 'VND'),
(1, N'Tết Nguyên Đán 2026', '2026-01-28', '2026-02-03', 0, 'icon_event_default.png', 'VND'),
(2, N'Du lịch Đà Nẵng', '2025-08-15', '2029-08-30', 0, 'icon_event_default.png', 'VND'),
(3, N'Sinh nhật 25 tuổi', '2026-03-15', '2026-03-15', 0, 'icon_event_default.png', 'VND'),
(4, N'Đám cưới anh Tuấn', '2026-05-10', '2026-05-10', 0, 'icon_event_default.png', 'VND'),
(5, N'Họp lớp 10 năm', '2026-07-20', '2026-07-20', 0, 'icon_event_default.png', 'VND'),
(6, N'Dự án tốt nghiệp', '2025-02-01', '2026-06-30', 0, 'icon_event_default.png', 'VND'),
(7, N'Khóa học React Native', '2025-03-01', '2025-08-31', 0, 'icon_event_default.png', 'VND'),
(8, N'Du lịch Phú Quốc', '2026-04-10', '2026-04-15', 0, 'icon_event_default.png', 'VND'),
(9, N'Thi chứng chỉ AWS', '2026-06-01', '2026-06-30', 0, 'icon_event_default.png', 'VND'),
(10, N'Lễ hội âm nhạc', '2026-09-12', '2026-09-13', 0, 'icon_event_default.png', 'VND'),
(11, N'Hackathon FPT 2026', '2026-10-15', '2026-10-17', 0, 'icon_event_default.png', 'VND'),
(12, N'Chuyến về quê Tết', '2027-01-25', '2027-02-05', 0, 'icon_event_default.png', 'VND'),
(13, N'Workshop Spring Boot', '2025-05-10', '2025-05-12', 0, 'icon_event_default.png', 'VND'),
(14, N'Đi teambuilding công ty', '2026-08-20', '2026-08-22', 0, 'icon_event_default.png', 'VND'),
(15, N'Mua sắm Black Friday', '2025-11-28', '2025-11-30', 0, 'icon_event_default.png', 'VND'),
(16, N'Du lịch Sapa', '2026-12-10', '2026-12-15', 0, 'icon_event_default.png', 'VND'),
(17, N'Tham gia DevFest 2026', '2026-11-05', '2026-11-06', 0, 'icon_event_default.png', 'VND'),
(18, N'Khám sức khỏe định kỳ', '2026-03-01', '2026-03-31', 0, 'icon_event_default.png', 'VND'),
(19, N'Sửa nhà', '2025-06-01', '2025-09-30', 0, 'icon_event_default.png', 'VND'),
(20, N'Kỳ nghỉ hè gia đình', '2026-07-01', '2026-07-10', 0, 'icon_event_default.png', 'VND');
GO

-- ======================================================================
-- 11. BẢNG SỔ NỢ (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tDebts (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    debt_type BIT NOT NULL,                      -- 0: Cần Trả (Đi vay) | 1: Cần Thu (Cho vay)
    person_name NVARCHAR(200) NOT NULL,          -- Tên người vay/cho vay (VD: "Bạn A", "Anh Minh")
    total_amount DECIMAL(18,2) NOT NULL,         -- Tổng số tiền ban đầu
    remain_amount DECIMAL(18,2) NOT NULL,        -- Số tiền còn lại (giảm dần khi trả/thu)
    due_date DATETIME NULL,                      -- Ngày hẹn trả (dùng để nhắc nhở)
    note NVARCHAR(500) NULL,                     -- Ghi chú thuần túy (VD: "Vay mua xe", "Học phí")
    finished BIT DEFAULT 0 NOT NULL,             -- 0: Đang nợ | 1: Đã hoàn thành
    created_at DATETIME DEFAULT GETDATE(),       -- Ngày tạo khoản nợ
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Debts_TotalAmount CHECK (total_amount > 0),
    CONSTRAINT CHK_Debts_RemainLogic CHECK (remain_amount >= 0 AND remain_amount <= total_amount),
    CONSTRAINT FK_Debts_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id) ON DELETE CASCADE
);
GO

-- Index: Tối ưu Tab Cần Thu/Trả theo User và loại
CREATE INDEX idx_debts_active ON tDebts(acc_id, debt_type, finished, due_date) INCLUDE (remain_amount, total_amount, note);

-- Index: Tối ưu tính tổng nợ cho Báo cáo/Dashboard
CREATE INDEX idx_debts_reportable ON tDebts(acc_id, finished) INCLUDE (remain_amount, debt_type);

-- Index: Tối ưu lọc sổ nợ theo thời gian tạo
CREATE INDEX idx_debts_created ON tDebts(acc_id, created_at DESC) WHERE finished = 0;
GO

-- DỮ LIỆU MẪU: Sổ nợ
INSERT INTO tDebts (acc_id, debt_type, person_name, total_amount, remain_amount, due_date, note, finished, created_at) VALUES 
-- User 1 - Admin
(1, 0, N'Ngân hàng VPBank',  20000000, 15000000, '2026-06-30 23:59:59', N'Vay mua xe máy SH',       0, '2025-07-15 10:00:00'),
(1, 1, N'Anh Minh',           5000000,  3000000, '2026-03-31 23:59:59', N'Cho vay tiền khẩn cấp',   0, '2025-12-10 14:30:00'),
-- User 2 - Mai Trần
(2, 1, N'Bạn A',               500000,   500000, '2029-07-30 23:59:59', NULL,                        0, '2025-01-15 09:00:00'),
(2, 0, N'Bố Mẹ',             3000000,  1500000, '2026-04-15 23:59:59', N'Vay mua iPhone',            0, '2026-01-20 11:00:00'),
-- User 3 - Nam Lê
(3, 1, N'Em trai',            2000000,  2000000, '2026-05-20 23:59:59', N'Học phí',                  0, '2026-02-01 08:00:00'),
(3, 0, N'Bạn thân',          10000000,  7000000, '2026-12-31 23:59:59', N'Vay mua laptop',           0, '2025-10-15 16:30:00'),
-- User 5
(5, 0, N'Ngân hàng ACB',     50000000, 40000000, '2027-12-31 23:59:59', N'Vay cưới',                 0, '2025-06-01 09:30:00'),
(5, 1, N'Đồng nghiệp Hưng',   8000000,  5000000, '2026-08-30 23:59:59', N'Cho vay mua xe',           0, '2025-11-20 13:00:00'),
-- User 6
(6, 1, N'Chị gái',            3500000,  3500000, '2026-07-15 23:59:59', N'Cho vay đi du lịch',       0, '2026-01-25 10:45:00'),
-- User 7
(7, 0, N'Bố',                15000000, 12000000, '2026-09-30 23:59:59', N'Vay mua MacBook',          0, '2025-12-05 15:00:00'),
-- User 8
(8, 1, N'Bạn cùng phòng',     4000000,  1500000, '2026-06-10 23:59:59', N'Cho vay tiền nhà',         0, '2025-09-01 12:00:00'),
-- User 10
(10, 0, N'Mẹ',               25000000, 20000000, '2027-06-30 23:59:59', N'Vay mua nhẫn cưới',        0, '2025-08-20 11:30:00'),
(10, 1, N'Em họ Khoa',         6000000,  6000000, '2026-10-31 23:59:59', N'Cho vay sửa xe',           0, '2026-01-10 09:15:00'),
-- User 11
(11, 0, N'Ngân hàng Techcom', 35000000, 28000000, '2028-12-31 23:59:59', N'Vay đầu tư chứng khoán',  0, '2024-11-01 10:00:00'),
-- User 12
(12, 1, N'Anh trai',          10000000,  7000000, '2026-11-20 23:59:59', N'Cho vay sửa nhà',          0, '2025-07-30 14:00:00'),
-- User 14
(14, 0, N'Công ty',            7000000,  5000000, '2026-05-31 23:59:59', N'Ứng lương',                0, '2025-11-15 08:30:00'),
-- User 15
(15, 1, N'Bạn học Phúc',      12000000, 12000000, '2027-03-31 23:59:59', N'Cho vay học Thạc sĩ',      0, '2026-01-05 13:20:00'),
-- User 17
(17, 0, N'Ngân hàng BIDV',   100000000, 80000000, '2029-12-31 23:59:59', N'Vay khởi nghiệp',          0, '2024-06-15 09:00:00'),
-- User 18
(18, 1, N'Cháu Linh',          5500000,  2500000, '2026-08-15 23:59:59', N'Cho vay mua điện thoại',   0, '2025-10-20 16:00:00'),
-- User 20
(20, 0, N'Bạn thân Tuấn',     18000000, 15000000, '2027-02-28 23:59:59', N'Vay mua máy ảnh',          0, '2025-09-10 11:00:00');
GO

-----------------------------------------------------------------------------------------------------------------------------
-- tAIConversations 1-1 tReceipts nếu xác nhận có hóa đơn thì mới tạo hóa đơn khóa chính. Hóa đơn là khóa chính của chat
-- ======================================================================
-- 12. BẢNG LỊCH SỬ CHAT AI (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tAIConversations (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    message_content NVARCHAR(MAX) NOT NULL,      -- Nội dung tin nhắn
    sender_type BIT NOT NULL,                    -- 0: User nhắn | 1: AI phản hồi
    intent TINYINT,                              -- NULL AI đang quét ảnh, 1: add_transaction | 2: report_query | 3: set_budget | 4: general_chat | 5: remind_task
    attachment_url NVARCHAR(500) NULL,           -- URL file đính kèm (hình ảnh hóa đơn/voice)
    attachment_type TINYINT NULL,                -- 1: image | 2: voice | NULL: chat text
    created_at DATETIME DEFAULT GETDATE(),       -- Thời gian chat 

    -- CONSTRAINTS    
    
    --1. Thêm chi tiêu/thu nhập
    --2. Hỏi về báo cáo, số dư
    --3. Thiết lập hạn mức
    --4. Tán gẫu hoặc hỏi đáp chung
    --5. Nhắc nhở    
    CONSTRAINT CHK_AIConversations_Intent CHECK (intent BETWEEN 1 AND 5),
	CONSTRAINT CHK_AIConversations_Attachment_Type CHECK (attachment_type IN (1, 2)), -- chat thường là null

	CONSTRAINT CHK_AIConversations_Attach_Logic CHECK (
		(attachment_type = 1 AND attachment_url IS NOT NULL) OR     -- Có ảnh thì bắt buộc phải có URL
		(attachment_type = 2 AND attachment_url IS NULL) OR         -- Lệnh giọng nói thì URL để NULL (không lưu file)
		(attachment_type IS NULL AND attachment_url IS NULL)        -- Chat text thì cả 2 NULL
	),

	CONSTRAINT FK_AIConversations_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
);
GO

-- Index: Tối ưu load lịch sử chat của User theo thời gian
CREATE INDEX idx_ai_chat_user ON tAIConversations(acc_id, created_at DESC) INCLUDE (message_content, sender_type, intent);

-- Index: Tối ưu phân loại chat theo mục đích (intent)
CREATE INDEX idx_ai_intent ON tAIConversations(acc_id, intent, created_at DESC) INCLUDE (message_content, sender_type, attachment_type);
GO

-- DỮ LIỆU MẪU: Chat AI
INSERT INTO tAIConversations (acc_id, message_content, sender_type, intent, attachment_url, attachment_type, created_at) VALUES
-- User 1: Nhắn text thêm giao dịch cafe
(1, N'Tôi vừa mua cafe 45k', 0, 1, NULL, NULL, '2026-02-10 08:15:00'),
(1, N'Đã ghi nhận: Chi tiêu 45,000đ cho danh mục Ăn uống - Cafe. Ví Tiền mặt còn 4,955,000đ', 1, 1, NULL, NULL, '2026-02-10 08:15:03'),

-- User 2: Nhắn text thêm giao dịch ăn sáng, sau đó gửi ảnh hóa đơn Vinmart
(2, N'Tôi đã chi 100k ăn sáng', 0, 1, NULL, NULL, '2026-02-09 07:30:00'),
(2, N'Đã ghi nhận giao dịch ăn sáng 100k', 1, 1, NULL, NULL, '2026-02-09 07:30:02'),
(2, N'Đây là hóa đơn mua sắm tại Vinmart', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user2_vinmart.jpg', 1, '2026-02-09 18:45:00'),
(2, N'Tôi đã phân tích hóa đơn: Tổng chi 850,000đ gồm 15 món hàng tại Vinmart. Bạn muốn phân loại vào danh mục nào?', 1, 1, NULL, NULL, '2026-02-09 18:45:05'),

-- User 3: Hỏi báo cáo chi tiêu ăn uống tháng này
(3, N'Tháng này tôi chi bao nhiêu tiền ăn uống?', 0, 2, NULL, NULL, '2026-02-10 20:00:00'),
(3, N'Tháng 2/2026 bạn đã chi 2,350,000đ cho Ăn uống, chiếm 35% tổng chi tiêu. Top 3: Nhà hàng (1.2tr), Cafe (800k), Ăn vặt (350k)', 1, 2, NULL, NULL, '2026-02-10 20:00:04'),

-- User 5: Dùng giọng nói thêm giao dịch xăng, sau đó gửi ảnh hóa đơn Petrolimex
(5, N'Vừa đổ xăng 200 nghìn', 0, 1, NULL, 2, '2026-02-09 17:20:00'),
(5, N'OK! Đã ghi nhận 200,000đ vào danh mục Đi lại - Xăng xe. Ví Agribank còn 19,800,000đ', 1, 1, NULL, NULL, '2026-02-09 17:20:02'),
(5, N'Hóa đơn đổ xăng Petrolimex', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user5_petrolimex.jpg', 1, '2026-02-09 17:25:00'),
(5, N'Đã phân tích hóa đơn Petrolimex: Xăng RON95 5.2L x 25,500đ = 132,600đ. Ghi vào danh mục Đi lại?', 1, 1, NULL, NULL, '2026-02-09 17:25:04'),

-- User 6: Thiết lập hạn mức ngân sách ăn uống
(6, N'Đặt hạn mức chi tiêu ăn uống tháng này là 3 triệu', 0, 3, NULL, NULL, '2026-02-01 09:00:00'),
(6, N'Đã thiết lập ngân sách: Ăn uống - 3,000,000đ/tháng. Hiện tại bạn đã chi 450,000đ (15%). Tôi sẽ nhắc nhở khi đạt 80%', 1, 3, NULL, NULL, '2026-02-01 09:00:03'),

-- User 7: Hỏi tư vấn cách tiết kiệm tiền
(7, N'Làm sao để tiết kiệm tiền hiệu quả?', 0, 4, NULL, NULL, '2026-02-08 21:30:00'),
(7, N'Dựa vào thói quen chi tiêu của bạn, tôi có 3 gợi ý: 1) Giảm cafe/trà sữa (đang chi 600k/tháng) 2) Nấu ăn thay vì ăn ngoài 3) Đặt mục tiêu tiết kiệm cụ thể với tính năng Saving Goals', 1, 4, NULL, NULL, '2026-02-08 21:30:06'),

-- User 10: Đặt nhắc nhở trả nợ, sau đó gửi ảnh hóa đơn Uniqlo
(10, N'Nhắc tôi trả nợ anh Tuấn vào ngày 15', 0, 5, NULL, NULL, '2026-02-10 14:00:00'),
(10, N'Đã tạo lời nhắc: "Trả nợ anh Tuấn" vào 15/02/2026 lúc 9:00 sáng. Số tiền còn nợ: 5,000,000đ', 1, 5, NULL, NULL, '2026-02-10 14:00:02'),
(10, N'Hóa đơn Uniqlo Diamond Plaza', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user10_uniqlo.jpg', 1, '2026-02-07 18:00:00'),
(10, N'Đã phân tích hóa đơn Uniqlo: Áo thun nam x2 (600k), Quần jean (900k). Tổng: 1,500,000đ. Xác nhận ghi vào Mua sắm?', 1, 1, NULL, NULL, '2026-02-07 18:00:05'),

-- User 11: Gửi ảnh hóa đơn CGV để thêm giao dịch
(11, N'Thêm giao dịch từ hóa đơn này', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user11_cgv.jpg', 1, '2026-02-09 22:00:00'),
(11, N'Phát hiện hóa đơn CGV: 2 vé phim (300k), bắp rang bơ (80k), nước ngọt (60k). Tổng: 440,000đ. Xác nhận ghi vào danh mục Giải trí?', 1, 1, NULL, NULL, '2026-02-09 22:00:04'),

-- User 15: Hỏi so sánh chi tiêu 2 tháng, sau đó gửi ảnh hóa đơn học phí FPT
(15, N'So sánh chi tiêu tháng này với tháng trước', 0, 2, NULL, NULL, '2026-02-10 19:30:00'),
(15, N'Tháng 2: 8,500,000đ | Tháng 1: 7,200,000đ (+18%). Tăng chủ yếu ở: Giáo dục (+2tr), Mua sắm (+500k). Giảm: Ăn uống (-200k)', 1, 2, NULL, NULL, '2026-02-10 19:30:05'),
(15, N'Hóa đơn học phí ĐH FPT', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user15_fpt.jpg', 1, '2026-02-06 13:05:00'),
(15, N'Đã phân tích hóa đơn ĐH FPT: Học phí kỳ 2 - 3,500,000đ. Ghi vào danh mục Giáo dục?', 1, 1, NULL, NULL, '2026-02-06 13:05:06'),

-- User 17: Dùng giọng nói thêm giao dịch mua sách
(17, N'Mua sách lập trình 350 nghìn', 0, 1, NULL, 2, '2026-02-08 16:45:00'),
(17, N'Đã lưu: 350,000đ - Sách lập trình vào danh mục Giáo dục. Quỹ phát triển kỹ năng lập trình còn 11,650,000đ', 1, 1, NULL, NULL, '2026-02-08 16:45:03'),

-- User 20: Hỏi tổng quan ngân sách, sau đó gửi ảnh vé máy bay VietJet
(20, N'Tôi đã chi bao nhiêu % ngân sách tháng này?', 0, 2, NULL, NULL, '2026-02-10 22:00:00'),
(20, N'Tổng quan tháng 2: Đã chi 4,200,000đ/8,000,000đ (52.5%). An toàn ở hầu hết danh mục. Cảnh báo: Du lịch đạt 85% (2,550k/3tr)', 1, 2, NULL, NULL, '2026-02-10 22:00:03'),
(20, N'Vé máy bay VietJet Hà Nội - Đà Lạt', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user20_vietjet.jpg', 1, '2026-02-09 11:25:00'),
(20, N'Đã phân tích vé VietJet: Hà Nội → Đà Lạt, 2,700,000đ. Ghi vào danh mục Du lịch?', 1, 1, NULL, NULL, '2026-02-09 11:25:06'),
-- User 3: Gửi ảnh hóa đơn bị mờ, OCR thất bại
(3, N'Hóa đơn siêu thị đây bạn', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user3_blur.jpg', 1, '2026-02-10 21:00:00'),
(3, N'Xin lỗi, ảnh hóa đơn bị mờ, tôi không thể đọc được. Bạn có thể chụp lại rõ hơn không?', 1, NULL, NULL, NULL, '2026-02-10 21:00:06'),

-- User 6: Gửi ảnh hóa đơn mới, AI đang xử lý
(6, N'Hóa đơn mua sắm Shopee hôm nay', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user6_shopee.jpg', 1, '2026-02-10 23:50:00');
-- (chưa có AI reply vì đang pending)
GO

-- ======================================================================
-- 13. BẢNG HÓA ĐƠN QUÉT (1-1 với tAIConversations)
-- ======================================================================
CREATE TABLE tReceipts (
    -- PRIMARY KEY (= Foreign Key)
    id INT PRIMARY KEY,                          -- FK -> tAIConversations (1-1)
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    image_url NVARCHAR(500) NOT NULL,            -- URL ảnh hóa đơn (upload lên Cloud hoặc server)
    raw_ocr_text NVARCHAR(MAX) NULL,             -- Text gốc từ OCR
    processed_data NVARCHAR(MAX) NULL DEFAULT '{}',    -- Dữ liệu đã parse (JSON format)
    receipt_status NVARCHAR(20) DEFAULT 'pending' NOT NULL, -- pending | processed | error
    created_at DATETIME DEFAULT GETDATE() NOT NULL,

    -- CONSTRAINTS	
    CONSTRAINT CHK_Receipt_Status CHECK (receipt_status IN ('pending', 'processed', 'error')),
    
    -- Check logic: Đã xong thì phải có dữ liệu
    CONSTRAINT CHK_Receipt_Processed_Logic CHECK (
        (receipt_status = 'processed' AND processed_data IS NOT NULL) 
        OR (receipt_status <> 'processed')
    ),

	CONSTRAINT FK_Receipts_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
	CONSTRAINT FK_Receipts_Chat FOREIGN KEY (id) REFERENCES tAIConversations(id) ON DELETE CASCADE
);
GO
-- Index: Tối ưu lọc hóa đơn chờ xử lý (pending) của User
CREATE INDEX idx_receipts_pending ON tReceipts(acc_id, receipt_status, created_at DESC) 
WHERE receipt_status = 'pending';

-- Index: Tối ưu query hóa đơn theo User và trạng thái
CREATE INDEX idx_receipts_user ON tReceipts(acc_id, receipt_status, created_at DESC) 
INCLUDE (image_url, raw_ocr_text);
GO
-- ======================================================================
-- DỮ LIỆU MẪU: Hóa đơn
-- ======================================================================
INSERT INTO tReceipts (id, acc_id, image_url, raw_ocr_text, processed_data, receipt_status, created_at) VALUES
(5, 2,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user2_vinmart.jpg',
N'VINMART
123 Nguyễn Huệ Q1
09/02/2026 18:30
Rau cải 35.000đ
Thịt heo 180.000đ
Trứng gà 45.000đ
Gạo ST25 150.000đ
TỔNG CỘNG 850.000đ',
'{"store":"Vinmart","total":850000,"date":"2026-02-09","category":"Mua sắm"}', 'processed', '2026-02-09 18:45:00'),

(11, 5,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user5_petrolimex.jpg',
N'PETROLIMEX
09/02/2026 17:25
Xăng RON95 5.2L
Đơn giá 25.500đ/L
Thành tiền 132.600đ
Tiền khách đưa 200.000đ
Tiền thừa 67.400đ',
'{"store":"Petrolimex","total":132600,"date":"2026-02-09","category":"Đi lại"}', 'processed', '2026-02-09 17:25:00'),

(19, 10,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user10_uniqlo.jpg',
N'UNIQLO
Diamond Plaza Q1
07/02/2026 18:00
Áo thun nam x2 600.000đ
Quần jean 900.000đ
TỔNG CỘNG 1.500.000đ',
'{"store":"Uniqlo","total":1500000,"date":"2026-02-07","category":"Mua sắm"}', 'processed', '2026-02-07 18:00:00'),

(21, 11,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user11_cgv.jpg',
N'CGV CINEMAS
Landmark 81
09/02/2026 22:00
2x Vé phim 300.000đ
Bắp rang bơ 80.000đ
Coca 60.000đ
TỔNG 440.000đ',
'{"store":"CGV","total":440000,"date":"2026-02-09","category":"Giải trí"}', 'processed', '2026-02-09 22:00:00'),

(25, 15,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user15_fpt.jpg',
NULL,
'{"store":"ĐH FPT","total":3500000,"date":"2026-02-06","category":"Giáo dục"}', 'processed', '2026-02-06 13:05:00'),

(31, 20,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user20_vietjet.jpg',
NULL,
'{"airline":"VietJet","total":2700000,"date":"2026-02-09","category":"Du lịch"}', 'processed', '2026-02-09 11:25:00'),
-- id=33: error - ảnh mờ không OCR được
(33, 3,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user3_blur.jpg',
N'##ÊU TH##
##/##/20## ##:##
S### ph### ##.###đ
TỔ## ##ỌNG ???',
NULL, 'error', '2026-02-10 21:00:00'),

-- id=35: pending - vừa gửi, chưa xử lý xong
(35, 6,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user6_shopee.jpg',
NULL,
NULL, 'pending', '2026-02-10 23:50:00');
GO
-----------------------------------------------------------------------------------------------------------------------------

-- ======================================================================
-- 14. BẢNG NGÂN SÁCH (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tBudgets (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    wallet_id INT NULL,                      -- FK -> tWallets (N-1) Ngân sách rút từ ví nào
    
    -- DATA COLUMNS
    amount DECIMAL(18,2) NOT NULL,               -- Giới hạn ngân sách
    begin_date DATE DEFAULT GETDATE() NOT NULL,  -- Ngày bắt đầu chu kỳ
    end_date DATE NOT NULL,                      -- Ngày kết thúc chu kỳ
    all_categories BIT DEFAULT 0,             -- 0: Theo danh mục cụ thể | 1: Tất cả Chi tiêu
    repeating BIT DEFAULT 0,                  -- 0: Một lần | 1: Tự động gia hạn
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Budgets_Amount CHECK (amount > 0),
    CONSTRAINT CHK_Budgets_Dates CHECK (end_date >= begin_date),
    CONSTRAINT FK_Budgets_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Budgets_Wallet FOREIGN KEY (wallet_id) REFERENCES tWallets(id) ON DELETE CASCADE
);
GO

-- Code back end
-- CHẶN TRÙNG NGÂN SÁCH: Một User không thể có 2 ngân sách cho 1 danh mục trong cùng 1 khoảng thời gian
-- Lưu ý: Backend cần check logic ngày tháng, còn DB chặn trùng lặp tuyệt đối category cho chắc ăn.
--CREATE UNIQUE NONCLUSTERED INDEX idx_unique_budget_period ON tBudgets(acc_id, ctg_id, begin_date, end_date);

-- Index: Tối ưu query ngân sách theo User và chu kỳ
CREATE INDEX idx_budget_lookup ON tBudgets(acc_id, begin_date, end_date, all_categories) INCLUDE (amount, wallet_id, repeating);
GO

-- ======================================================================
-- Dữ liệu mẫu tBudgets
-- ======================================================================
INSERT INTO tBudgets (acc_id, wallet_id, amount, begin_date, end_date, all_categories, repeating) VALUES
-- [ID=1]  User 1:  Ăn uống tháng 2 - mọi ví - tự gia hạn
(1,  NULL, 5000000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=2]  User 2:  Mua sắm tháng 2 - ví MoMo (id=3)
(2,  3,    3000000,  '2026-02-01', '2026-02-28', 0, 0),
-- [ID=3]  User 2:  Tổng chi tiêu all_categories - mọi ví
(2,  NULL, 10000000, '2026-02-01', '2026-02-28', 1, 1),
-- [ID=4]  User 6:  Ăn uống + Giải trí gộp - mọi ví
(6,  NULL, 2000000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=5]  User 5:  Di chuyển tháng 2 - mọi ví
(5,  NULL, 1500000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=6]  User 3:  Hoá đơn & Tiện ích - ví Tiền mặt (id=5)
(3,  5,    2000000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=7]  User 20: Du lịch tháng 2 - mọi ví
(20, NULL, 10000000, '2026-02-01', '2026-02-28', 0, 0),
-- [ID=8]  User 1:  Mua sắm tháng 2 - ví Vietcombank (id=2)
(1,  2,    3000000,  '2026-02-01', '2026-02-28', 0, 0),
-- [ID=9]  User 7:  Ăn uống tháng 2 - ví ACB (id=12)
(7,  12,   2500000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=10] User 10: Tổng chi tiêu all_categories - mọi ví
(10, NULL, 8000000,  '2026-02-01', '2026-02-28', 1, 1),
-- [ID=11] User 11: Giáo dục tháng 2 - ví TPBank (id=18)
(11, 18,   5000000,  '2026-02-01', '2026-02-28', 0, 0),
-- [ID=12] User 15: Giáo dục tháng 2 - ví Học phí (id=23)
(15, 23,   8000000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=13] User 17: Đầu tư tháng 2 - ví Đầu tư (id=26) - không gia hạn
(17, 26,   15000000, '2026-02-01', '2026-02-28', 0, 0),
-- [ID=14] User 3:  Ăn uống + Sức khỏe gộp - mọi ví
(3,  NULL, 3000000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=15] User 12: Tổng chi tiêu all_categories - ví Sacombank (id=20)
(12, 20,   12000000, '2026-02-01', '2026-02-28', 1, 1),
-- [ID=16] User 8:  Sức khỏe tháng 2 - ví Tiền mặt (id=21)
(8,  21,   2000000,  '2026-02-01', '2026-02-28', 0, 0),
-- [ID=17] User 2:  Ăn uống tháng 3 - ví Techcombank (id=4) - tự gia hạn
(2,  4,    2500000,  '2026-03-01', '2026-03-31', 0, 1),
-- [ID=18] User 6:  Giáo dục tháng 2 - mọi ví
(6,  NULL, 1500000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=19] User 20: Tổng all_categories tháng 2 - ví du lịch (id=13)
(20, 13,   20000000, '2026-02-01', '2026-02-28', 1, 0),
-- [ID=20] User 1:  Hoá đơn & Tiện ích quý 1 - mọi ví - tự gia hạn
(1,  NULL, 2000000,  '2026-01-01', '2026-03-31', 0, 1);
GO

-- ======================================================================
-- 15. BẢNG TRUNG GIAN BUDGET - CATEGORY (N-N)
-- ======================================================================
CREATE TABLE tBudgetCategories (
    -- PRIMARY KEY (Composite)
    budget_id INT NOT NULL,                      -- FK -> tBudgets (N-N)
    ctg_id INT NOT NULL,                         -- FK -> tCategories (N-N)
    PRIMARY KEY (budget_id, ctg_id),
    
    -- FOREIGN KEYS
    CONSTRAINT FK_BudgetCategories_Budget FOREIGN KEY (budget_id) REFERENCES tBudgets(id) ON DELETE CASCADE,
    CONSTRAINT FK_BudgetCategories_Category FOREIGN KEY (ctg_id) REFERENCES tCategories(id) ON DELETE CASCADE
);
GO

-- Index: Tối ưu query ngược từ Category -> Budgets
CREATE INDEX idx_budget_ctg_reverse ON tBudgetCategories(ctg_id, budget_id);
GO
-- ======================================================================
-- DỮ LIỆU MẪU: Chi tiết danh mục áp dụng ngân sách (tBudgetCategories)
-- ======================================================================
INSERT INTO tBudgetCategories (budget_id, ctg_id) VALUES
(1,  1),  -- Budget 1  (User 1):  Ăn uống (id=1)
(2,  10), -- Budget 2  (User 2):  Mua sắm (id=10)
          -- Budget 3  (User 2):  all_categories=1 → không cần insert
(4,  1),  -- Budget 4  (User 6):  Ăn uống
(4,  7),  -- Budget 4  (User 6):  Giải trí
(5,  5),  -- Budget 5  (User 5):  Di chuyển (id=5)
(6,  9),  -- Budget 6  (User 3):  Hoá đơn & Tiện ích (id=9)
(7,  7),  -- Budget 7  (User 20): Giải trí (id=7) - map du lịch vào Giải trí
(8,  10), -- Budget 8  (User 1):  Mua sắm (id=10)
(9,  1),  -- Budget 9  (User 7):  Ăn uống (id=1)
          -- Budget 10 (User 10): all_categories=1 → không cần insert
(11, 8),  -- Budget 11 (User 11): Giáo dục (id=8)
(12, 8),  -- Budget 12 (User 15): Giáo dục (id=8)
(13, 4),  -- Budget 13 (User 17): Đầu tư (id=4)
(14, 1),  -- Budget 14 (User 3):  Ăn uống
(14, 12), -- Budget 14 (User 3):  Sức khỏe
          -- Budget 15 (User 12): all_categories=1 → không cần insert
(16, 12), -- Budget 16 (User 8):  Sức khỏe (id=12)
(17, 1),  -- Budget 17 (User 2):  Ăn uống (id=1)
(18, 8),  -- Budget 18 (User 6):  Giáo dục (id=8)
          -- Budget 19 (User 20): all_categories=1 → không cần insert
(20, 9),  -- Budget 20 (User 1):  Hoá đơn & Tiện ích (id=9)
(20, 29), -- Budget 20 (User 1):  sub Điện (id=29)
(20, 32); -- Budget 20 (User 1):  Internet (id=32)
GO

-- ======================================================================
-- 16. BẢNG GIAO DỊCH (TRUNG TÂM HỆ THỐNG)
-- ======================================================================
CREATE TABLE tTransactions (
    -- PRIMARY KEY
    id BIGINT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    ctg_id INT NULL,                             -- FK -> tCategories (N-1) | NULL = Chi trừ nợ không phân loại
    wallet_id INT NULL,                          -- FK -> tWallets (N-1)
    event_id INT NULL,                           -- FK -> tEvents (N-1) | NULL = Không thuộc sự kiện
    debt_id INT NULL,                            -- FK -> tDebts (N-1) | NULL = Không liên quan nợ
    goal_id INT NULL,                            -- FK -> tSavingGoals (N-1) | NULL = Không liên quan mục tiêu
    ai_chat_id INT NULL,                         -- FK -> tAIConversations (N-1) | NULL = Nhập thủ công
    
    -- DATA COLUMNS
    amount DECIMAL(18,2) NOT NULL,               -- Số tiền giao dịch
    with_person NVARCHAR(100) NULL,              -- Tên người liên quan (VD: người vay, người trả)
    note NVARCHAR(500) NULL,                     -- Ghi chú (VD: "Ăn sáng", "Lương tháng 1")
    reportable BIT DEFAULT 1 NOT NULL,        -- 0: Không tính vào báo cáo | 1: Tính vào Dashboard
    source_type TINYINT DEFAULT 1 NOT NULL,      -- 1: manual | 2: chat | 3: voice | 4: receipt | 5: planned
    trans_date DATETIME DEFAULT GETDATE() NOT NULL,   -- Ngày giao dịch thực tế
    created_at DATETIME DEFAULT GETDATE() NOT NULL,   -- Ngày hệ thống ghi nhận
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Transaction_Amount CHECK (amount > 0),
    CONSTRAINT CHK_Transaction_SourceType CHECK (source_type BETWEEN 1 AND 5),
    CONSTRAINT CHK_Transaction_Integrity CHECK (
        (source_type = 1 AND ai_chat_id IS NULL) OR          -- Nhập tay hoàn toàn (ko liên quan Lịch) -> KO có chat
        (source_type IN (2, 3, 4) AND ai_chat_id IS NOT NULL) OR -- AI nhập giùm khoản phát sinh -> BẮT BUỘC có chat
        (source_type = 5)                                    -- Sinh ra từ Lịch -> TỰ DO (Có chat cũng đc, ko có cũng đc)
    ),  
    CONSTRAINT CHK_Transaction_SingleWallet CHECK (
        NOT (wallet_id IS NOT NULL AND goal_id IS NOT NULL)
    ),
    CONSTRAINT FK_Transactions_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Transactions_Category FOREIGN KEY (ctg_id) REFERENCES tCategories(id) ON DELETE CASCADE,
    CONSTRAINT FK_Transactions_Wallet FOREIGN KEY (wallet_id) REFERENCES tWallets(id) ON DELETE CASCADE,
    CONSTRAINT FK_Transactions_Event FOREIGN KEY (event_id) REFERENCES tEvents(id),
    CONSTRAINT FK_Transactions_Debt FOREIGN KEY (debt_id) REFERENCES tDebts(id),
    CONSTRAINT FK_Transactions_Goal FOREIGN KEY (goal_id) REFERENCES tSavingGoals(id),
    CONSTRAINT FK_Transactions_Chat FOREIGN KEY (ai_chat_id) REFERENCES tAIConversations(id)
);
GO

-- Index: Tối ưu Báo cáo tài chính và Dashboard chính
CREATE INDEX idx_trans_main ON tTransactions(acc_id, wallet_id, trans_date DESC) 
INCLUDE (amount, ctg_id, reportable, source_type);

-- Index: Tối ưu query giao dịch theo Mục tiêu tiết kiệm
CREATE INDEX idx_trans_goal ON tTransactions(goal_id) 
INCLUDE (amount, trans_date) 
WHERE goal_id IS NOT NULL;

-- Index: Tối ưu query giao dịch theo Sự kiện
CREATE INDEX idx_trans_event ON tTransactions(event_id) 
INCLUDE (amount, trans_date, ctg_id) 
WHERE event_id IS NOT NULL;

-- Index: Tối ưu query giao dịch do AI tạo
CREATE INDEX idx_trans_ai ON tTransactions(ai_chat_id) 
INCLUDE (amount, trans_date, source_type) 
WHERE ai_chat_id IS NOT NULL;

-- Index: Tối ưu tính toán khoản nợ (Trả/Thu)
CREATE INDEX idx_trans_debt ON tTransactions(debt_id) 
INCLUDE (amount, trans_date) 
WHERE debt_id IS NOT NULL;

-- Index: Tối ưu query giao dịch theo Danh mục
CREATE INDEX idx_trans_category ON tTransactions(acc_id, ctg_id, trans_date DESC) 
INCLUDE (amount, wallet_id);
GO


-- ======================================================================
-- DỮ LIỆU MẪU: Giao dịch
-- ======================================================================
INSERT INTO tTransactions (acc_id, ctg_id, wallet_id, amount, note, trans_date, with_person, reportable, source_type, event_id, debt_id, goal_id, ai_chat_id) VALUES

-- ── User 1 ──────────────────────────────────────────────────────────────
(1, 1,  1,    50000,      N'Ăn sáng bánh mì',            '2026-02-10 07:30:00', N'Cô Hương',               1, 1, NULL, NULL, NULL, NULL),
(1, 15, 2,    15000000,   N'Lương tháng 2',               '2026-02-05 09:00:00', N'Công ty ABC',            1, 1, NULL, NULL, NULL, NULL),
(1, 9,  1,    500000,     N'Tiền điện tháng 1',           '2026-02-08 14:20:00', N'Điện lực TP.HCM',        1, 1, NULL, NULL, NULL, NULL),
(1, 1,  1,    45000,      N'Cafe',                        '2026-02-10 08:15:00', NULL,                      1, 2, NULL, NULL, NULL, 2),
(1, 1,  2,    250000,     N'Ăn tối gia đình',             '2026-02-03 19:00:00', NULL,                      1, 1, 2,    NULL, NULL, NULL),
(1, 19, 2,    5000000,    N'Cho anh Minh vay khẩn cấp',   '2025-12-10 14:30:00', N'Anh Minh',               1, 1, NULL, 2,    NULL, NULL),

-- ── User 2 ──────────────────────────────────────────────────────────────
(2, 1,  3,    85000,      N'Trà sữa chiều',               '2026-02-09 15:45:00', N'Gongcha',                1, 1, NULL, NULL, NULL, NULL),
(2, 10, 4,    2000000,    N'Mua áo khoác Zara',           '2026-02-07 18:30:00', N'Zara Vincom',            1, 1, NULL, NULL, NULL, NULL),
(2, 5,  3,    300000,     N'Xăng xe máy',                 '2026-02-06 08:15:00', N'Petrolimex',             1, 1, NULL, NULL, NULL, NULL),
(2, 1,  3,    100000,     N'Ăn sáng',                     '2026-02-09 07:30:00', NULL,                      1, 2, NULL, NULL, NULL, 4),
(2, 10, 3,    850000,     N'Mua sắm Vinmart',              '2026-02-09 18:45:00', N'Vinmart',                1, 4, NULL, NULL, NULL, 6),
(2, 16, NULL, 3000000,    N'Đi vay bố mẹ mua iPhone',     '2026-01-20 11:00:00', N'Bố mẹ',                  0, 1, NULL, 4,    3,    NULL),

-- ── User 3 ──────────────────────────────────────────────────────────────
(3, 1,  5,    120000,     N'Cơm trưa văn phòng',          '2026-02-10 12:00:00', N'Quán cơm Phúc Lộc Thọ', 1, 1, NULL, NULL, NULL, NULL),
(3, 12, 6,    500000,     N'Khám răng định kỳ',           '2026-02-08 10:30:00', N'Nha khoa Kim',           1, 1, NULL, NULL, NULL, NULL),
(3, 20, 6,    10000000,   N'Vay bạn thân mua laptop',     '2025-10-15 16:30:00', N'Bạn thân',               0, 1, NULL, 6,    NULL, NULL),
(3, 22, 6,    1000000,    N'Trả nợ bạn thân kỳ này',      '2026-02-15 10:00:00', N'Bạn thân',               1, 1, NULL, 6,    NULL, NULL),

-- ── User 5 ──────────────────────────────────────────────────────────────
(5, 7,  9,    150000,     N'Xem phim Avengers',           '2026-02-09 19:45:00', N'CGV Landmark',           1, 1, NULL, NULL, NULL, NULL),
(5, 16, NULL, 5000000,    N'Rút tiết kiệm về ví',         '2026-02-07 11:00:00', NULL,                      0, 1, NULL, NULL, 7,    NULL),
(5, 5,  9,    200000,     N'Đổ xăng',                     '2026-02-09 17:20:00', N'Petrolimex',             1, 3, NULL, NULL, NULL, 10),
(5, 5,  9,    132600,     N'Xăng RON95 5.2L',             '2026-02-09 17:25:00', N'Petrolimex',             1, 4, NULL, NULL, NULL, 12),
(5, 20, NULL, 50000000,   N'Vay ngân hàng tiền cưới',     '2025-06-01 09:30:00', N'Ngân hàng',              0, 1, NULL, 7,    8,    NULL),

-- ── User 6 ──────────────────────────────────────────────────────────────
(6, 8,  10,   800000,     N'Mua sách lập trình',          '2026-02-08 16:20:00', N'Fahasa',                 1, 1, NULL, NULL, NULL, NULL),
(6, 10, 11,   250000,     N'Mua ốp lưng iPhone',          '2026-02-09 14:10:00', N'Shopee',                 1, 1, NULL, NULL, NULL, NULL),
(6, 7,  10,   350000,     N'Chi phí dự án tốt nghiệp',    '2026-02-05 10:00:00', NULL,                      1, 1, 7,    NULL, NULL, NULL),
(6, 16, NULL, 500000,     N'Góp quỹ ChatGPT Plus',        '2026-02-01 08:00:00', NULL,                      1, 1, NULL, NULL, 31,   NULL),

-- ── User 7 ──────────────────────────────────────────────────────────────
(7, 1,  12,   350000,     N'Ăn tối lẩu',                  '2026-02-09 19:00:00', N'Lẩu Hải Sản Đà Lạt',    1, 1, 8,    NULL, NULL, NULL),
(7, 9,  12,   1200000,    N'Thuê khách sạn 2 đêm',        '2026-02-08 15:30:00', N'Dalat Palace Hotel',     1, 1, 8,    NULL, NULL, NULL),
(7, 20, NULL, 15000000,   N'Vay bố mua MacBook',          '2025-12-05 15:00:00', N'Bố',                     0, 1, NULL, 10,   10,   NULL),

-- ── User 10 ─────────────────────────────────────────────────────────────
(10, 1, 16,   95000,      N'Cafe sáng',                   '2026-02-10 08:00:00', N'Highlands Coffee',       1, 1, NULL, NULL, NULL, NULL),
(10, 10,17,   1500000,    N'Áo thun nam x2, Quần jean',   '2026-02-07 18:00:00', N'Uniqlo',                 1, 4, NULL, NULL, NULL, 20),
(10, 20,NULL, 25000000,   N'Vay mẹ mua nhẫn cưới',       '2025-08-20 11:30:00', N'Mẹ',                     0, 1, NULL, 12,   13,   NULL),
(10, 22,16,   2000000,    N'Trả nợ mẹ kỳ này',           '2026-02-10 09:00:00', N'Mẹ',                     1, 1, NULL, 12,   NULL, NULL),

-- ── User 11 ─────────────────────────────────────────────────────────────
(11, 11,18,   200000,     N'Đóng góp từ thiện',           '2026-02-09 09:30:00', N'Quỹ vì người nghèo',     1, 1, NULL, NULL, NULL, NULL),
(11, 15,18,   18000000,   N'Lương tháng 2',               '2026-02-05 10:00:00', N'Công ty Tech Innovation', 1, 1, NULL, NULL, NULL, NULL),
(11, 7, 18,   440000,     N'2 vé phim, bắp, nước',        '2026-02-09 22:00:00', N'CGV Landmark 81',        1, 4, NULL, NULL, NULL, 22),
(11, 8, NULL, 8000000,    N'Góp quỹ khóa học AWS',        '2026-02-10 10:00:00', NULL,                      1, 1, NULL, NULL, 27,   NULL),

-- ── User 15 ─────────────────────────────────────────────────────────────
(15, 8, NULL, 3500000,    N'Học phí học kỳ 1',            '2026-02-06 13:00:00', N'Trường ĐH FPT',          1, 1, NULL, NULL, 19,   NULL),
(15, 8, NULL, 3500000,    N'Học phí kỳ 2 - ĐH FPT',       '2026-02-06 13:05:00', N'ĐH FPT',                 1, 4, NULL, NULL, 19,   26),
(15, 21,23,   12000000,   N'Cho bạn học vay học Thạc sĩ', '2026-01-05 13:20:00', N'Bạn học',                1, 1, NULL, 17,   NULL, NULL),

-- ── User 17 ─────────────────────────────────────────────────────────────
(17, 8, 26,   350000,     N'Sách lập trình',              '2026-02-08 16:45:00', NULL,                      1, 3, NULL, NULL, NULL, 28),
(17, 16,NULL, 10000000,   N'Góp quỹ đầu tư chứng khoán', '2026-02-01 09:00:00', NULL,                      0, 1, NULL, NULL, 21,   NULL),
(17, 20,26,   100000000,  N'Vay ngân hàng khởi nghiệp',  '2024-06-15 09:00:00', N'Ngân hàng',              0, 1, NULL, 18,   NULL, NULL),

-- ── User 20 ─────────────────────────────────────────────────────────────
(20, 9, 13,   2500000,    N'Đặt vé máy bay đi Phú Quốc', '2026-02-09 11:20:00', N'VietJet Air',            1, 1, 21,   NULL, NULL, NULL),
(20, 9, 13,   2700000,    N'Vé máy bay HN - Đà Lạt',     '2026-02-09 11:25:00', N'VietJet Air',            1, 4, NULL, NULL, NULL, 32),
(20, 9, 14,   4000000,    N'Đặt khách sạn Đà Lạt',       '2026-02-08 10:00:00', N'Agoda',                  1, 1, 21,   NULL, NULL, NULL),
(20, 16,NULL, 5000000,    N'Góp quỹ mua máy ảnh',        '2026-02-05 08:00:00', NULL,                      1, 1, NULL, NULL, 24,   NULL),
(20, 20,13,   18000000,   N'Vay bạn thân mua máy ảnh',   '2025-09-10 11:00:00', N'Bạn thân',               0, 1, NULL, 20,   NULL, NULL);
GO

-- ======================================================================
-- 17. BẢNG THÔNG BÁO (1-N với tAccounts)
-- ======================================================================
CREATE TABLE tNotifications (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)     

	-- LOẠI THÔNG BÁO (Sử dụng TINYINT để tối ưu hiệu năng)
    -- 1: TRANSACTION (Giao dịch/Biến động số dư)
    -- 2: SAVING      (Mục tiêu tiết kiệm/Quỹ)
    -- 3: BUDGET      (Cảnh báo ngân sách/Vượt hạn mức)
    -- 4: SYSTEM      (Hệ thống/Cập nhật/Bảo mật)
    -- 5: CHAT_AI     (Thông báo từ trợ lý AI)
    -- 6: WALLETS     (Thông báo liên quan đến ví/số dư âm)
    -- 7: EVENTS      (Sự kiện/Lịch trình)
    -- 8: DEBT_LOAN   (Nhắc nợ/Thu nợ)
    -- 9: REMINDER    (Nhắc nhở chung/Daily nhắc ghi chép)
    notify_type TINYINT NOT NULL, 

    -- ID CỦA ĐỐI TƯỢNG LIÊN QUAN (Tùy theo notify_type)
    -- Ví dụ: Nếu type = 1 thì đây là ID của tTransactions
    -- Nếu type = 6 thì đây là ID của tWallets
    related_id BIGINT NULL,

	title NVARCHAR(100) NULL,                    -- Tiêu đề ngắn gọn (VD: "Cảnh báo ngân sách")
    content NVARCHAR(500) NOT NULL,              -- Nội dung chi tiết (VD: "Bạn đã xài hết 50% tiền Ăn uống")
    scheduled_time DATETIME DEFAULT GETDATE(),   -- Thời điểm thông báo (ngay hoặc hẹn lịch)
    notify_sent BIT DEFAULT 0,                       -- 0: Chưa gửi Push | 1: Đã gửi Push
    notify_read BIT DEFAULT 0,                       -- 0: Chưa đọc | 1: Đã đọc  
    created_at DATETIME DEFAULT GETDATE(),       -- Ngày tạo thông báo
	
    -- CONSTRAINTS
    CONSTRAINT CHK_Notify_Type CHECK (notify_type BETWEEN 1 AND 9),
    CONSTRAINT FK_Notifications_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id)
);
GO

-- Index: Tối ưu Worker quét thông báo cần gửi
CREATE INDEX idx_notify_worker ON tNotifications(scheduled_time, notify_sent) WHERE notify_sent = 0;

-- Index: Tối ưu load thông báo cho User UI
CREATE INDEX idx_notify_ui ON tNotifications(acc_id, notify_read, created_at DESC) INCLUDE (title, content, notify_type, related_id);

-- Index: Tối ưu load thông báo mới nhất
CREATE INDEX idx_notify_latest ON tNotifications(acc_id, created_at DESC) INCLUDE (notify_read, title, content);
GO

-- ======================================================================
-- DỮ LIỆU MẪU: Thông báo
-- ======================================================================
INSERT INTO tNotifications (acc_id, notify_type, related_id, title, content, scheduled_time, notify_sent, notify_read) VALUES

-- type=1: Giao dịch lớn (đã đọc)
(1,  1, 2,    N'Giao dịch mới',       N'Đã ghi nhận thu nhập 15,000,000đ - Lương tháng 2 vào ví Vietcombank',       '2026-02-05 09:00:05', 1, 1),
(11, 1, 23,   N'Giao dịch mới',       N'Đã ghi nhận thu nhập 18,000,000đ - Lương tháng 2 vào ví TPBank',            '2026-02-05 10:00:05', 1, 1),
(2,  1, 12,   N'Giao dịch mới',       N'Đã ghi nhận chi tiêu 3,000,000đ - Đi vay bố mẹ mua iPhone vào ví TCB',     '2026-01-20 11:00:10', 1, 1),

-- type=2: Mục tiêu tiết kiệm (mix đọc/chưa)
(5,  2, 7,    N'Mục tiêu tiến triển', N'Bạn đã đạt 50% mục tiêu "Mua xe máy SH". Còn 45,000,000đ nữa là hoàn thành!','2026-02-07 09:00:00', 1, 0),
(10, 2, 13,   N'Nhắc mục tiêu',       N'Mục tiêu "Mua nhẫn cưới" sắp đến hạn (30/11/2026). Còn thiếu 15,000,000đ', '2026-02-10 08:00:00', 1, 0),
(6,  2, 31,   N'Mục tiêu tiến triển', N'Quỹ ChatGPT Plus đã đạt 29%. Cố lên! Còn 8,500,000đ nữa.',                  '2026-02-08 10:00:00', 1, 1),

-- type=3: Cảnh báo ngân sách (mix)
(2,  3, 1,    N'Cảnh báo ngân sách',  N'Bạn đã chi 80% ngân sách Ăn uống tháng 2. Hãy cân nhắc chi tiêu!',          '2026-02-09 20:00:00', 1, 1),
(6,  3, 4,    N'Vượt ngân sách',      N'Bạn đã vượt 120% ngân sách Ăn uống + Giải trí. Tổng chi: 2,400,000đ/2tr',   '2026-02-10 18:00:00', 1, 0),
(10, 3, 10,   N'Cảnh báo ngân sách',  N'Đã chi 75% tổng ngân sách tháng 2 (6,000,000đ/8,000,000đ).',                 '2026-02-09 22:00:00', 1, 0),

-- type=4: Hệ thống
(1,  4, NULL, N'Cập nhật hệ thống',   N'SmartMoney v1.1 vừa ra mắt! Tính năng mới: Báo cáo nâng cao và xuất PDF',   '2026-02-01 07:00:00', 1, 1),
(15, 4, NULL, N'Bảo mật tài khoản',   N'Phát hiện đăng nhập mới từ thiết bị lạ lúc 02:30. Hãy đổi mật khẩu ngay',  '2026-02-08 02:35:00', 1, 0),

-- type=5: AI Chat
(3,  5, 7,    N'Phân tích AI',        N'AI đã phân tích xong chi tiêu tháng 2. Bạn đang chi nhiều hơn 18% tháng trước','2026-02-10 20:00:10', 1, 0),
(10, 5, 18,   N'AI nhắc nhở',         N'Lời nhắc: "Trả nợ anh Tuấn" vào ngày mai 15/02/2026 lúc 9:00 sáng',         '2026-02-14 21:00:00', 0, 0),

-- type=6: Ví số dư thấp
(2,  6, 3,    N'Số dư ví thấp',       N'Ví MoMo còn 250,000đ - dưới mức cảnh báo 500,000đ. Hãy nạp thêm tiền',      '2026-02-10 15:00:00', 1, 0),
(6,  6, 11,   N'Số dư ví thấp',       N'Ví VNPay còn 150,000đ. Bạn có muốn chuyển tiền từ MB Bank sang không?',      '2026-02-09 22:00:00', 1, 1),

-- type=7: Sự kiện sắp tới (hẹn lịch tương lai)
(3,  7, 4,    N'Sự kiện sắp tới',     N'Sinh nhật 25 tuổi còn 33 ngày nữa (15/03/2026). Đừng quên lên kế hoạch!',   '2026-02-10 08:00:00', 1, 0),
(20, 7, 21,   N'Sự kiện sắp tới',     N'Kỳ nghỉ hè gia đình còn 141 ngày (01/07/2026). Ngân sách: 10,000,000đ',     '2026-02-15 08:00:00', 0, 0),

-- type=8: Nhắc nợ (hẹn lịch tương lai)
(1,  8, 2,    N'Nhắc khoản thu',      N'Khoản cho anh Minh vay 3,000,000đ đến hạn thu 31/03/2026. Hãy liên hệ!',    '2026-02-20 09:00:00', 0, 0),
(5,  8, 7,    N'Nhắc khoản nợ',       N'Khoản vay cưới còn 40,000,000đ. Kỳ thanh toán tiếp theo 01/03/2026',         '2026-02-25 09:00:00', 0, 0),

-- type=9: Nhắc ghi chép
(7,  9, NULL, N'Nhắc ghi chép',       N'Bạn chưa ghi chép chi tiêu hôm nay! Hãy dành 2 phút cập nhật sổ chi tiêu 📝','2026-02-10 21:00:00', 1, 1),
(17, 9, NULL, N'Tổng kết tuần',       N'Tuần này bạn đã chi 2,350,000đ. Chi tiêu cao nhất: Giáo dục (350,000đ).',    '2026-02-10 20:00:00', 1, 0);
GO
--------------
-- Thêm notifications cho user 6 (minh.pham) — đủ 9 loại để test
INSERT INTO tNotifications (acc_id, notify_type, related_id, title, content, scheduled_time, notify_sent, notify_read)
VALUES
-- Type 1: TRANSACTION
(6, 1, NULL, N'Giao dịch mới',        N'Đã ghi nhận thu nhập 12,000,000đ - Lương tháng 3 vào ví MB Bank',               '2026-03-05 09:00:05', 1, 1),
-- Type 2: SAVING
(6, 2, 31,   N'Mục tiêu tiến triển',  N'Quỹ ChatGPT Plus & Claude Pro đã đạt 35%. Cố lên! Còn thiếu khoảng 7,800,000đ', '2026-03-05 09:00:10', 1, 0),
-- Type 3: BUDGET (từ check-now vừa tạo — nhắc lại dạng seed)
(6, 3, 21,   N'Vượt quá ngân sách!',  N'Bạn đã chi vượt 165% ngân sách Ăn uống tháng 3. Tổng chi: 1,650,000đ/1,000,000đ', '2026-03-13 10:40:50', 1, 0),
(6, 3, 22,   N'Cảnh báo ngân sách',   N'Bạn đã chi 87% ngân sách Giải trí tháng 3. Hãy cân nhắc chi tiêu!',              '2026-03-13 10:40:50', 1, 0),
-- Type 4: SYSTEM
(6, 4, NULL, N'Cập nhật hệ thống',    N'SmartMoney v1.1 vừa ra mắt! Tính năng mới: Báo cáo nâng cao và xuất PDF',        '2026-02-01 07:00:00', 1, 1),
-- Type 5: CHAT_AI (không có AI conversation của user 6 → related_id=NULL)
(6, 5, NULL, N'Phân tích AI',         N'AI đã phân tích chi tiêu tháng 3. Bạn chi Ăn uống nhiều hơn 22% tháng trước',   '2026-03-13 20:00:00', 1, 0),
-- Type 6: WALLETS
(6, 6, 11,   N'Số dư ví thấp',        N'Ví VNPay còn 900,000đ - gần mức cảnh báo. Hãy chú ý chi tiêu!',                 '2026-03-12 08:00:00', 1, 1),
-- Type 7: EVENTS
(6, 7, NULL, N'Sự kiện sắp tới',      N'Sinh nhật bạn thân còn 2 ngày nữa (15/03/2026). Đừng quên chuẩn bị quà!',       '2026-03-13 08:00:00', 0, 0),
-- Type 8: DEBT_LOAN
(6, 8, 6,    N'Nhắc khoản nợ',        N'Khoản vay bạn thân mua laptop còn 9,000,000đ. Hạn trả tiếp theo: 15/03/2026',   '2026-03-01 09:00:00', 1, 0),
-- Type 9: REMINDER
(6, 9, NULL, N'Nhắc ghi chép',        N'Bạn chưa ghi chép chi tiêu hôm nay! Hãy dành 2 phút cập nhật sổ chi tiêu 📝',   '2026-03-13 21:00:00', 0, 0);
GO
--------------

-- ======================================================================
-- 18. BẢNG GIAO DỊCH ĐỊNH KỲ/HÓA ĐƠN (1-N với tAccounts)
-- ======================================================================
-- THAY ĐỔI SO VỚI PHIÊN BẢN CŨ:
--   ❌ Bỏ cột trans_type  → ctg_id JOIN tCategories đã xác định loại giao dịch
--   ✅ Thêm cột debt_id   → Liên kết với tDebts khi là giao dịch nợ định kỳ
-- ======================================================================
CREATE TABLE tPlannedTransactions (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),

    -- FOREIGN KEYS
    acc_id    INT NOT NULL,  -- FK -> tAccounts (N-1)
    wallet_id INT NOT NULL,  -- FK -> tWallets (N-1)
    ctg_id    INT NOT NULL,  -- FK -> tCategories (N-1)
    --   Bills menu     → chỉ hiện danh mục CHI
    --   Recurring menu → hiện tất cả Thu/Chi/Vay-Nợ
    debt_id   INT NULL,      -- FK -> tDebts (N-1) | NULL = không liên quan nợ
    --   Chỉ điền khi ctg là: Cho vay (19) | Đi vay (20) | Thu nợ (21) | Trả nợ (22)
    --   Flutter: chỉ hiện dropdown "Chọn khoản nợ" khi user chọn đúng 4 category trên

    -- DATA COLUMNS
    note   NVARCHAR(500)  NULL,       -- Tên hóa đơn hoặc ghi chú
    amount DECIMAL(18,2)  NOT NULL,   -- Số tiền mỗi kỳ

    -- Phân loại nghiệp vụ
    -- 1: Bill      (Chi - số tiền THAY ĐỔI - cần duyệt tay trước khi tạo Transaction)
    -- 2: Recurring (Thu/Chi/Nợ - số tiền CỐ ĐỊNH - tự động tạo Transaction)
    plan_type TINYINT NOT NULL,

    -- Cấu hình lặp lại
    repeat_type     TINYINT NOT NULL,        -- 0: Không lặp | 1: Ngày | 2: Tuần | 3: Tháng | 4: Năm
    repeat_interval INT DEFAULT 1 NOT NULL,  -- Mỗi "1" ngày / "2" tuần / ...
    /*  Bitmask repeat_on_day_val (chỉ dùng khi repeat_type = 2 - Tuần):
        CN=1 | T2=2 | T3=4 | T4=8 | T5=16 | T6=32 | T7=64
        VD: T2+T6 = 2+32 = 34  |  T2→T6 = 2+4+8+16+32 = 62              */
    repeat_on_day_val INT NULL,

    begin_date       DATE NOT NULL,  -- Ngày bắt đầu hiệu lực
    next_due_date    DATE NOT NULL,  -- Ngày đến hạn tiếp theo (Scheduler quét cột này)
    last_executed_at DATE NULL,      -- Ngày thực hiện gần nhất (tránh duyệt trùng kỳ)
    end_date         DATE NULL,      -- NULL = lặp lại trọn đời

    active     BIT      DEFAULT 1        NOT NULL,  -- 1: Đang áp dụng | 0: Đã kết thúc
    created_at DATETIME DEFAULT GETDATE() NOT NULL,  -- Ngày tạo (admin sort)

    -- CONSTRAINTS
    CONSTRAINT CHK_Plan_Amount   CHECK (amount > 0),
    CONSTRAINT CHK_Plan_Repeat   CHECK (repeat_type BETWEEN 0 AND 4),
    CONSTRAINT CHK_Plan_Interval CHECK (repeat_interval >= 1),
    CONSTRAINT CHK_Plan_Dates    CHECK (end_date IS NULL OR end_date >= begin_date),
    CONSTRAINT CHK_Plan_Type     CHECK (plan_type IN (1, 2)),
    CONSTRAINT CHK_Plan_NextDue  CHECK (next_due_date >= begin_date),

    CONSTRAINT FK_Plan_Acc      FOREIGN KEY (acc_id)    REFERENCES tAccounts(id),
    CONSTRAINT FK_Plan_Wallet   FOREIGN KEY (wallet_id) REFERENCES tWallets(id)    ON DELETE CASCADE,
    CONSTRAINT FK_Plan_Category FOREIGN KEY (ctg_id)    REFERENCES tCategories(id) ON DELETE CASCADE,
    CONSTRAINT FK_Plan_Debt     FOREIGN KEY (debt_id)   REFERENCES tDebts(id)
);
GO

-- Index: Scheduler quét hóa đơn/giao dịch đến hạn
CREATE INDEX idx_planned_scan ON tPlannedTransactions(acc_id, next_due_date, active)
    INCLUDE (note, amount, plan_type, wallet_id, debt_id);
GO

-- ======================================================================
-- DỮ LIỆU MẪU: tPlannedTransactions
-- ======================================================================
-- PHÂN LOẠI:
--   BILLS (plan_type=1)     : Số tiền THAY ĐỔI mỗi kỳ, user duyệt tay
--                             VD: Tiền điện, nước, gas, y tế...
--   RECURRING (plan_type=2) : Số tiền CỐ ĐỊNH, Scheduler tự tạo Transaction
--                             VD: Internet, Netflix, lương, trả góp...
--
-- MAPPING debt_id (tDebts theo thứ tự INSERT):
--   id=1  acc=1  Vay mua xe máy SH (VPBank)
--   id=2  acc=1  Cho vay Anh Minh
--   id=3  acc=2  Cho vay Bạn A
--   id=4  acc=2  Vay mua iPhone (Bố Mẹ)
--   id=5  acc=3  Cho vay Em trai (học phí)
--   id=6  acc=3  Vay mua laptop (Bạn thân)
--   id=7  acc=5  Vay cưới (Ngân hàng ACB)
--   id=8  acc=5  Cho vay mua xe (Đồng nghiệp Hưng)
--   id=9  acc=6  Cho vay đi du lịch (Chị gái)
--   id=10 acc=7  Vay mua MacBook (Bố)
--   id=11 acc=8  Cho vay tiền nhà (Bạn cùng phòng)
--   id=12 acc=10 Vay mua nhẫn cưới (Mẹ)
--   id=13 acc=10 Cho vay sửa xe (Em họ Khoa)
-- ======================================================================
GO

INSERT INTO tPlannedTransactions (
    acc_id, wallet_id, ctg_id, debt_id,
    note, amount, plan_type,
    repeat_type, repeat_interval, repeat_on_day_val,
    begin_date, next_due_date, last_executed_at, end_date, active
) VALUES

-- ══════════════════════════════════════════════════════════════════════
-- NHÓM 1: BILLS (plan_type=1) — Số tiền THAY ĐỔI, duyệt tay
-- ══════════════════════════════════════════════════════════════════════

-- ── Hóa đơn điện ──────────────────────────────────────────────────────
(1,  2,  28, NULL, N'Hóa đơn tiền điện EVN',
 520000,  1, 3, 1, NULL,
 '2026-01-08', '2026-03-08', '2026-02-08', NULL, 1),
-- 💡 Dao động 480k-550k tùy mức tiêu thụ

(2,  4,  28, NULL, N'Hóa đơn tiền điện (Căn hộ)',
 680000,  1, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),
-- 💡 Căn hộ lớn dao động 650k-750k

(6,  10, 28, NULL, N'Hóa đơn điện (Nhà riêng)',
 450000,  1, 3, 1, NULL,
 '2026-01-20', '2026-03-20', '2026-02-20', NULL, 1),
-- 💡 Nhà nhỏ dao động 400k-500k

-- ── Hóa đơn nước ──────────────────────────────────────────────────────
(1,  2,  32, NULL, N'Hóa đơn tiền nước Cấp nước TP',
 85000,   1, 3, 1, NULL,
 '2026-01-10', '2026-03-10', '2026-02-10', NULL, 1),
-- 💡 Dao động 70k-100k

(3,  6,  32, NULL, N'Tiền nước hàng tháng',
 120000,  1, 3, 1, NULL,
 '2026-01-12', '2026-03-12', '2026-02-12', NULL, 1),
-- 💡 Gia đình đông người dao động 100k-150k

-- ── Hóa đơn gas ───────────────────────────────────────────────────────
(2,  3,  30, NULL, N'Hóa đơn gas Petrolimex',
 320000,  1, 3, 1, NULL,
 '2026-01-15', '2026-03-15', '2026-02-15', NULL, 1),
-- 💡 Thay bình không đều, dao động 300k-350k

(11, 18, 30, NULL, N'Gas nấu ăn',
 280000,  1, 3, 1, NULL,
 '2026-01-18', '2026-03-18', '2026-02-18', NULL, 1),
-- 💡 Dao động 250k-350k

-- ── Chi phí y tế ──────────────────────────────────────────────────────
(3,  5,  38, NULL, N'Khám sức khỏe định kỳ',
 650000,  1, 4, 1, NULL,
 '2026-01-15', '2027-01-15', '2026-01-15', NULL, 1),
-- 💡 Hàng năm, dao động tùy gói khám

(8,  21, 38, NULL, N'Chi phí y tế gia đình',
 1200000, 1, 3, 1, NULL,
 '2026-02-01', '2026-03-01', '2026-02-01', '2026-06-30', 1),
-- 💡 Không ổn định, có tháng 0đ có tháng vài triệu

-- ══════════════════════════════════════════════════════════════════════
-- NHÓM 2: RECURRING (plan_type=2) — Số tiền CỐ ĐỊNH, tự động
-- ══════════════════════════════════════════════════════════════════════

-- ── Internet / TV ─────────────────────────────────────────────────────
(1,  2,  31, NULL, N'Internet VNPT - Gói 200Mbps',
 280000,  2, 3, 1, NULL,
 '2026-01-15', '2026-03-15', '2026-02-15', NULL, 1),

(2,  4,  31, NULL, N'Internet FPT - Gói 300Mbps',
 350000,  2, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),

(6,  10, 31, NULL, N'Internet Viettel - Gói 100Mbps',
 220000,  2, 3, 1, NULL,
 '2026-01-20', '2026-03-20', '2026-02-20', NULL, 1),

(11, 18, 34, NULL, N'Truyền hình K+ Premium',
 180000,  2, 3, 1, NULL,
 '2026-01-12', '2026-03-12', '2026-02-12', NULL, 1),

-- ── Subscription ──────────────────────────────────────────────────────
(11, 18, 25, NULL, N'Netflix Premium (Gói gia đình)',
 260000,  2, 3, 1, NULL,
 '2026-01-12', '2026-03-12', '2026-02-12', NULL, 1),

(7,  12, 25, NULL, N'Spotify Premium',
 59000,   2, 3, 1, NULL,
 '2026-01-08', '2026-03-08', '2026-02-08', NULL, 1),

(3,  6,  25, NULL, N'YouTube Premium',
 79000,   2, 3, 1, NULL,
 '2026-01-10', '2026-03-10', '2026-02-10', NULL, 1),

(17, 26, 25, NULL, N'ChatGPT Plus',
 440000,  2, 3, 1, NULL,
 '2026-01-15', '2026-03-15', '2026-02-15', NULL, 1),
-- 💡 $20/tháng ~ 440k VND

-- ── Gói cước di động ──────────────────────────────────────────────────
(6,  10, 29, NULL, N'Gói cước Viettel - V90',
 90000,   2, 3, 1, NULL,
 '2026-01-20', '2026-03-20', '2026-02-20', NULL, 1),

(1,  2,  29, NULL, N'Gói cước VinaPhone - VD149',
 149000,  2, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),

(11, 18, 29, NULL, N'Gói cước MobiFone - MAX200',
 200000,  2, 3, 1, NULL,
 '2026-01-10', '2026-03-10', '2026-02-10', NULL, 1),

-- ── Thuê nhà ──────────────────────────────────────────────────────────
(2,  4,  34, NULL, N'Tiền thuê căn hộ Vinhomes',
 8500000, 2, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),

(9,  15, 34, NULL, N'Tiền thuê trọ',
 3200000, 2, 3, 1, NULL,
 '2026-01-08', '2026-03-08', '2026-02-08', '2026-12-31', 1),

-- ── Bảo hiểm ──────────────────────────────────────────────────────────
(3,  6,  2,  NULL, N'Phí bảo hiểm nhân thọ Prudential',
 8400000, 2, 4, 1, NULL,
 '2026-01-20', '2027-01-20', '2026-01-20', '2030-01-20', 1),
-- 💡 Hàng năm

(1,  2,  2,  NULL, N'Bảo hiểm xe ô tô',
 6500000, 2, 4, 1, NULL,
 '2026-02-01', '2027-02-01', '2026-02-01', NULL, 1),

-- ── Học phí ───────────────────────────────────────────────────────────
(15, 23, 8,  NULL, N'Học phí Đại học FPT - Học kỳ Spring',
 16500000, 2, 4, 6, NULL,
 '2026-02-06', '2027-02-06', '2026-02-06', '2028-06-30', 1),
-- 💡 Mỗi 6 tháng/lần

(12, 19, 8,  NULL, N'Học phí THPT Chuyên',
 4500000, 2, 4, 1, NULL,
 '2026-01-15', '2027-01-15', '2026-01-15', '2029-06-30', 1),

-- ── Lương / Thu nhập cố định ──────────────────────────────────────────
(1,  2,  15, NULL, N'Lương tháng - Công ty ABC Tech',
 15000000, 2, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),

(11, 18, 15, NULL, N'Lương tháng - Ngân hàng XYZ',
 28000000, 2, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),

(17, 26, 15, NULL, N'Lương freelance',
 12000000, 2, 3, 1, NULL,
 '2026-01-10', '2026-03-10', '2026-02-10', NULL, 1),

(3,  6,  16, NULL, N'Thu cổ tức đầu tư chứng khoán',
 2500000, 2, 3, 1, NULL,
 '2026-01-28', '2026-03-28', '2026-02-28', NULL, 1),

-- ── Trả nợ định kỳ (debt_id BẮT BUỘC điền) ───────────────────────────
-- acc=5, ctg=22(Trả nợ) → debt_id=7 (Vay cưới Ngân hàng ACB)
(5,  9,  22, 7, N'Trả góp vay cưới - Ngân hàng Vietcombank',
 2000000, 2, 3, 1, NULL,
 '2025-07-01', '2026-03-01', '2026-02-01', '2027-12-31', 1),

-- acc=3, ctg=22(Trả nợ) → debt_id=6 (Vay mua laptop - Bạn thân)
(3,  6,  22, 6, N'Trả nợ bạn thân - Vay mua laptop',
 1000000, 2, 3, 1, NULL,
 '2025-11-15', '2026-03-15', '2026-02-15', '2026-09-15', 1),

-- acc=10, ctg=22(Trả nợ) → debt_id=12 (Vay mua nhẫn cưới - Mẹ)
(10, 16, 22, 12, N'Trả góp mua xe máy Honda Vision',
 3500000, 2, 3, 1, NULL,
 '2025-08-01', '2026-03-01', '2026-02-01', '2027-08-01', 1),

-- acc=6, ctg=22(Trả nợ) → NULL vì user 6 chưa có khoản vay trong tDebts
-- ⚠️ Cần bổ sung debt row cho user 6 nếu muốn liên kết đầy đủ
(6,  10, 22, NULL, N'Trả góp mua iPhone 15 Pro',
 8000000, 2, 3, 1, NULL,
 '2025-10-01', '2026-03-01', '2026-02-01', '2026-10-01', 1),

-- ── Lặp lại hàng tuần (Bitmask) ───────────────────────────────────────
-- T2+T6 = 2+32 = 34
(7,  12, 1,  NULL, N'Cafe sáng đầu tuần (T2, T6)',
 50000,   2, 2, 1, 34,
 '2026-01-05', '2026-02-16', '2026-02-13', NULL, 1),

-- T2→T6 = 2+4+8+16+32 = 62
(1,  1,  1,  NULL, N'Ăn trưa văn phòng (T2-T6)',
 70000,   2, 2, 1, 62,
 '2026-02-03', '2026-02-14', '2026-02-13', NULL, 1),

-- ── Lặp lại hàng ngày ─────────────────────────────────────────────────
(5,  9,  1,  NULL, N'Ăn sáng hàng ngày',
 40000,   2, 1, 1, NULL,
 '2026-02-01', '2026-02-11', '2026-02-10', NULL, 1),

-- ── Tạm dừng (active=0) ───────────────────────────────────────────────
(2,  3,  10, NULL, N'Mua sắm Shopee định kỳ',
 500000,  2, 3, 1, NULL,
 '2025-10-01', '2026-03-01', '2026-02-01', NULL, 0);
-- ⏸️ Tạm dừng

GO

-- ======================================================================
-- THỐNG KÊ
-- ======================================================================
-- ✅ BILLS (plan_type=1): 9 rows
--    - Điện: 3 | Nước: 2 | Gas: 2 | Y tế: 2
--
-- ✅ RECURRING (plan_type=2): 31 rows
--    - Internet/TV: 4 | Subscription: 4 | Mobile: 3
--    - Thuê nhà: 2 | Bảo hiểm: 2 | Học phí: 2
--    - Lương/Thu: 4 | Trả nợ: 4 (3 có debt_id, 1 NULL)
--    - Lặp tuần: 2 | Lặp ngày: 1 | Tạm dừng: 1
--
-- ✅ debt_id được điền: 3 rows (trả góp vay cưới, vay laptop, nhẫn cưới)
-- ⚠️ debt_id=NULL:      1 row  (iPhone 15 Pro - user 6 chưa có debt row)
--
-- TOTAL: 40 planned transactions
-- ======================================================================

PRINT '✅ Đã chèn 40 rows vào tPlannedTransactions (đã bỏ trans_type, thêm debt_id)';
PRINT '   - Bills (thay đổi, duyệt tay): 9 rows';
PRINT '   - Recurring (cố định, tự động): 31 rows';
PRINT '   - Trong đó có debt_id: 3 rows trả nợ định kỳ';
GO

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ======================================================================
-- BUDGET TEST DATA v2 — User 6 (minh.pham@gmail.com)
-- Wallet: MB Bank (id=10), VNPay (id=11)
-- ======================================================================

-- BƯỚC 1: GIAO DỊCH THÁNG 3/2026
-- ======================================================================
INSERT INTO tTransactions (acc_id, ctg_id, wallet_id, amount, note, trans_date, with_person, reportable, source_type, event_id, debt_id, goal_id, ai_chat_id)
VALUES
-- Ăn uống (ctg=1) — Tổng: 1,650,000
(6, 1, 10,  85000,    N'Bún bò buổi sáng',           '2026-03-02 07:30:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 1, 10,  120000,   N'Cơm trưa văn phòng',          '2026-03-04 12:00:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 1, 11,  75000,    N'Bánh mì ốp la',               '2026-03-05 07:45:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 1, 10,  350000,   N'Ăn tối bạn bè',               '2026-03-07 19:30:00', N'Nhóm bạn ĐH',   1, 1, NULL, NULL, NULL, NULL),
(6, 1, 10,  95000,    N'Phở gà',                      '2026-03-10 11:30:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 1, 11,  180000,   N'Trà sữa và snack',            '2026-03-11 15:00:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 1, 10,  145000,   N'Cơm chiều + chè',             '2026-03-12 18:00:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 1, 10,  600000,   N'Tiệc sinh nhật bạn thân',     '2026-03-15 20:00:00', N'Nhà hàng',       1, 1, NULL, NULL, NULL, NULL),
-- Giải trí (ctg=7) — Tổng: 870,000
(6, 7, 10,  240000,   N'2 vé xem phim + bắp nước',   '2026-03-03 19:00:00', N'CGV Crescent',   1, 1, NULL, NULL, NULL, NULL),
(6, 7, 11,  180000,   N'Karaoke nhóm bạn',            '2026-03-08 21:00:00', N'Nhóm bạn',       1, 1, NULL, NULL, NULL, NULL),
(6, 7, 10,  450000,   N'Mua game Steam sale',         '2026-03-09 14:00:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
-- Mua sắm (ctg=10) — Tổng: 1,280,000
(6, 10, 10, 320000,   N'Mua quần áo Uniqlo',          '2026-03-06 15:30:00', N'Uniqlo',         1, 1, NULL, NULL, NULL, NULL),
(6, 10, 11, 180000,   N'Đồ dùng văn phòng phẩm',      '2026-03-08 10:00:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 10, 10, 780000,   N'Giày thể thao mới',           '2026-03-12 16:00:00', N'Nike Store',     1, 1, NULL, NULL, NULL, NULL),
-- Di chuyển (ctg=5) — Tổng: 560,000
(6, 5,  10, 85000,    N'Xăng xe đầy bình',            '2026-03-03 08:00:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 5,  11, 45000,    N'Grab đi làm',                 '2026-03-05 08:30:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 5,  10, 65000,    N'Xăng giữa tháng',             '2026-03-10 17:00:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 5,  11, 365000,   N'Vé xe khách về quê cuối tuần','2026-03-13 06:00:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
-- Giáo dục (ctg=8) — Tổng: 1,350,000
(6, 8,  10, 850000,   N'Khóa học React Native Udemy', '2026-03-01 20:00:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 8,  10, 350000,   N'Mua sách Clean Code',         '2026-03-07 09:00:00', N'Fahasa',         1, 1, NULL, NULL, NULL, NULL),
(6, 8,  11, 150000,   N'Phí thi chứng chỉ tiếng Anh', '2026-03-09 14:30:00', NULL,             1, 1, NULL, NULL, NULL, NULL),
-- Sức khỏe (ctg=12) — Tổng: 680,000
(6, 12, 10, 250000,   N'Khám sức khỏe định kỳ',       '2026-03-04 09:00:00', N'Bệnh viện FV',  1, 1, NULL, NULL, NULL, NULL),
(6, 12, 11, 180000,   N'Mua thuốc dự phòng',          '2026-03-06 18:00:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 12, 10, 250000,   N'Đăng ký gym 1 tháng',         '2026-03-01 10:00:00', N'California Gym', 1, 1, NULL, NULL, NULL, NULL),
-- Hoá đơn & Tiện ích (ctg=9) — Tổng: 790,000
(6, 9,  10, 350000,   N'Tiền điện tháng 3',           '2026-03-03 10:00:00', N'EVN TP.HCM',     1, 1, NULL, NULL, NULL, NULL),
(6, 9,  10, 220000,   N'Internet Viettel tháng 3',    '2026-03-05 09:00:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
(6, 9,  11, 220000,   N'Tiền nước tháng 3',           '2026-03-05 09:30:00', NULL,              1, 1, NULL, NULL, NULL, NULL),
-- Thu nhập (ctg=15 — type THU, không tính vào budget)
(6, 15, 10, 12000000, N'Lương tháng 3/2026',          '2026-03-05 09:00:00', N'Công ty FPT',    1, 1, NULL, NULL, NULL, NULL);
GO

-- BƯỚC 2: BUDGETS + CATEGORIES (dùng IDENTITY để lấy ID tự động)
-- ======================================================================
DECLARE @A INT, @B INT, @C INT, @D INT, @E INT, @F INT;

-- Scenario A: Ăn uống — 1,650,000 / 1,000,000 = 165% → VƯỢT
INSERT INTO tBudgets (acc_id, wallet_id, amount, begin_date, end_date, all_categories, repeating)
VALUES (6, NULL, 1000000, '2026-03-01', '2026-03-31', 0, 0);
SET @A = SCOPE_IDENTITY();
INSERT INTO tBudgetCategories (budget_id, ctg_id) VALUES (@A, 1);

-- Scenario B: Giải trí — 870,000 / 1,000,000 = 87% → CẢNH BÁO
INSERT INTO tBudgets (acc_id, wallet_id, amount, begin_date, end_date, all_categories, repeating)
VALUES (6, NULL, 1000000, '2026-03-01', '2026-03-31', 0, 0);
SET @B = SCOPE_IDENTITY();
INSERT INTO tBudgetCategories (budget_id, ctg_id) VALUES (@B, 7);

-- Scenario C: Di chuyển — 560,000 / 1,000,000 = 56% → AN TOÀN
INSERT INTO tBudgets (acc_id, wallet_id, amount, begin_date, end_date, all_categories, repeating)
VALUES (6, NULL, 1000000, '2026-03-01', '2026-03-31', 0, 0);
SET @C = SCOPE_IDENTITY();
INSERT INTO tBudgetCategories (budget_id, ctg_id) VALUES (@C, 5), (@C, 23);

-- Scenario D: Tất cả danh mục — 7,180,000 / 5,000,000 = 143% → VƯỢT + repeating
INSERT INTO tBudgets (acc_id, wallet_id, amount, begin_date, end_date, all_categories, repeating)
VALUES (6, NULL, 5000000, '2026-03-01', '2026-03-31', 1, 1);
SET @D = SCOPE_IDENTITY();
-- all_categories=1 → không cần insert tBudgetCategories

-- Scenario E: Ăn uống chỉ ví MB Bank — 1,395,000 / 1,500,000 = 93% → CẢNH BÁO
INSERT INTO tBudgets (acc_id, wallet_id, amount, begin_date, end_date, all_categories, repeating)
VALUES (6, 10, 1500000, '2026-03-01', '2026-03-31', 0, 0);
SET @E = SCOPE_IDENTITY();
INSERT INTO tBudgetCategories (budget_id, ctg_id) VALUES (@E, 1);

-- Scenario F: Giáo dục — 1,350,000 / 3,000,000 = 45% → AN TOÀN + repeating
INSERT INTO tBudgets (acc_id, wallet_id, amount, begin_date, end_date, all_categories, repeating)
VALUES (6, NULL, 3000000, '2026-03-01', '2026-03-31', 0, 1);
SET @F = SCOPE_IDENTITY();
INSERT INTO tBudgetCategories (budget_id, ctg_id) VALUES (@F, 8);

PRINT N'✅ Đã tạo 6 budgets: A=' + CAST(@A AS VARCHAR) + ' B=' + CAST(@B AS VARCHAR)
    + ' C=' + CAST(@C AS VARCHAR) + ' D=' + CAST(@D AS VARCHAR)
    + ' E=' + CAST(@E AS VARCHAR) + ' F=' + CAST(@F AS VARCHAR);
GO

-- ======================================================================
-- TEST DATA: tPlannedTransactions — User 6 (minh.pham@gmail.com)
-- ======================================================================
-- User 6 info:
--   acc_id   = 6
--   wallet   = 10 (MB Bank 6,500,000đ) | 11 (VNPay 900,000đ)
--   debt     = id=9 (Cho vay Chị gái 3,500,000đ — ctg=21 Thu nợ)
--
-- Mục tiêu: cover đủ các case để test API + Scheduler
-- ┌───┬──────────────────────────────────────────────────────────────┐
-- │ # │ Case cần test                                                │
-- ├───┼──────────────────────────────────────────────────────────────┤
-- │ 1 │ Bill hóa đơn điện    → plan_type=1, repeat_type=3 (tháng)   │
-- │ 2 │ Recurring Internet   → plan_type=2, repeat_type=3 (tháng)   │
-- │ 3 │ Recurring Gói mobile → plan_type=2, repeat_type=3 (tháng)   │
-- │ 4 │ Recurring Trả nợ     → plan_type=2, debt_id=NULL (iPhone)   │
-- │ 5 │ Recurring THU lương  → plan_type=2, ctg=15 (Lương) ← MỚI   │
-- │ 6 │ Recurring tuần       → plan_type=2, repeat_type=2, bitmask  │
-- │ 7 │ Thu nợ có debt_id    → plan_type=2, ctg=21, debt_id=9 ← MỚI│
-- │ 8 │ Đã kết thúc          → active=0, end_date trong quá khứ     │
-- └───┴──────────────────────────────────────────────────────────────┘
-- ======================================================================
-- chỉ có 8 dữ liệu test nhưng select ra 12 bị trùng một số field nên xóa bớt để test
DELETE FROM tPlannedTransactions
WHERE acc_id = 6 AND id IN (3, 12, 18, 34);
GO
INSERT INTO tPlannedTransactions (
    acc_id, wallet_id, ctg_id, debt_id,
    note, amount, plan_type,
    repeat_type, repeat_interval, repeat_on_day_val,
    begin_date, next_due_date, last_executed_at, end_date, active
) VALUES

-- ── CASE 1: Bill hóa đơn điện ─────────────────────────────────────────
-- plan_type=1 → user phải duyệt tay trước khi tạo Transaction
-- Đã qua hạn (2026-03-20) → test bill quá hạn
(6, 10, 28, NULL,
 N'Hóa đơn điện (Nhà riêng)',
 450000, 1,
 3, 1, NULL,
 '2026-01-20', '2026-03-20', '2026-02-20', NULL, 1),

-- ── CASE 2: Recurring Internet ────────────────────────────────────────
-- plan_type=2 → Scheduler tự tạo Transaction khi đến hạn
(6, 10, 31, NULL,
 N'Internet Viettel - Gói 100Mbps',
 220000, 2,
 3, 1, NULL,
 '2026-01-20', '2026-03-20', '2026-02-20', NULL, 1),

-- ── CASE 3: Recurring Gói mobile ──────────────────────────────────────
(6, 11, 29, NULL,
 N'Gói cước Viettel - V90',
 90000, 2,
 3, 1, NULL,
 '2026-01-20', '2026-03-20', '2026-02-20', NULL, 1),

-- ── CASE 4: Recurring Trả nợ (debt_id=NULL vì chưa có khoản vay) ─────
-- ⚠️ iPhone 15 Pro chưa có debt row → debt_id NULL
-- Flutter: user tạo planned trả nợ nhưng không chọn khoản nợ
(6, 10, 22, NULL,
 N'Trả góp mua iPhone 15 Pro',
 8000000, 2,
 3, 1, NULL,
 '2025-10-01', '2026-03-01', '2026-02-01', '2026-10-01', 1),

-- ── CASE 5 (MỚI): Recurring THU — Lương hàng tháng ───────────────────
-- Test ctg_type=1 (THU) → Scheduler cộng tiền vào ví thay vì trừ
-- ctg=15 (Lương), trans sinh ra là THU
(6, 10, 15, NULL,
 N'Lương tháng - Freelance Dev',
 12000000, 2,
 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),

-- ── CASE 6 (MỚI): Recurring lặp tuần — T2+T4+T6 (bitmask=42) ────────
-- T2=2, T4=8, T6=32 → 2+8+32 = 42
-- Test logic tính next_due_date theo bitmask
(6, 11, 1, NULL,
 N'Cà phê sáng (T2, T4, T6)',
 35000, 2,
 2, 1, 42,
 '2026-03-01', '2026-03-16', '2026-03-13', NULL, 1),
-- next_due_date=16/3 (T2 tuần sau) — dùng để test scheduler tuần

-- ── CASE 7 (MỚI): Thu nợ có debt_id ──────────────────────────────────
-- ctg=21 (Thu nợ), debt_id=9 (Cho vay Chị gái 3,500,000đ)
-- Scheduler: tạo Transaction THU + cộng remain_amount vào tDebts id=9
-- Test luồng: PlannedTransaction → Transaction → recalculateDebt(9)
(6, 10, 21, 9,
 N'Thu nợ Chị gái trả hàng tháng',
 500000, 2,
 3, 1, NULL,
 '2026-02-15', '2026-03-15', '2026-02-15', '2026-08-15', 1),
-- Chị gái trả 500k/tháng trong 7 tháng = 3,500,000đ ✅

-- ── CASE 8 (MỚI): Đã kết thúc (active=0) ────────────────────────────
-- Test filter API: GET /api/planned?active=false
-- end_date đã qua → hệ thống tự set active=0
(6, 11, 25, NULL,
 N'Gói Claude Pro (đã hủy)',
 500000, 2,
 3, 1, NULL,
 '2025-10-01', '2026-02-01', '2026-01-01', '2026-01-31', 0);
-- ⏸️ Đã kết thúc vì end_date='2026-01-31' đã qua

GO

-- ======================================================================
-- VERIFY: Kiểm tra sau khi INSERT
-- ======================================================================
SELECT
    id,
    ctg_id,
    note,
    amount,
    plan_type,
    repeat_type,
    repeat_on_day_val,
    debt_id,
    next_due_date,
    active
FROM tPlannedTransactions
WHERE acc_id = 6
ORDER BY id;

-- Kỳ vọng: 8 rows
-- ┌──┬──────┬─────────────────────────────┬──────────┬───────┬──────┬──────┬─────────┬──────────────┬──────┐
-- │id│ctg_id│note                         │  amount  │p_type │r_type│bitmsk│ debt_id │next_due_date │active│
-- ├──┼──────┼─────────────────────────────┼──────────┼───────┼──────┼──────┼─────────┼──────────────┼──────┤
-- │? │  28  │Hóa đơn điện Nhà riêng       │  450,000 │  1    │  3   │ NULL │  NULL   │ 2026-03-20   │  1   │
-- │? │  31  │Internet Viettel 100Mbps      │  220,000 │  2    │  3   │ NULL │  NULL   │ 2026-03-20   │  1   │
-- │? │  29  │Gói cước Viettel V90          │   90,000 │  2    │  3   │ NULL │  NULL   │ 2026-03-20   │  1   │
-- │? │  22  │Trả góp iPhone 15 Pro        │8,000,000 │  2    │  3   │ NULL │  NULL   │ 2026-03-01   │  1   │
-- │? │  15  │Lương Freelance Dev          │12,000,000│  2    │  3   │ NULL │  NULL   │ 2026-03-05   │  1   │
-- │? │   1  │Cà phê sáng T2,T4,T6         │   35,000 │  2    │  2   │  42  │  NULL   │ 2026-03-16   │  1   │
-- │? │  21  │Thu nợ Chị gái               │  500,000 │  2    │  3   │ NULL │    9    │ 2026-03-15   │  1   │
-- │? │  25  │Gói Claude Pro (đã hủy)      │  500,000 │  2    │  3   │ NULL │  NULL   │ 2026-02-01   │  0   │
-- └──┴──────┴─────────────────────────────┴──────────┴───────┴──────┴──────┴─────────┴──────────────┴──────┘

PRINT '✅ Test data user 6 — 8 rows, cover đủ các case';
GO
--select * from tWallets
--select * from tSavingGoals
--select * from tAccounts
--select * from tTransactions
--select * from tUserDevices
--select * from tReceipts
--select * from tPlannedTransactions
--select * from tNotifications
--select * from tCategories
--select * from tBudgets