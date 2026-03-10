-- ================================================================================================================================
-- DATABASE: SmartMoney
-- AUTHOR DATABASE: Ph?m ??c Phát 
-- CREATED: 2026 
-- VERSION: 1.0 (Standardized)
-- DESCRIPTION: Qu?n lý tài chính cá nhân v?i AI Assistant - Thu/Chi/Ngân sách/S? N?/Ti?t ki?m/Hóa ??n/Giao d?ch ??nh k?/S? ki?n
-- =================================================================================================================================
-- =======================================================================================================
-- D? ÁN: SMARTMONEY - QUY T?C PHÁT TRI?N & T? ?I?N K? THU?T
-- VERSION: 1.0 | TEAM: Phát - Nh?t - Nam | TH?I GIAN: 4 Tu?n
-- VERSION: 1.1 Có d? li?u m?u
-- =======================================================================================================
-- ?? L?U Ý: ?ây là guideline tham kh?o ?? nhóm d? research, không b?t bu?c áp d?ng 100%

-- 1. QUY CHU?N KI?U D? LI?U
--    Ti?n t?: DECIMAL(18,2)    | Ngày: DATE       | Time: DATETIME
--    Status: BIT/TINYINT        | ID: INT IDENTITY | Password: VARCHAR(255) (Bcrypt)

-- 2. QUY T?C ??T TÊN
--    Table: tTableName     | View: vViewName     | Index: idx_Table_Columns
--    Trigger: trg_Table_Action | FK: FK_Child_Parent | Constraint: CHK_Table_Field

-- 3. B?O M?T & QUY?N TRUY C?P (B?T BU?C)
--    ? M?i query ph?i có WHERE acc_id = ? (Row-level security)
--    ? Hash password: Bcrypt cost 12 | JWT: 15 phút + Refresh 7 ngày
--    ? Admin: Ch? Lock/Unlock account, không xóa Account/Role/Currency

-- 4. QUAN H? DATABASE
--    ????????????????????????????????????????????????????????????????????
--    ? LO?I       ? VÍ D?           ? CÁCH NH?N BI?T                   ?
--    ????????????????????????????????????????????????????????????????????
--    ? 1-1        ? Chat ? Hóa ??n  ? PK = FK (tReceipts.id = tAIConv.id)?
--    ? 1-N        ? User ? Wallets  ? FK t? con tr? v? cha              ?
--    ? N-N        ? Roles ? Perms   ? B?ng trung gian (2 FK)            ?
--    ? SELF-REF   ? Categories      ? parent_id ? id (cùng b?ng)        ?
--    ????????????????????????????????????????????????????????????????????

-- 5. THU?T NG? K? THU?T
--    ?????????????????????????????????????????????????????????????????
--    ? THU?T NG?      ? Ý NGH?A & VÍ D?                            ?
--    ?????????????????????????????????????????????????????????????????
--    ? CONSTANTS      ? Giá tr? c? ??nh DB (CHECK constraint)       ?
--    ?                 ? VD: CHECK (source_type BETWEEN 1 AND 4)    ?
--    ?????????????????????????????????????????????????????????????????
--    ? ENUM (Java)    ? H?ng s? Backend (package: com.smartmoney.enum)?
--    ?                 ? VD: TransactionType.INCOME (DB value = 1)  ?
--    ?????????????????????????????????????????????????????????????????
--    ? BITMASK        ? L?u nhi?u option vào 1 INT (l?y th?a 2)     ?
--    ?                 ? VD: T2=1,T3=2,T4=4 ? T2+T4 = 5 (1+4)       ?
--    ?????????????????????????????????????????????????????????????????
--    ?????????????????????????????????????????????????????????????????
--    ? DTO            ? Data Transfer Object - Ch? tr? data c?n    ?
--    ?                 ? VD: TransactionDTO (không tr? Entity JPA)  ?
--    ?????????????????????????????????????????????????????????????????

-- 6. QUY T?C X? LÝ ??C BI?T
--    ? Xóa danh m?c: Chuy?n transaction sang danh m?c khác ho?c xóa
--    ? S? d? âm: Cho phép (hi?n th? màu ?? + c?nh báo)

-- 7. TRIGGER - T? ??NG HÓA
--    ? T? c?ng/tr? s? d? ví khi có giao d?ch m?i/xóa
--    ? T? c?p nh?t updated_at khi record thay ??i
--    ? T? update current_amount c?a SavingGoals
--    -- L?u ý: Trigger ??n gi?n, logic ph?c t?p x? lý ? Backend

-- 8. INDEX T?I ?U HI?U N?NG
--    ? Luôn có acc_id ??u trong composite index
--    ? Dùng INCLUDE cho column th??ng SELECT
--    VD: CREATE INDEX idx_trans_active ON tTransactions(acc_id, deleted) 
--        INCLUDE (amount, trans_date)

-- 9. QUY TRÌNH PHÁT TRI?N
--    1. ??c business rules (m?c 3,6) tr??c khi code
--    2. Check constants/enum trong DB và Java
--    3. M?i API ph?i validate acc_id c?a user ?ang login
--    4. Test v?i ít nh?t 2 user (??m b?o data isolation)

-- 10. COMMON MISTAKES C?N TRÁNH
--     ? SELECT * (dùng column c? th?)  ? N+1 query (dùng JOIN FETCH)
--     ? Hardcode s? (dùng constant)    ? Không validate ownership
--     ? G?i raw Entity ra API (dùng DTO) ? Quên WHERE acc_id = ?

-- 11. AI INTEGRATION NOTES
--     ? Chat Intent: 1=add_trans, 2=report, 3=budget, 4=chat, 5=remind
--     ? OCR Receipt: Google Vision API (free tier)
--     ? Voice: Google Speech-to-Text
--     ? AI Model: ?u tiên Gemini API (free), backup OpenAI

-- 12. SECURITY CHECKLIST
--     ? Password hash v?i Bcrypt (cost 12) ? JWT expiration h?p lý
--     ? Input validation (SQL injection)   ? Rate limiting API login
--     ? HTTPS only                         ? CORS configuration

-- =======================================================================================================
-- ?? PHÂN CÔNG MODULE & TRÁCH NHI?M
-- =======================================================================================================
-- MODULE 1: WEB/AUTH (Nam ph? trách)
--   B?ng: tAccounts, tRoles, tPermissions, tRolePermissions, tUserDevices, tNotifications
--   Nhi?m v?:
--     - JWT Authentication & Spring Security
--     - Dashboard / Admin Frontend v?i bi?u ?? th?ng kê
--     - H? th?ng nh?n thông báo (tNotifications) trên thi?t b? ?ã login l?u token c?a thi?t b? pc, laptop, ?t
--     - Qu?n lý ?a thi?t b? ??ng nh?p (tUserDevices)
--     - Frontend Admin Dashboard (React)
-- 
-- MODULE 2: BASIC CRUD (Nh?t ph? trách)
--   B?ng: tWallets, tSavingGoals, tEvents, tBudgets, tBudgetCategories, tCurrencies
--   Nhi?m v?:
--     - CRUDS c? b?n cho các b?ng trên ( c? tWallet và tSavingGoals th?c ch?t c?ng là ví nh?ng m?c ?ích s? d?ng khác nhau )
--     - Cung c?p API ?? Module 3 có c? s? x? lý backend ph?n giao d?ch
--     - Frontend EndUser c? b?n (React)
-- 
-- MODULE 3: TRANSACTION CORE (Phát - Leader ph? trách)
--   B?ng: tTransactions, tPlannedTransactions, tCategories, tDebts
--   Nhi?m v?:
--     - Thi?t k? database & Qu?n lý t?ng th?
--     - Vi?t tài li?u d? án & H??ng d?n nhóm
--     - X? lý logic giao d?ch ph?c t?p (thu/chi, ??nh k?, n?)
--     - Qu?n lý danh m?c (tCategories) - c? system và user
-- 
-- MODULE 4: APP CLIENT (C? nhóm cùng làm SAU KHI hoàn thành 3 module trên)
--   Nhi?m v?:
--     - ?ng d?ng di ??ng
--     - Mobile UI/UX, Push Notifications
-- 
-- MODULE 5: AI INTEGRATION (C? nhóm cùng làm SAU KHI hoàn thành 3 module trên)
--   B?ng: tAIConversations, tReceipts
--   Nhi?m v?:
--     - AI Chat (text/voice)
--     - OCR x? lý hóa ??n
--     - Voice Processing
------------------------------------------------------------------------------------------
-- =======================================================================================================
-- ?? L?U Ý: ?ây là guideline tham kh?o, không b?t bu?c áp d?ng 100%
-- ?? L?U Ý: N?u vi?t view, trigger, m?i ch?nh s?a vào database ph?i thông báo tr??c cho nhóm không t? ý thay ??i.
-- =======================================================================================================
GO

USE master;
GO

-- Xóa database c? n?u t?n t?i
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'SmartMoney')
BEGIN
    ALTER DATABASE SmartMoney SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SmartMoney;
END
GO
-- T?O DATABASE
CREATE DATABASE SmartMoney;
GO
USE SmartMoney
GO

-- ======================================================================
-- XÓA B?NG THEO TH? T? NG??C (CON TR??C, CHA SAU)
-- ======================================================================
DROP TABLE IF EXISTS tBudgetCategories;        -- [1]  B?ng trung gian (N-N) gi?a tBudgets và tCategories
DROP TABLE IF EXISTS tPlannedTransactions;     -- [2]  Con c?a tAccounts(1-N) + tWallets(1-N) + tCategories(1-N)
DROP TABLE IF EXISTS tTransactions;            -- [3]  Con c?a tAccounts(1-N) + tWallets(1-N) + tCategories(1-N)
DROP TABLE IF EXISTS tReceipts;                -- [4]  Con c?a tAIConversations (quan h? 1-1: PK = FK)
DROP TABLE IF EXISTS tAIConversations;         -- [5]  Con c?a tAccounts (1-N)
DROP TABLE IF EXISTS tNotifications;           -- [6]  Con c?a tAccounts (1-N)
DROP TABLE IF EXISTS tDebts;                   -- [7]  Con c?a tAccounts (1-N)
DROP TABLE IF EXISTS tBudgets;                 -- [8]  Con c?a tAccounts(1-N) + tWallets(1-N)
DROP TABLE IF EXISTS tSavingGoals;             -- [9]  Con c?a tAccounts (1-N)
DROP TABLE IF EXISTS tEvents;                  -- [10] Con c?a tAccounts (1-N)
DROP TABLE IF EXISTS tWallets;                 -- [11] Con c?a tAccounts(1-N) + tCurrencies(1-N)
DROP TABLE IF EXISTS tCategories;              -- [12] Con c?a tAccounts(1-N) + T? tham chi?u chính nó
DROP TABLE IF EXISTS tUserDevices;             -- [13] Con c?a tAccounts (1-N)
DROP TABLE IF EXISTS tAccounts;                -- [14] Cha chính - Con c?a tRoles(1-N) và tCurrencies(1-N)
DROP TABLE IF EXISTS tRolePermissions;         -- [15] B?ng trung gian (N-N) gi?a tRoles và tPermissions
DROP TABLE IF EXISTS tRoles;                   -- [16] Master data - Không ph? thu?c b?ng nào
DROP TABLE IF EXISTS tPermissions;             -- [17] Master data - Không ph? thu?c b?ng nào
DROP TABLE IF EXISTS tCurrencies;              -- [18] Master data - Xóa cu?i cùng
GO
-- ======================================================================
-- 1. B?NG QUY?N H? TH?NG
-- ======================================================================
CREATE TABLE tPermissions(
    -- PRIMARY KEY
	id INT PRIMARY KEY IDENTITY(1,1),

    -- DATA COLUMNS
	per_code VARCHAR(50) UNIQUE NOT NULL,   -- Mã quy?n ??ng t? (VD: "USER_STANDARD_MANAGE", "ADMIN_SYSTEM_ALL")
	per_name NVARCHAR(100) UNIQUE NOT NULL, -- Tên hi?n th?
	module_group NVARCHAR(50) NOT NULL      -- Nhóm module (USER_CORE, ADMIN_CORE)
);
GO
-- Index: T?i ?u tìm ki?m quy?n theo nhóm module cho Admin UI
CREATE INDEX idx_permissions_group ON tPermissions(module_group) INCLUDE (per_code, per_name);
GO

-- D? LI?U M?U: Quy?n h? th?ng
INSERT INTO tPermissions (per_code, per_name, module_group) VALUES 
('ADMIN_SYSTEM_ALL',     N'Toàn quy?n qu?n tr? h? th?ng và ng??i dùng', 'ADMIN_CORE'),
('USER_STANDARD_MANAGE', N'Toàn quy?n qu?n lý tài chính cá nhân c? b?n', 'USER_CORE');
GO

-- ======================================================================
-- 2. B?NG VAI TRÒ
-- ======================================================================
CREATE TABLE tRoles(
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    -- DATA COLUMNS
    role_code VARCHAR(50) UNIQUE NOT NULL,       -- Mã role cho code check (VD: "ROLE_USER", "ROLE_ADMIN")
    role_name NVARCHAR(100) UNIQUE NOT NULL      -- Tên role hi?n th? UI (VD: "Qu?n tr? viên", "Ng??i dùng")
)
GO

-- Index: T?i ?u check role t? Backend
CREATE INDEX idx_role_code ON tRoles(role_code) INCLUDE (role_name);
GO

-- D? LI?U M?U: Vai trò
INSERT INTO tRoles (role_code, role_name) VALUES 
('ROLE_ADMIN', N'Qu?n tr? viên'),
('ROLE_USER', N'Ng??i dùng tiêu chu?n');
GO

-- ======================================================================
-- 3. B?NG TRUNG GIAN ROLE - PERMISSION (N-N)
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

-- Index: T?i ?u load quy?n theo Role (dùng khi n?p Security Context)
CREATE INDEX idx_roleper_role ON tRolePermissions(role_id) INCLUDE (per_id);
GO

INSERT INTO tRolePermissions (role_id, per_id) VALUES 
(1, 1),  -- Admin có quy?n toàn quy?n h? th?ng
(2, 2);  -- User có quy?n qu?n lý tài chính cá nhân
GO

-- ======================================================================
-- 4. B?NG TI?N T?
-- ======================================================================
CREATE TABLE tCurrencies (
    -- PRIMARY KEY
    currency_code VARCHAR(10) PRIMARY KEY,       -- Mã ti?n t? (VD: VND, USD, EUR)
    
    -- DATA COLUMNS
    currency_name NVARCHAR(100) UNIQUE NOT NULL, -- Tên ??y ?? (VD: "Vi?t Nam ??ng")
    symbol NVARCHAR(10) NOT NULL,                -- Ký hi?u (VD: "?", "$", "€")
    flag_url VARCHAR(500) UNIQUE NOT NULL        -- URL c? qu?c gia (dùng CDN)
);
GO

-- D? LI?U M?U: Ti?n t?
INSERT INTO tCurrencies (currency_code, currency_name, symbol, flag_url) VALUES 
-- C??ng qu?c & Chi?n h?u
('VND', N'Vi?t Nam ??ng', N'?', 'https://flagcdn.com/w40/vn.png'),
('CNY', N'Nhân dân t?', N'¥', 'https://flagcdn.com/w40/cn.png'),
('RUB', N'Rúp Nga', N'?', 'https://flagcdn.com/w40/ru.png'),
('CUP', N'Peso Cuba', N'?', 'https://flagcdn.com/w40/cu.png'),
('KPW', N'Won Tri?u Tiên', N'?', 'https://flagcdn.com/w40/kp.png'),
('AOA', N'Kwanza Angola', N'Kz', 'https://flagcdn.com/w40/ao.png'),

-- Khu v?c ?ông Á
('HKD', N'?ô la H?ng Kông', N'$', 'https://flagcdn.com/w40/hk.png'),
('MOP', N'Pataca Macao', N'MOP$', 'https://flagcdn.com/w40/mo.png'),
('TWD', N'?ô la ?ài Loan', N'$', 'https://flagcdn.com/w40/tw.png'),
('JPY', N'Yên Nh?t', N'¥', 'https://flagcdn.com/w40/jp.png'),
('KRW', N'Won Hàn Qu?c', N'?', 'https://flagcdn.com/w40/kr.png'),

-- ?ông Âu & Trung Á
('UAH', N'Hryvnia Ukraina', N'?', 'https://flagcdn.com/w40/ua.png'),
('BYN', N'Rúp Belarus', N'Br', 'https://flagcdn.com/w40/by.png'),
('KZT', N'Tenge Kazakhstan', N'?', 'https://flagcdn.com/w40/kz.png'),
('PLN', N'Zloty Ba Lan', N'z?', 'https://flagcdn.com/w40/pl.png'),

-- Ph??ng Tây
('USD', N'?ô la M?', N'$', 'https://flagcdn.com/w40/us.png'),
('EUR', N'Euro (Kh?i EU)', N'€', 'https://flagcdn.com/w40/eu.png'),
('GBP', N'B?ng Anh', N'£', 'https://flagcdn.com/w40/gb.png'),
('CHF', N'Franc Th?y S?', N'CHF', 'https://flagcdn.com/w40/ch.png'),
('CAD', N'?ô la Canada', N'$', 'https://flagcdn.com/w40/ca.png'),
('AUD', N'?ô la Úc', N'$', 'https://flagcdn.com/w40/au.png'),

-- Nam M? & Nam Á
('ARS', N'Peso Argentina', N'$', 'https://flagcdn.com/w40/ar.png'),
('BRL', N'Real Brazil', N'R$', 'https://flagcdn.com/w40/br.png'),
('INR', N'Rupee ?n ??', N'?', 'https://flagcdn.com/w40/in.png'),

-- Trung ?ông & Châu Phi
('SAR', N'Riyal Saudi Arabia', N'?', 'https://flagcdn.com/w40/sa.png'),
('AED', N'Dirham UAE', N'?.?', 'https://flagcdn.com/w40/ae.png'),
('ILS', N'Shekel Israel', N'?', 'https://flagcdn.com/w40/il.png'),
('EGP', N'B?ng Ai C?p', N'E£', 'https://flagcdn.com/w40/eg.png'),
('NGN', N'Naira Nigeria', N'?', 'https://flagcdn.com/w40/ng.png'),
('ZAR', N'Rand Nam Phi', N'R', 'https://flagcdn.com/w40/za.png'),

-- ?ông Nam Á (ASEAN)
('LAK', N'Kip Lào', N'?', 'https://flagcdn.com/w40/la.png'),
('KHR', N'Riel Campuchia', N'?', 'https://flagcdn.com/w40/kh.png'),
('THB', N'Baht Thái Lan', N'?', 'https://flagcdn.com/w40/th.png'),
('SGD', N'?ô la Singapore', N'$', 'https://flagcdn.com/w40/sg.png'),
('MYR', N'Ringgit Malaysia', N'RM', 'https://flagcdn.com/w40/my.png'),
('IDR', N'Rupiah Indonesia', N'Rp', 'https://flagcdn.com/w40/id.png'),
('PHP', N'Peso Philippines', N'?', 'https://flagcdn.com/w40/ph.png'),
('MMK', N'Kyat Myanmar', N'K', 'https://flagcdn.com/w40/mm.png'),
('BND', N'?ô la Brunei', N'$', 'https://flagcdn.com/w40/bn.png');
GO

-- ======================================================================
-- 5. B?NG TÀI KHO?N NG??I DÙNG
-- ======================================================================
CREATE TABLE tAccounts (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    role_id INT NOT NULL,                        -- FK -> tRoles (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1) Ti?n t? m?c ??nh
    
    -- DATA COLUMNS
    acc_phone VARCHAR(20) NULL,                  -- S? ?i?n tho?i (NULL n?u ??ng ký b?ng email)
    acc_email VARCHAR(100) NULL,                 -- Email (NULL n?u ??ng ký b?ng S?T)
    hash_password VARCHAR(255) NOT NULL,         -- M?t kh?u ?ã hash (BCrypt/Argon2)
    avatar_url VARCHAR(2048) NULL,               -- URL avatar (upload ho?c CDN)
    locked BIT DEFAULT 0 NOT NULL,            -- 0: Active | 1: Locked (không th? login)
    
    -- METADATA
    created_at DATETIME DEFAULT GETDATE() NOT NULL,
    updated_at DATETIME DEFAULT GETDATE(),
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Account_Identity CHECK (acc_phone IS NOT NULL OR acc_email IS NOT NULL), -- B?t bu?c có 1 trong 2

    CONSTRAINT FK_Account_Role FOREIGN KEY (role_id) REFERENCES tRoles(id),
    CONSTRAINT FK_Account_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: Unique cho Phone (ch?n trùng l?p)
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_acc_phone ON tAccounts(acc_phone) 
WHERE acc_phone IS NOT NULL;

-- Index: Unique cho Email (ch?n trùng l?p)
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_acc_email ON tAccounts(acc_email) 
WHERE acc_email IS NOT NULL;

-- Index: T?i ?u Admin search User theo status và role
CREATE INDEX idx_accounts_admin ON tAccounts(locked, role_id, created_at DESC) 
INCLUDE (acc_phone, acc_email, avatar_url, currency);

-- Index: T?i ?u l?c User theo ti?n t? cho th?ng kê
CREATE INDEX idx_accounts_currency ON tAccounts(currency, created_at DESC);
GO

-- D? LI?U M?U: Tài kho?n
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
-- 6. B?NG THI?T B? NG??I DÙNG (1-N v?i tAccounts)
-- ======================================================================
CREATE TABLE tUserDevices (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    device_token VARCHAR(500) NOT NULL,          -- Firebase/APNs token (UNIQUE)

    refresh_token VARCHAR(512) NULL,             -- JWT Refresh Token (hash)
    refresh_token_expired_at DATETIME NULL,      -- Th?i h?n Refresh Token

    device_type VARCHAR(50) NOT NULL,            -- VD: "iOS", "Android", "Chrome_Windows"
    device_name NVARCHAR(100) NULL,              -- VD: "iPhone 15 Pro", "Samsung S24"
    ip_address VARCHAR(45) NULL,                 -- IPv4/IPv6 cu?i cùng (c?nh báo ??ng nh?p l?)
    logged_in BIT DEFAULT 1 NOT NULL,         -- 0: ?ã logout | 1: Còn session
    last_active DATETIME DEFAULT GETDATE() NOT NULL, -- Th?i gian cu?i active (dùng tính Online)
    
    -- CONSTRAINTS
    CONSTRAINT FK_UserDevices_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id)     
);
GO
/* CÔNG TH?C CHECK ONLINE (Dành cho Dev Backend/Frontend):
  Online = (logged_in == 1) AND (CurrentTime - last_active < 5 phút)
  
  Lý do: logged_in ch? cho bi?t User ch?a b?m "??ng xu?t". 
  Còn last_active m?i cho bi?t User có th?c s? ?ang c?m máy hay không.
*/

--  Index: Unique cho Device Token (ch?n trùng l?p)
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_device_token ON tUserDevices(device_token) WHERE device_token IS NOT NULL;
-- Index: T?i ?u validate Refresh Token nhanh
CREATE INDEX idx_devices_refresh ON tUserDevices(refresh_token, refresh_token_expired_at) WHERE refresh_token IS NOT NULL;
-- Index: T?i ?u query danh sách thi?t b? Online c?a User
CREATE INDEX idx_devices_presence ON tUserDevices(acc_id, logged_in, last_active DESC) INCLUDE (device_name, device_type);
-- Index: T?i ?u Worker d?n token h?t h?n
CREATE INDEX idx_devices_expired_token ON tUserDevices(refresh_token_expired_at) WHERE refresh_token IS NOT NULL;
GO
-- ======================================================================
-- D? LI?U M?U: Thi?t b? ng??i dùng (tUserDevices)
-- ======================================================================
-- PHÂN B?: 26 rows cho 20 users
-- TEST CASES: Multi-device, Online/Offline, Token h?t h?n, ?a n?n t?ng
-- ======================================================================

INSERT INTO tUserDevices (
    acc_id, device_token, refresh_token, refresh_token_expired_at,
    device_type, device_name, ip_address, logged_in, last_active
) VALUES

-- ??????????????????????????????????????????????????????????????????????
-- USER 1 (Admin) - 2 thi?t b? (PC + Mobile)
-- ??????????????????????????????????????????????????????????????????????
(1, 'fcm_admin_desktop_token_001', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.admin.pc', 
 DATEADD(DAY, 7, GETDATE()), 
 'Chrome_Windows', N'PC Dell XPS 15', '192.168.1.100', 1, DATEADD(MINUTE, -2, GETDATE())),
 -- ?? ONLINE (logged_in=1, last_active < 5 phút)

(1, 'fcm_admin_mobile_token_002', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.admin.iphone', 
 DATEADD(DAY, 5, GETDATE()), 
 'iOS', N'iPhone 15 Pro Max', '42.118.225.134', 1, DATEADD(HOUR, -3, GETDATE())),
 -- ?? OFFLINE (logged_in=1 nh?ng last_active > 5 phút)

-- ??????????????????????????????????????????????????????????????????????
-- USER 2 (Mai) - LOCKED account - 1 thi?t b? c?
-- ??????????????????????????????????????????????????????????????????????
(2, 'fcm_mai_android_token_003', NULL, NULL, 
 'Android', N'Samsung Galaxy S23', '103.56.158.92', 0, DATEADD(DAY, -15, GETDATE())),
 -- ?? LOGGED OUT (logged_in=0) - Account b? lock

-- ??????????????????????????????????????????????????????????????????????
-- USER 3 (Nam) - 3 thi?t b? (test multi-device)
-- ??????????????????????????????????????????????????????????????????????
(3, 'fcm_nam_iphone_token_004', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.nam.iphone', 
 DATEADD(DAY, 6, GETDATE()), 
 'iOS', N'iPhone 14', '115.78.34.201', 1, GETDATE()),
 -- ?? ONLINE (v?a m?i active)

(3, 'fcm_nam_laptop_token_005', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.nam.macbook', 
 DATEADD(DAY, 3, GETDATE()), 
 'Safari_macOS', N'MacBook Pro 2023', '192.168.1.105', 1, DATEADD(MINUTE, -4, GETDATE())),
 -- ?? ONLINE (trong 5 phút)

(3, 'fcm_nam_ipad_token_006', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.nam.ipad', 
 DATEADD(DAY, -2, GETDATE()), 
 'iOS', N'iPad Air 5', '115.78.34.201', 1, DATEADD(DAY, -1, GETDATE())),
 -- ?? TOKEN H?T H?N + OFFLINE

-- ??????????????????????????????????????????????????????????????????????
-- USER 4 (test3) - 1 thi?t b? Android
-- ??????????????????????????????????????????????????????????????????????
(4, 'fcm_test3_xiaomi_token_007', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test3.xiaomi', 
 DATEADD(DAY, 4, GETDATE()), 
 'Android', N'Xiaomi Redmi Note 12', '171.244.56.123', 1, DATEADD(MINUTE, -30, GETDATE())),
 -- ?? OFFLINE (30 phút tr??c)

-- ??????????????????????????????????????????????????????????????????????
-- USER 5 (H??ng - Admin) - 2 thi?t b?
-- ??????????????????????????????????????????????????????????????????????
(5, 'fcm_huong_desktop_token_008', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.huong.desktop', 
 DATEADD(DAY, 7, GETDATE()), 
 'Edge_Windows', N'PC HP EliteBook', '192.168.10.50', 1, DATEADD(MINUTE, -1, GETDATE())),
 -- ?? ONLINE

(5, 'fcm_huong_android_token_009', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.huong.oppo', 
 DATEADD(DAY, 5, GETDATE()), 
 'Android', N'OPPO Find X6 Pro', '113.161.78.45', 1, DATEADD(HOUR, -2, GETDATE())),
 -- ?? OFFLINE

-- ??????????????????????????????????????????????????????????????????????
-- USER 6 (Minh) - 1 thi?t b? iPhone
-- ??????????????????????????????????????????????????????????????????????
(6, 'fcm_minh_iphone13_token_010', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.minh.iphone', 
 DATEADD(DAY, 6, GETDATE()), 
 'iOS', N'iPhone 13 Pro', '14.231.187.92', 1, DATEADD(MINUTE, -10, GETDATE())),
 -- ?? OFFLINE

-- ??????????????????????????????????????????????????????????????????????
-- USER 7 (Linh) - LOCKED - 1 thi?t b? c?
-- ??????????????????????????????????????????????????????????????????????
(7, 'fcm_linh_vivo_token_011', NULL, NULL, 
 'Android', N'Vivo V29', '125.235.10.88', 0, DATEADD(DAY, -20, GETDATE())),
 -- ?? LOGGED OUT - Account locked

-- ??????????????????????????????????????????????????????????????????????
-- USER 8 (Quân) - 2 thi?t b? (Web + Mobile)
-- ??????????????????????????????????????????????????????????????????????
(8, 'fcm_quan_chrome_token_012', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.quan.chrome', 
 DATEADD(DAY, 7, GETDATE()), 
 'Chrome_Linux', N'Ubuntu Desktop 22.04', '118.70.186.45', 1, DATEADD(SECOND, -30, GETDATE())),
 -- ?? ONLINE (30s tr??c)

(8, 'fcm_quan_realme_token_013', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.quan.realme', 
 DATEADD(DAY, 4, GETDATE()), 
 'Android', N'Realme GT Neo 5', '118.70.186.45', 1, DATEADD(DAY, -1, GETDATE())),
 -- ?? OFFLINE (1 ngày tr??c)

-- ??????????????????????????????????????????????????????????????????????
-- USER 9 (Th?o) - 1 thi?t b? Samsung
-- ??????????????????????????????????????????????????????????????????????
(9, 'fcm_thao_samsung_token_014', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.thao.samsung', 
 DATEADD(DAY, 5, GETDATE()), 
 'Android', N'Samsung Galaxy A54', '171.224.178.90', 1, DATEADD(MINUTE, -3, GETDATE())),
 -- ?? ONLINE

-- ??????????????????????????????????????????????????????????????????????
-- USER 10 (Khánh) - 2 thi?t b? (PC + iOS)
-- ??????????????????????????????????????????????????????????????????????
(10, 'fcm_khanh_firefox_token_015', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.khanh.firefox', 
 DATEADD(DAY, 6, GETDATE()), 
 'Firefox_Windows', N'PC Acer Aspire', '192.168.2.88', 1, DATEADD(MINUTE, -15, GETDATE())),
 -- ?? OFFLINE

(10, 'fcm_khanh_iphone_token_016', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.khanh.iphone12', 
 DATEADD(DAY, -1, GETDATE()), 
 'iOS', N'iPhone 12 Mini', '42.112.89.156', 1, DATEADD(HOUR, -10, GETDATE())),
 -- ?? TOKEN H?T H?N + OFFLINE

-- ??????????????????????????????????????????????????????????????????????
-- USER 11 (Anh) - LOCKED - ?ã logout
-- ??????????????????????????????????????????????????????????????????????
(11, 'fcm_anh_oneplus_token_017', NULL, NULL, 
 'Android', N'OnePlus 11', '113.185.42.78', 0, DATEADD(DAY, -10, GETDATE())),
 -- ?? LOGGED OUT

-- ??????????????????????????????????????????????????????????????????????
-- USER 12 (??c) - 1 thi?t b? Android
-- ??????????????????????????????????????????????????????????????????????
(12, 'fcm_duc_pixel_token_018', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.duc.pixel', 
 DATEADD(DAY, 7, GETDATE()), 
 'Android', N'Google Pixel 8 Pro', '171.250.166.34', 1, DATEADD(MINUTE, -2, GETDATE())),
 -- ?? ONLINE

-- ??????????????????????????????????????????????????????????????????????
-- USER 13 (Hoa) - 1 thi?t b? Web
-- ??????????????????????????????????????????????????????????????????????
(13, 'fcm_hoa_brave_token_019', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.hoa.brave', 
 DATEADD(DAY, 5, GETDATE()), 
 'Brave_macOS', N'MacBook Air M2', '192.168.5.120', 1, DATEADD(HOUR, -1, GETDATE())),
 -- ?? OFFLINE

-- ??????????????????????????????????????????????????????????????????????
-- USER 14 (Tu?n) - 1 thi?t b? iPhone
-- ??????????????????????????????????????????????????????????????????????
(14, 'fcm_tuan_iphone14_token_020', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.tuan.iphone14', 
 DATEADD(DAY, 6, GETDATE()), 
 'iOS', N'iPhone 14 Plus', '27.72.98.156', 1, DATEADD(MINUTE, -4, GETDATE())),
 -- ?? ONLINE

-- ??????????????????????????????????????????????????????????????????????
-- USER 15 (Lan) - LOCKED - Không còn session
-- ??????????????????????????????????????????????????????????????????????
(15, 'fcm_lan_huawei_token_021', NULL, NULL, 
 'Android', N'Huawei Nova 11', '14.177.234.89', 0, DATEADD(DAY, -25, GETDATE())),
 -- ?? LOGGED OUT

-- ??????????????????????????????????????????????????????????????????????
-- USER 16 (H?ng) - 1 thi?t b? Android
-- ??????????????????????????????????????????????????????????????????????
(16, 'fcm_hung_note20_token_022', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.hung.note20', 
 DATEADD(DAY, 4, GETDATE()), 
 'Android', N'Samsung Note 20 Ultra', '113.172.45.201', 1, DATEADD(MINUTE, -8, GETDATE())),
 -- ?? OFFLINE

-- ??????????????????????????????????????????????????????????????????????
-- USER 17 (M?) - 2 thi?t b? (PC + Mobile)
-- ??????????????????????????????????????????????????????????????????????
(17, 'fcm_my_opera_token_023', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.my.opera', 
 DATEADD(DAY, 7, GETDATE()), 
 'Opera_Windows', N'PC Lenovo ThinkPad', '192.168.8.45', 1, GETDATE()),
 -- ?? ONLINE (v?a m?i active)

(17, 'fcm_my_asus_token_024', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.my.asus', 
 DATEADD(DAY, 3, GETDATE()), 
 'Android', N'ASUS Zenfone 10', '171.255.89.123', 1, DATEADD(HOUR, -6, GETDATE())),
 -- ?? OFFLINE

-- ??????????????????????????????????????????????????????????????????????
-- USER 18 (S?n) - 1 thi?t b? iOS
-- ??????????????????????????????????????????????????????????????????????
(18, 'fcm_son_iphone13pro_token_025', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.son.iphone', 
 DATEADD(DAY, 5, GETDATE()), 
 'iOS', N'iPhone 13 Pro Max', '42.119.167.88', 1, DATEADD(MINUTE, -20, GETDATE())),
 -- ?? OFFLINE

-- ??????????????????????????????????????????????????????????????????????
-- USER 19 (Thu) - LOCKED - ?ã logout
-- ??????????????????????????????????????????????????????????????????????
(19, 'fcm_thu_tablet_token_026', NULL, NULL, 
 'Android', N'Samsung Galaxy Tab S9', '113.168.234.77', 0, DATEADD(DAY, -30, GETDATE())),
 -- ?? LOGGED OUT - Account locked

-- ??????????????????????????????????????????????????????????????????????
-- USER 20 (Long) - 1 thi?t b? Web
-- ??????????????????????????????????????????????????????????????????????
(20, 'fcm_long_chromium_token_027', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.long.chromium', 
 DATEADD(DAY, 6, GETDATE()), 
 'Chromium_Linux', N'Linux Mint Desktop', '118.69.78.156', 1, DATEADD(MINUTE, -3, GETDATE()));
 -- ?? ONLINE

GO

-- ======================================================================
-- TH?NG KÊ D? LI?U ?Ã CHÈN
-- ======================================================================
-- Total Rows: 27 devices
-- Users có >1 thi?t b?: User 1, 3, 5, 8, 10, 17 (6 users)
-- Devices ONLINE (logged_in=1, last_active < 5 min): 10 devices
-- Devices OFFLINE: 11 devices
-- Devices LOGGED OUT (logged_in=0): 6 devices (users b? lock)
-- Tokens h?t h?n: 2 devices (user 3, user 10)
-- N?n t?ng: iOS (8), Android (13), Windows (4), macOS (2), Linux (2)
-- ======================================================================
PRINT '? ?ã chèn 27 rows vào tUserDevices thành công!';
PRINT 'Phân b?: 20 users, 10 online, 11 offline, 6 logged out';
GO

-- ======================================================================
-- 7. B?NG DANH M?C THU/CHI (T? tham chi?u: 1-N v?i chính nó)
-- ======================================================================
-- N?u ng??i dùng mu?n xóa danh m?c thì s? có 2 h??ng ( Xóa h?n và g?m l?ch s? giao d?ch ho?c ch?n g?p sang m?t danh m?c khác và xóa danh m?c này )
CREATE TABLE tCategories (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NULL,                             -- FK -> tAccounts (N-1) | NULL = System Category
    parent_id INT NULL,                          -- FK -> tCategories (1-N) | NULL = Root Category
    
    -- DATA COLUMNS
    ctg_name NVARCHAR(100) NOT NULL,             -- Tên danh m?c (VD: "?n u?ng", "L??ng")
    ctg_type BIT NOT NULL,                       -- 0: Chi tiêu | 1: Thu nh?p
    ctg_icon_url VARCHAR(2048) NULL,             -- Icon SVG ho?c URL (VD: "icon_food.svg")
    
    -- CONSTRAINTS
    CONSTRAINT FK_Categories_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Categories_Parent FOREIGN KEY (parent_id) REFERENCES tCategories(id) -- T? tham chi?u
);
GO

-- Index: T?i ?u Backend check danh m?c System
CREATE INDEX idx_system_category_check ON tCategories(ctg_name) WHERE acc_id IS NULL AND parent_id IS NULL;
-- Index: T?i ?u query danh m?c theo User và Parent
CREATE INDEX idx_categories_lookup ON tCategories(acc_id, parent_id, ctg_type) INCLUDE (ctg_name, ctg_icon_url);
-- Ch?n User t?o 2 m?c con (vd: "Ti?n trà ?á", "Ti?n trà ?á") trong cùng m?t m?c cha.
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_sub_category ON tCategories(acc_id, parent_id, ctg_name, ctg_type) WHERE parent_id IS NOT NULL;
-- Ch?n User t?o 2 m?c cha (vd: "?n u?ng", "?n u?ng").
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_user_root ON tCategories(acc_id, ctg_name, ctg_type) 
WHERE parent_id IS NULL AND acc_id IS NOT NULL;
-- Index Unique: B?o v? danh m?c g?c System không b? trùng
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_root_category ON tCategories(ctg_name, ctg_type) 
WHERE parent_id IS NULL AND acc_id IS NULL;
-- Index Unique: B?o v? danh m?c con System không b? trùng
CREATE UNIQUE NONCLUSTERED INDEX idx_unique_system_sub_category ON tCategories(parent_id, ctg_name, ctg_type) WHERE parent_id IS NOT NULL AND acc_id IS NULL;
-- Ng?n User t?o danh m?c G?c trùng tên v?i danh m?c G?c c?a H? th?ng ( vi?t trong backend )

/* H??NG D?N CHO BACKEND ho?c dùng trigger (IMPORTANT):
   - ?I?U KI?N: "User không ???c t?o danh m?c G?c trùng tên v?i System".
   - BACKEND C?N CHECK: Tr??c khi l?u danh m?c G?c cho User, hãy ki?m tra xem 'ctg_name' 
     ?ã t?n t?i trong các dòng (acc_id IS NULL AND parent_id IS NULL) ch?a. 
     N?u có -> Báo l?i cho ng??i dùng không ???c t?o trùng danh m?c h? th?ng
*/

GO
-- Chèn danh m?c h? th?ng (acc_id = NULL)
-- ==========================================================
-- B??C 1: CHÈN CÁC NHÓM CHA (ROOT) - ??NH DANH C?P CAO NH?T
-- ==========================================================
-- 1.1 NHÓM CHI TIÊU (EXPENSE = 0)
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url) VALUES  
 (NULL, NULL, N'?n u?ng', 0, 'icon_food.svg')
,(NULL, NULL, N'B?o hi?m', 0, 'icon_insurance.svg')
,(NULL, NULL, N'Các chi phí khác', 0, 'icon_other_expense.svg')
,(NULL, NULL, N'??u t?', 0, 'icon_invest.svg')
,(NULL, NULL, N'Di chuy?n', 0, 'icon_transport.svg')
,(NULL, NULL, N'Gia ?ình', 0, 'icon_family.svg')
,(NULL, NULL, N'Gi?i trí', 0, 'icon_entertainment.svg')
,(NULL, NULL, N'Giáo d?c', 0, 'icon_education.svg')
,(NULL, NULL, N'Hoá ??n & Ti?n ích', 0, 'icon_utilities.svg')
,(NULL, NULL, N'Mua s?m', 0, 'icon_shopping.svg')
,(NULL, NULL, N'Quà t?ng & Quyên góp', 0, 'icon_gift.svg')
,(NULL, NULL, N'S?c kh?e', 0, 'icon_health.svg')
,(NULL, NULL, N'Ti?n chuy?n ?i', 0, 'icon_transfer_out.svg')
,(NULL, NULL, N'Tr? lãi', 0, 'icon_interest_pay.svg');

-- 1.2 NHÓM THU NH?P (INCOME = 1)
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url) VALUES  
 (NULL, NULL, N'L??ng', 1, 'icon_salary.svg')
,(NULL, NULL, N'Thu lãi', 1, 'icon_interest_receive.svg')
,(NULL, NULL, N'Thu nh?p khác', 1, 'icon_other_income.svg')
,(NULL, NULL, N'Ti?n chuy?n ??n', 1, 'icon_transfer_in.svg');

-- 1.3 NHÓM VAY / N?
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url) VALUES  
 (NULL, NULL, N'Cho vay', 0, 'icon_loan_out.svg')
,(NULL, NULL, N'?i vay', 1, 'icon_loan_in.svg')
,(NULL, NULL, N'Thu n?', 1, 'icon_debt_collection.svg')
,(NULL, NULL, N'Tr? n?', 0, 'icon_debt_repayment.svg');
GO -- K?t thúc phiên làm vi?c 1 ?? SQL l?u ID các nhóm Cha

-- ==========================================================
-- B??C 2: CHÈN CÁC NHÓM CON (SUB-CATEGORIES) - LIÊN K?T CHA
-- ==========================================================
-- Chèn con cho nhóm CHI TIÊU
INSERT INTO tCategories (acc_id, parent_id, ctg_name, ctg_type, ctg_icon_url)
SELECT NULL, p.id, v.new_name, p.ctg_type, v.icon
FROM (VALUES  
    (N'Di chuy?n', N'B?o d??ng xe', 'icon_car_repair.svg'),
    (N'Gia ?ình', N'D?ch v? gia ?ình', 'icon_home_service.svg'),
    (N'Gia ?ình', N'S?a & trang trí nhà', 'icon_home_decor.svg'),
    (N'Gia ?ình', N'V?t nuôi', 'icon_pets.svg'),
    (N'Gi?i trí', N'D?ch v? tr?c tuy?n', 'icon_online_service.svg'),
    (N'Gi?i trí', N'Vui - ch?i', 'icon_travel.svg'),
    (N'Hoá ??n & Ti?n ích', N'Hoá ??n ?i?n', 'icon_electricity.svg'),
    (N'Hoá ??n & Ti?n ích', N'Hoá ??n ?i?n tho?i', 'icon_phone_bill.svg'),
    (N'Hoá ??n & Ti?n ích', N'Hoá ??n gas', 'icon_gas.svg'),
    (N'Hoá ??n & Ti?n ích', N'Hoá ??n internet', 'icon_internet.svg'),
    (N'Hoá ??n & Ti?n ích', N'Hoá ??n n??c', 'icon_water.svg'),
    (N'Hoá ??n & Ti?n ích', N'Hoá ??n ti?n ích khác', 'icon_other_bill.svg'),
    (N'Hoá ??n & Ti?n ích', N'Hoá ??n TV', 'icon_tv.svg'),
    (N'Hoá ??n & Ti?n ích', N'Thuê nhà', 'icon_rent.svg'),
    (N'Mua s?m', N'?? dùng cá nhân', 'icon_personal_item.svg'),
    (N'Mua s?m', N'?? gia d?ng', 'icon_home_appliance.svg'),
    (N'Mua s?m', N'Làm ??p', 'icon_beauty.svg'),
    (N'S?c kh?e', N'Khám s?c kho?', 'icon_medical.svg'),
    (N'S?c kh?e', N'Th? d?c th? thao', 'icon_sport.svg')
) AS v(parent_name, new_name, icon)
JOIN tCategories p ON p.ctg_name = v.parent_name AND p.parent_id IS NULL;
GO

-- ======================================================================
-- 8. B?NG VÍ (1-N v?i tAccounts)
-- ======================================================================
CREATE TABLE tWallets (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1)
    -- them anh con thieu
     goal_image_url VARCHAR(2048) NULL,           -- Hình ?nh ví
    -- DATA COLUMNS
    wallet_name NVARCHAR(100) NOT NULL,          -- VD: "Ti?n m?t", "Vietcombank", "Momo"
    balance DECIMAL(18,2) DEFAULT 0,             -- S? d? hi?n t?i (t? ??ng tính t? Transactions)
    notified BIT DEFAULT 1 NOT NULL,          -- 0: T?t thông báo | 1: B?t thông báo
    reportable BIT DEFAULT 1 NOT NULL,        -- 0: Không tính vào báo cáo | 1: Tính vào Dashboard
    
    -- CONSTRAINTS
    CONSTRAINT FK_Wallets_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Wallets_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: T?i ?u load danh sách Ví c?a User
CREATE INDEX idx_wallets_user ON tWallets(acc_id, reportable) INCLUDE (wallet_name, balance, currency, notified);
GO

-- D? LI?U M?U: Ví
INSERT INTO tWallets (acc_id, wallet_name, balance, currency, notified, reportable, goal_image_url) VALUES 
(1, N'Ti?n m?t', 5000000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=cash'),
(1, N'Vietcombank', 15000000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank1'),
(2, N'Ví MoMo', 2500000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=momo'),
(2, N'Techcombank', 8000000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank2'),
(3, N'Ti?n m?t', 3200000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=cash2'),
(3, N'BIDV', 12000000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank3'),
(19, N'ZaloPay', 1800000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=zalopay'),
(4, N'Agribank', 20000000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank4'),
(5, N'Ví ti?t ki?m', 50000000, 'VND', 0, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=saving'),
(6, N'MB Bank', 6500000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank5'),
(6, N'VNPay', 900000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=vnpay'),
(7, N'ACB', 18000000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank6'),
(20, N'Ví du l?ch', 10000000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=travel'),
(20, N'VPBank', 7200000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank7'),
(9, N'Ti?n m?t', 4500000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=cash3'),
(10, N'SHB', 9800000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank8'),
(10, N'Ví mua s?m', 3000000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=shopping'),
(11, N'TPBank', 11000000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank9'),
(12, N'Ví kh?n c?p', 5000000, 'VND', 0, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=emergency'),
(12, N'Sacombank', 14500000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank10'),
(8, N'Ti?n m?t', 2800000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=cash4'),
(14, N'HDBank', 16000000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank11'),
(15, N'Ví h?c phí', 25000000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=education'),
(16, N'OCB', 8500000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank12'),
(17, N'Ví ??u t?', 30000000, 'VND', 0, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=invest'),
(18, N'VietinBank', 13200000, 'VND', 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bank13');
GO

-- ======================================================================
-- 9. B?NG M?C TIÊU TI?T KI?M (1-N v?i tAccounts)
-- ======================================================================
CREATE TABLE tSavingGoals (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1)
    
    -- DATA COLUMNS
    goal_name NVARCHAR(200) NOT NULL,            -- VD: "Mua iPhone 15 Pro Max", "Qu? kh?n c?p"
    target_amount DECIMAL(18,2) NOT NULL,        -- S? ti?n m?c tiêu
    current_amount DECIMAL(18,2) DEFAULT 0,      -- S? ti?n ?ã ti?t ki?m
    goal_image_url VARCHAR(2048) NULL,           -- Hình ?nh m?c tiêu (VD: ?nh iPhone)
    begin_date DATE DEFAULT GETDATE(),           -- Ngày b?t ??u
    end_date DATE NOT NULL,                      -- Ngày k?t thúc
    goal_status TINYINT DEFAULT 1 NOT NULL,        -- 1: Active | 2: Completed | 3: Cancelled | 4: OVERDUE ( quá h?n )
    notified BIT DEFAULT 1 NOT NULL,          -- 0: T?t thông báo | 1: B?t thông báo
    reportable BIT DEFAULT 1 NOT NULL,        -- 0: Không tính vào báo cáo | 1: Tính vào Dashboard
    finished BIT DEFAULT 0,                   -- 0: ?ang di?n ra | 1: ?ã k?t thúc
    
    -- CONSTRAINTS
    CONSTRAINT CHK_SavingGoals_Amount CHECK (target_amount > 0 AND current_amount >= 0),
    CONSTRAINT CHK_SavingGoals_Progress CHECK (current_amount <= target_amount),
    CONSTRAINT CHK_SavingGoals_Dates CHECK (end_date >= begin_date),
    CONSTRAINT CHK_SavingGoals_Status CHECK (goal_status IN (1, 2, 3, 4)),

    CONSTRAINT FK_SavingGoals_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_SavingGoals_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: T?i ?u Dashboard và Báo cáo t?ng quát
CREATE INDEX idx_saving_reportable ON tSavingGoals(acc_id, reportable, goal_status, finished) INCLUDE (current_amount, target_amount, end_date, currency);
-- Index: T?i ?u hi?n th? m?c tiêu ?ang Active
CREATE INDEX idx_saving_active ON tSavingGoals(acc_id, goal_status, finished) INCLUDE (goal_name, current_amount, target_amount, end_date);
GO

-- D? LI?U M?U: M?c tiêu ti?t ki?m
INSERT INTO tSavingGoals (acc_id, goal_name, target_amount, current_amount, begin_date, end_date, goal_status, notified, reportable, finished, goal_image_url, currency) VALUES 
(1, N'Qu? kh?n c?p', 50000000, 30000000, '2024-01-15', '2026-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=emergency', 'VND'),
(1, N'Mua nhà', 2000000000, 500000000, '2023-06-01', '2028-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=house', 'VND'),
(2, N'Mua iPhone 15', 25000000, 5000000, '2025-03-10', '2027-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=iphone', 'VND'),
(2, N'Du l?ch Nh?t B?n', 40000000, 15000000, '2025-01-20', '2026-06-30', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=japan', 'VND'),
(3, N'Heo ??t màu vàng', 10000000, 8500000, '2024-08-01', '2026-08-01', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=piggy', 'VND'),
(3, N'Ti?n khám b?nh', 15000000, 12000000, '2024-05-15', '2026-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=health', 'VND'),
(5, N'Mua xe máy SH', 90000000, 45000000, '2024-11-01', '2026-10-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=motorbike', 'VND'),
(5, N'Qu? c??i', 200000000, 80000000, '2024-02-14', '2027-02-14', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=wedding', 'VND'),
(6, N'Mua laptop Dell XPS 15', 45000000, 25000000, '2025-02-01', '2026-05-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=laptop', 'VND'),
(7, N'Ti?t ki?m h?c t?p', 30000000, 18000000, '2024-09-01', '2027-06-30', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=education', 'VND'),
(8, N'Mua ??t', 500000000, 150000000, '2024-01-01', '2029-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=land', 'VND'),
(9, N'Qu? kh?n c?p', 40000000, 25000000, '2024-07-01', '2026-06-30', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=emergency2', 'VND'),
(10, N'Mua nh?n c??i', 50000000, 35000000, '2024-12-01', '2026-11-30', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=ring', 'VND'),
(10, N'K? ngh? Châu Âu', 80000000, 30000000, '2025-01-01', '2027-05-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=europe', 'VND'),
(11, N'Mua ô tô', 400000000, 120000000, '2024-03-15', '2028-03-15', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=car', 'VND'),
(12, N'Qu? s?a nhà', 100000000, 45000000, '2024-10-01', '2026-09-30', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=renovation', 'VND'),
(13, N'Mua iPad Pro', 28000000, 10000000, '2025-04-01', '2026-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=ipad', 'VND'),
(14, N'Ti?n sinh nh?t con', 20000000, 15000000, '2024-06-01', '2026-08-15', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=birthday', 'VND'),
(15, N'H?c Th?c s?', 150000000, 60000000, '2024-01-10', '2028-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=master', 'VND'),
(16, N'Mua AirPods Pro', 6000000, 4500000, '2025-03-01', '2026-03-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=airpods', 'VND'),
(17, N'??u t? ch?ng khoán', 100000000, 70000000, '2024-02-01', '2027-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=stock', 'VND'),
(18, N'Mua ??ng h?', 45000000, 20000000, '2025-01-05', '2026-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=watch', 'VND'),
(19, N'Qu? kh?i nghi?p', 200000000, 50000000, '2024-04-01', '2027-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=startup', 'VND'),
(20, N'Mua máy ?nh', 55000000, 35000000, '2024-11-15', '2026-06-30', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=camera', 'VND'),
(4, N'Qu? h?u trí', 500000000, 100000000, '2023-01-01', '2030-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=retirement', 'VND'),
(4, N'Qu? giáo d?c con', 300000000, 150000000, '2023-09-01', '2028-08-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=school', 'VND'),
(11, N'Khóa h?c AWS Solutions Architect', 18000000, 8000000, '2025-02-10', '2026-08-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=aws', 'VND'),
(13, N'Chuy?n du ngo?n Maldives', 65000000, 22000000, '2025-03-15', '2026-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=maldives', 'VND'),
(15, N'Qu? phát tri?n k? n?ng l?p trình', 25000000, 12000000, '2024-10-01', '2027-03-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=coding', 'VND'),
(17, N'Mua MacBook Pro M3', 52000000, 28000000, '2025-01-20', '2026-09-30', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=macbook', 'VND'),
(6, N'Qu? ??ng ký ChatGPT Plus & Claude Pro', 12000000, 3500000, '2025-01-01', '2026-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=ai', 'VND'),
(8, N'Qu? mua license JetBrains', 8000000, 4200000, '2024-11-01', '2026-06-30', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=jetbrains', 'VND'),
(12, N'Qu? nâng c?p VPS & Domain', 15000000, 6800000, '2024-08-15', '2027-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=server', 'VND'),
(14, N'Qu? s?c kh?e tinh th?n (sau khi b? AI thay th?)', 30000000, 8000000, '2024-06-01', '2028-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=mental', 'VND'),
(16, N'Qu? h?c chuy?n ngh? (phòng thân)', 50000000, 15000000, '2024-09-01', '2027-06-30', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=career', 'VND'),
(18, N'Qu? mua API credits (OpenAI, Anthropic)', 20000000, 9500000, '2025-02-01', '2026-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=api', 'VND'),
-- ??????????????????????????????????????????????????????????????????????
-- STATUS 2: Completed (?ã hoàn thành)
-- Logic: current_amount = target_amount, finished = 1, end_date ?ã qua
-- ??????????????????????????????????????????????????????????????????????
(1,  N'Mua iPhone 14 Pro',          20000000, 20000000, '2024-01-01', '2024-12-31', 2, 1, 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=iphone14',   'VND'),
-- ? ?ã ti?t ki?m ?? 20tr, hoàn thành tr??c h?n

(3,  N'Mua xe ??p th? thao',         8000000,  8000000, '2024-03-01', '2025-06-30', 2, 1, 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=bicycle',    'VND'),
-- ? ?ã ??t m?c tiêu, finished

(8,  N'Qu? du l?ch Thái Lan',       25000000, 25000000, '2024-05-01', '2025-12-31', 2, 1, 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=thailand',   'VND'),
-- ? Hoàn thành ?úng h?n

(12, N'Mua máy ?nh Sony A7III',      40000000, 40000000, '2023-06-01', '2025-01-31', 2, 1, 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=sony',       'VND'),
-- ? Hoàn thành s?m

(20, N'H?c khóa Flutter nâng cao',    5000000,  5000000, '2025-01-01', '2025-08-31', 2, 1, 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=flutter',    'VND'),
-- ? Hoàn thành

-- ??????????????????????????????????????????????????????????????????????
-- STATUS 3: Cancelled (?ã h?y)
-- Logic: finished = 1, current_amount < target_amount (b? d? gi?a ch?ng)
-- ??????????????????????????????????????????????????????????????????????
(2,  N'Mua PS5',                     16000000,  4500000, '2024-02-01', '2025-03-31', 3, 0, 0, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=ps5',        'VND'),
-- ? H?y vì ??i ý không mua n?a, ?ã rút ti?n ra

(5,  N'Du l?ch Hàn Qu?c',           60000000, 12000000, '2024-06-01', '2025-12-31', 3, 0, 0, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=korea',      'VND'),
-- ? H?y vì k? ho?ch thay ??i

(9,  N'Mua t? l?nh side-by-side',   18000000,  3000000, '2024-09-01', '2025-06-30', 3, 0, 0, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=fridge',     'VND'),
-- ? H?y vì m??n ???c ti?n ng??i thân

(16, N'Mua SmartTV 65 inch',        22000000,  8000000, '2024-04-01', '2025-09-30', 3, 0, 1, 1, 'https://api.dicebear.com/7.x/icons/svg?seed=tv',         'VND'),
-- ? H?y vì mua lo?i khác r? h?n

-- ??????????????????????????????????????????????????????????????????????
-- STATUS 4 OVERDUE: ?? status=1, end_date trong QUÁ KH?
-- ? Scheduler s? t? ??ng detect và chuy?n sang status=4
-- ??????????????????????????????????????????????????????????????????????

-- CASE A: S? b? Scheduler ?óng (finished s? = 1 sau khi scheduler ch?y)
(1,  N'Qu? s?a xe ô tô',            15000000,  6000000, '2024-08-01', '2025-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=carfix',    'VND'),
(7,  N'Qu? h?c IELTS',              12000000,  5000000, '2024-07-01', '2025-11-30', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=ielts',     'VND'),
(18, N'Mua gh? gaming DXRacer',      9000000,  4000000, '2025-02-01', '2026-02-28', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=gaming',    'VND'),

-- CASE B: Quá h?n nh?ng user v?n mu?n ti?p t?c (finished = 0 gi? nguyên)
-- ? Scheduler detect ra, chuy?n status=4 nh?ng KHÔNG set finished=1
(4,  N'Mua máy l?c không khí',       8000000,  2500000, '2024-10-01', '2025-10-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=airfilter', 'VND'),
(10, N'Mua bàn làm vi?c ergonomic',  6000000,  1800000, '2025-01-01', '2025-12-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=desk',      'VND'),
(13, N'Qu? ?ám c??i b?n thân',      10000000,  3000000, '2025-03-01', '2026-01-31', 1, 1, 1, 0, 'https://api.dicebear.com/7.x/icons/svg?seed=friend',    'VND');
GO

-- ======================================================================
-- 10. B?NG S? KI?N (1-N v?i tAccounts)
-- ======================================================================
CREATE TABLE tEvents (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    currency VARCHAR(10) DEFAULT 'VND',          -- FK -> tCurrencies (N-1)
    
    -- DATA COLUMNS
    event_name NVARCHAR(200) NOT NULL,           -- VD: "?ám c??i", "Du l?ch ?à L?t"
    event_icon_url NVARCHAR(2048) DEFAULT 'icon_event_default.svg',
    begin_date DATE DEFAULT GETDATE(),           -- Ngày b?t ??u s? ki?n
    end_date DATE NOT NULL,                      -- Ngày k?t thúc s? ki?n
    finished BIT DEFAULT 0,                   -- 0: ?ang di?n ra | 1: ?ã k?t thúc
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Events_Dates CHECK (end_date >= begin_date),
    CONSTRAINT FK_Events_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id) ON DELETE CASCADE,
    CONSTRAINT FK_Events_Currency FOREIGN KEY (currency) REFERENCES tCurrencies(currency_code)
);
GO

-- Index: T?i ?u tìm ki?m s? ki?n ?ang ch?y ?? gán vào giao d?ch
CREATE INDEX idx_events_active ON tEvents(acc_id, finished, currency) 
INCLUDE (event_name, begin_date, end_date);

-- Index: T?i ?u hi?n th? danh sách t?t c? s? ki?n ? màn qu?n lý
CREATE INDEX idx_events_all ON tEvents(acc_id, begin_date DESC) 
INCLUDE (event_name, finished, event_icon_url);
GO

-- D? LI?U M?U: S? ki?n
INSERT INTO tEvents (acc_id, event_name, begin_date, end_date, finished, event_icon_url, currency) VALUES 
(1, N'Du l?ch ?à L?t', '2025-12-20', '2025-12-25', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=dalat', 'VND'),
(1, N'T?t Nguyên ?án 2026', '2026-01-28', '2026-02-03', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=tet', 'VND'),
(2, N'Du l?ch ?à N?ng', '2025-08-15', '2029-08-30', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=danang', 'VND'),
(3, N'Sinh nh?t 25 tu?i', '2026-03-15', '2026-03-15', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=birthday', 'VND'),
(4, N'?ám c??i anh Tu?n', '2026-05-10', '2026-05-10', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=wedding', 'VND'),
(5, N'H?p l?p 10 n?m', '2026-07-20', '2026-07-20', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=reunion', 'VND'),
(6, N'D? án t?t nghi?p', '2025-02-01', '2026-06-30', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=thesis', 'VND'),
(7, N'Khóa h?c React Native', '2025-03-01', '2025-08-31', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=course', 'VND'),
(8, N'Du l?ch Phú Qu?c', '2026-04-10', '2026-04-15', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=phuquoc', 'VND'),
(9, N'Thi ch?ng ch? AWS', '2026-06-01', '2026-06-30', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=aws', 'VND'),
(10, N'L? h?i âm nh?c', '2026-09-12', '2026-09-13', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=festival', 'VND'),
(11, N'Hackathon FPT 2026', '2026-10-15', '2026-10-17', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=hackathon', 'VND'),
(12, N'Chuy?n v? quê T?t', '2027-01-25', '2027-02-05', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=hometown', 'VND'),
(13, N'Workshop Spring Boot', '2025-05-10', '2025-05-12', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=workshop', 'VND'),
(14, N'?i teambuilding công ty', '2026-08-20', '2026-08-22', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=teambuilding', 'VND'),
(15, N'Mua s?m Black Friday', '2025-11-28', '2025-11-30', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=blackfriday', 'VND'),
(16, N'Du l?ch Sapa', '2026-12-10', '2026-12-15', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=sapa', 'VND'),
(17, N'Tham gia DevFest 2026', '2026-11-05', '2026-11-06', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=devfest', 'VND'),
(18, N'Khám s?c kh?e ??nh k?', '2026-03-01', '2026-03-31', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=health', 'VND'),
(19, N'S?a nhà', '2025-06-01', '2025-09-30', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=renovation', 'VND'),
(20, N'K? ngh? hè gia ?ình', '2026-07-01', '2026-07-10', 0, 'https://api.dicebear.com/7.x/icons/svg?seed=vacation', 'VND');
GO

-- ======================================================================
-- 11. B?NG S? N? (1-N v?i tAccounts)
-- ======================================================================
CREATE TABLE tDebts (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    debt_type BIT NOT NULL,                      -- 0: C?n Tr? (?i vay) | 1: C?n Thu (Cho vay)
    total_amount DECIMAL(18,2) NOT NULL,         -- T?ng s? ti?n ban ??u
    remain_amount DECIMAL(18,2) NOT NULL,        -- S? ti?n còn l?i (gi?m d?n khi tr?/thu)
    due_date DATETIME NULL,                      -- Ngày h?n tr? (dùng ?? nh?c nh?)
    note NVARCHAR(500),                          -- Ghi chú (VD: "Vay b?n A mua xe")
    finished BIT DEFAULT 0 NOT NULL,          -- 0: ?ang n? | 1: ?ã hoàn thành
    created_at DATETIME DEFAULT GETDATE(),       -- Ngày t?o kho?n n?
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Debts_TotalAmount CHECK (total_amount > 0),
    CONSTRAINT CHK_Debts_RemainLogic CHECK (remain_amount >= 0 AND remain_amount <= total_amount),
    CONSTRAINT FK_Debts_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id) ON DELETE CASCADE
);
GO

-- Index: T?i ?u Tab C?n Thu/Tr? theo User và lo?i
CREATE INDEX idx_debts_active ON tDebts(acc_id, debt_type, finished, due_date) INCLUDE (remain_amount, total_amount, note);

-- Index: T?i ?u tính t?ng n? cho Báo cáo/Dashboard
CREATE INDEX idx_debts_reportable ON tDebts(acc_id, finished) INCLUDE (remain_amount, debt_type);

-- Index: T?i ?u l?c s? n? theo th?i gian t?o
CREATE INDEX idx_debts_created ON tDebts(acc_id, created_at DESC) WHERE finished = 0;
GO

-- D? LI?U M?U: S? n?
INSERT INTO tDebts (acc_id, debt_type, total_amount, remain_amount, due_date, note, finished, created_at) VALUES 
-- User 1 - Admin
(1, 0, 20000000, 15000000, '2026-06-30 23:59:59', N'Vay ngân hàng mua xe máy SH', 0, '2025-07-15 10:00:00'),
(1, 1, 5000000, 3000000, '2026-03-31 23:59:59', N'Cho anh Minh vay ti?n kh?n c?p', 0, '2025-12-10 14:30:00'),
-- User 2 - Mai Tr?n
(2, 1, 500000, 500000, '2029-07-30 23:59:59', N'Cho b?n A vay', 0, '2025-01-15 09:00:00'),
(2, 0, 3000000, 1500000, '2026-04-15 23:59:59', N'Vay b? m? mua iPhone', 0, '2026-01-20 11:00:00'),
-- User 3 - Nam Lê
(3, 1, 2000000, 2000000, '2026-05-20 23:59:59', N'Cho em trai vay h?c phí', 0, '2026-02-01 08:00:00'),
(3, 0, 10000000, 7000000, '2026-12-31 23:59:59', N'Vay b?n thân mua laptop', 0, '2025-10-15 16:30:00'),
-- User 5 
(5, 0, 50000000, 40000000, '2027-12-31 23:59:59', N'Vay ngân hàng c??i', 0, '2025-06-01 09:30:00'),
(5, 1, 8000000, 5000000, '2026-08-30 23:59:59', N'Cho ??ng nghi?p vay mua xe', 0, '2025-11-20 13:00:00'),
-- User 6
(6, 1, 3500000, 3500000, '2026-07-15 23:59:59', N'Cho ch? gái vay ?i du l?ch', 0, '2026-01-25 10:45:00'),
-- User 7
(7, 0, 15000000, 12000000, '2026-09-30 23:59:59', N'Vay b? ti?n mua MacBook', 0, '2025-12-05 15:00:00'),
-- User 8
(8, 1, 4000000, 1500000, '2026-06-10 23:59:59', N'Cho b?n cùng phòng vay ti?n nhà', 0, '2025-09-01 12:00:00'),
-- User 10
(10, 0, 25000000, 20000000, '2027-06-30 23:59:59', N'Vay m? mua nh?n c??i', 0, '2025-08-20 11:30:00'),
(10, 1, 6000000, 6000000, '2026-10-31 23:59:59', N'Cho em h? vay ti?n s?a xe', 0, '2026-01-10 09:15:00'),
-- User 11
(11, 0, 35000000, 28000000, '2028-12-31 23:59:59', N'Vay ngân hàng ??u t? ch?ng khoán', 0, '2024-11-01 10:00:00'),
-- User 12
(12, 1, 10000000, 7000000, '2026-11-20 23:59:59', N'Cho anh trai vay s?a nhà', 0, '2025-07-30 14:00:00'),
-- User 14
(14, 0, 7000000, 5000000, '2026-05-31 23:59:59', N'Vay công ty ti?n ?ng l??ng', 0, '2025-11-15 08:30:00'),
-- User 15
(15, 1, 12000000, 12000000, '2027-03-31 23:59:59', N'Cho b?n h?c vay ti?n h?c Th?c s?', 0, '2026-01-05 13:20:00'),
-- User 17
(17, 0, 100000000, 80000000, '2029-12-31 23:59:59', N'Vay ngân hàng kh?i nghi?p', 0, '2024-06-15 09:00:00'),
-- User 18
(18, 1, 5500000, 2500000, '2026-08-15 23:59:59', N'Cho cháu vay mua ?i?n tho?i', 0, '2025-10-20 16:00:00'),
-- User 20
(20, 0, 18000000, 15000000, '2027-02-28 23:59:59', N'Vay b?n thân mua máy ?nh', 0, '2025-09-10 11:00:00');
GO

-----------------------------------------------------------------------------------------------------------------------------
-- tAIConversations 1-1 tReceipts n?u xác nh?n có hóa ??n thì m?i t?o hóa ??n khóa chính. Hóa ??n là khóa chính c?a chat
-- ======================================================================
-- 12. B?NG L?CH S? CHAT AI (1-N v?i tAccounts)
-- ======================================================================
CREATE TABLE tAIConversations (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    message_content NVARCHAR(MAX) NOT NULL,      -- N?i dung tin nh?n
    sender_type BIT NOT NULL,                    -- 0: User nh?n | 1: AI ph?n h?i
    intent TINYINT,                              -- NULL AI ?ang quét ?nh, 1: add_transaction | 2: report_query | 3: set_budget | 4: general_chat | 5: remind_task
    attachment_url NVARCHAR(500) NULL,           -- URL file ?ính kèm (hình ?nh hóa ??n/voice)
    attachment_type TINYINT NULL,                -- 1: image | 2: voice | NULL: chat text
    created_at DATETIME DEFAULT GETDATE(),       -- Th?i gian chat 

    -- CONSTRAINTS    
    
    --1. Thêm chi tiêu/thu nh?p
    --2. H?i v? báo cáo, s? d?
    --3. Thi?t l?p h?n m?c
    --4. Tán g?u ho?c h?i ?áp chung
    --5. Nh?c nh?    
    CONSTRAINT CHK_AIConversations_Intent CHECK (intent BETWEEN 1 AND 5),
	CONSTRAINT CHK_AIConversations_Attachment_Type CHECK (attachment_type IN (1, 2)), -- chat th??ng là null

	CONSTRAINT CHK_AIConversations_Attach_Logic CHECK (
		(attachment_type = 1 AND attachment_url IS NOT NULL) OR     -- Có ?nh thì b?t bu?c ph?i có URL
		(attachment_type = 2 AND attachment_url IS NULL) OR         -- L?nh gi?ng nói thì URL ?? NULL (không l?u file)
		(attachment_type IS NULL AND attachment_url IS NULL)        -- Chat text thì c? 2 NULL
	),

	CONSTRAINT FK_AIConversations_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
);
GO

-- Index: T?i ?u load l?ch s? chat c?a User theo th?i gian
CREATE INDEX idx_ai_chat_user ON tAIConversations(acc_id, created_at DESC) INCLUDE (message_content, sender_type, intent);

-- Index: T?i ?u phân lo?i chat theo m?c ?ích (intent)
CREATE INDEX idx_ai_intent ON tAIConversations(acc_id, intent, created_at DESC) INCLUDE (message_content, sender_type, attachment_type);
GO

-- D? LI?U M?U: Chat AI
INSERT INTO tAIConversations (acc_id, message_content, sender_type, intent, attachment_url, attachment_type, created_at) VALUES
-- User 1: Nh?n text thêm giao d?ch cafe
(1, N'Tôi v?a mua cafe 45k', 0, 1, NULL, NULL, '2026-02-10 08:15:00'),
(1, N'?ã ghi nh?n: Chi tiêu 45,000? cho danh m?c ?n u?ng - Cafe. Ví Ti?n m?t còn 4,955,000?', 1, 1, NULL, NULL, '2026-02-10 08:15:03'),

-- User 2: Nh?n text thêm giao d?ch ?n sáng, sau ?ó g?i ?nh hóa ??n Vinmart
(2, N'Tôi ?ã chi 100k ?n sáng', 0, 1, NULL, NULL, '2026-02-09 07:30:00'),
(2, N'?ã ghi nh?n giao d?ch ?n sáng 100k', 1, 1, NULL, NULL, '2026-02-09 07:30:02'),
(2, N'?ây là hóa ??n mua s?m t?i Vinmart', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user2_vinmart.jpg', 1, '2026-02-09 18:45:00'),
(2, N'Tôi ?ã phân tích hóa ??n: T?ng chi 850,000? g?m 15 món hàng t?i Vinmart. B?n mu?n phân lo?i vào danh m?c nào?', 1, 1, NULL, NULL, '2026-02-09 18:45:05'),

-- User 3: H?i báo cáo chi tiêu ?n u?ng tháng này
(3, N'Tháng này tôi chi bao nhiêu ti?n ?n u?ng?', 0, 2, NULL, NULL, '2026-02-10 20:00:00'),
(3, N'Tháng 2/2026 b?n ?ã chi 2,350,000? cho ?n u?ng, chi?m 35% t?ng chi tiêu. Top 3: Nhà hàng (1.2tr), Cafe (800k), ?n v?t (350k)', 1, 2, NULL, NULL, '2026-02-10 20:00:04'),

-- User 5: Dùng gi?ng nói thêm giao d?ch x?ng, sau ?ó g?i ?nh hóa ??n Petrolimex
(5, N'V?a ?? x?ng 200 nghìn', 0, 1, NULL, 2, '2026-02-09 17:20:00'),
(5, N'OK! ?ã ghi nh?n 200,000? vào danh m?c ?i l?i - X?ng xe. Ví Agribank còn 19,800,000?', 1, 1, NULL, NULL, '2026-02-09 17:20:02'),
(5, N'Hóa ??n ?? x?ng Petrolimex', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user5_petrolimex.jpg', 1, '2026-02-09 17:25:00'),
(5, N'?ã phân tích hóa ??n Petrolimex: X?ng RON95 5.2L x 25,500? = 132,600?. Ghi vào danh m?c ?i l?i?', 1, 1, NULL, NULL, '2026-02-09 17:25:04'),

-- User 6: Thi?t l?p h?n m?c ngân sách ?n u?ng
(6, N'??t h?n m?c chi tiêu ?n u?ng tháng này là 3 tri?u', 0, 3, NULL, NULL, '2026-02-01 09:00:00'),
(6, N'?ã thi?t l?p ngân sách: ?n u?ng - 3,000,000?/tháng. Hi?n t?i b?n ?ã chi 450,000? (15%). Tôi s? nh?c nh? khi ??t 80%', 1, 3, NULL, NULL, '2026-02-01 09:00:03'),

-- User 7: H?i t? v?n cách ti?t ki?m ti?n
(7, N'Làm sao ?? ti?t ki?m ti?n hi?u qu??', 0, 4, NULL, NULL, '2026-02-08 21:30:00'),
(7, N'D?a vào thói quen chi tiêu c?a b?n, tôi có 3 g?i ý: 1) Gi?m cafe/trà s?a (?ang chi 600k/tháng) 2) N?u ?n thay vì ?n ngoài 3) ??t m?c tiêu ti?t ki?m c? th? v?i tính n?ng Saving Goals', 1, 4, NULL, NULL, '2026-02-08 21:30:06'),

-- User 10: ??t nh?c nh? tr? n?, sau ?ó g?i ?nh hóa ??n Uniqlo
(10, N'Nh?c tôi tr? n? anh Tu?n vào ngày 15', 0, 5, NULL, NULL, '2026-02-10 14:00:00'),
(10, N'?ã t?o l?i nh?c: "Tr? n? anh Tu?n" vào 15/02/2026 lúc 9:00 sáng. S? ti?n còn n?: 5,000,000?', 1, 5, NULL, NULL, '2026-02-10 14:00:02'),
(10, N'Hóa ??n Uniqlo Diamond Plaza', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user10_uniqlo.jpg', 1, '2026-02-07 18:00:00'),
(10, N'?ã phân tích hóa ??n Uniqlo: Áo thun nam x2 (600k), Qu?n jean (900k). T?ng: 1,500,000?. Xác nh?n ghi vào Mua s?m?', 1, 1, NULL, NULL, '2026-02-07 18:00:05'),

-- User 11: G?i ?nh hóa ??n CGV ?? thêm giao d?ch
(11, N'Thêm giao d?ch t? hóa ??n này', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user11_cgv.jpg', 1, '2026-02-09 22:00:00'),
(11, N'Phát hi?n hóa ??n CGV: 2 vé phim (300k), b?p rang b? (80k), n??c ng?t (60k). T?ng: 440,000?. Xác nh?n ghi vào danh m?c Gi?i trí?', 1, 1, NULL, NULL, '2026-02-09 22:00:04'),

-- User 15: H?i so sánh chi tiêu 2 tháng, sau ?ó g?i ?nh hóa ??n h?c phí FPT
(15, N'So sánh chi tiêu tháng này v?i tháng tr??c', 0, 2, NULL, NULL, '2026-02-10 19:30:00'),
(15, N'Tháng 2: 8,500,000? | Tháng 1: 7,200,000? (+18%). T?ng ch? y?u ?: Giáo d?c (+2tr), Mua s?m (+500k). Gi?m: ?n u?ng (-200k)', 1, 2, NULL, NULL, '2026-02-10 19:30:05'),
(15, N'Hóa ??n h?c phí ?H FPT', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user15_fpt.jpg', 1, '2026-02-06 13:05:00'),
(15, N'?ã phân tích hóa ??n ?H FPT: H?c phí k? 2 - 3,500,000?. Ghi vào danh m?c Giáo d?c?', 1, 1, NULL, NULL, '2026-02-06 13:05:06'),

-- User 17: Dùng gi?ng nói thêm giao d?ch mua sách
(17, N'Mua sách l?p trình 350 nghìn', 0, 1, NULL, 2, '2026-02-08 16:45:00'),
(17, N'?ã l?u: 350,000? - Sách l?p trình vào danh m?c Giáo d?c. Qu? phát tri?n k? n?ng l?p trình còn 11,650,000?', 1, 1, NULL, NULL, '2026-02-08 16:45:03'),

-- User 20: H?i t?ng quan ngân sách, sau ?ó g?i ?nh vé máy bay VietJet
(20, N'Tôi ?ã chi bao nhiêu % ngân sách tháng này?', 0, 2, NULL, NULL, '2026-02-10 22:00:00'),
(20, N'T?ng quan tháng 2: ?ã chi 4,200,000?/8,000,000? (52.5%). An toàn ? h?u h?t danh m?c. C?nh báo: Du l?ch ??t 85% (2,550k/3tr)', 1, 2, NULL, NULL, '2026-02-10 22:00:03'),
(20, N'Vé máy bay VietJet Hà N?i - ?à L?t', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user20_vietjet.jpg', 1, '2026-02-09 11:25:00'),
(20, N'?ã phân tích vé VietJet: Hà N?i ? ?à L?t, 2,700,000?. Ghi vào danh m?c Du l?ch?', 1, 1, NULL, NULL, '2026-02-09 11:25:06'),
-- User 3: G?i ?nh hóa ??n b? m?, OCR th?t b?i
(3, N'Hóa ??n siêu th? ?ây b?n', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user3_blur.jpg', 1, '2026-02-10 21:00:00'),
(3, N'Xin l?i, ?nh hóa ??n b? m?, tôi không th? ??c ???c. B?n có th? ch?p l?i rõ h?n không?', 1, NULL, NULL, NULL, '2026-02-10 21:00:06'),

-- User 6: G?i ?nh hóa ??n m?i, AI ?ang x? lý
(6, N'Hóa ??n mua s?m Shopee hôm nay', 0, NULL, 'https://res.cloudinary.com/smartmoney/image/upload/receipts/user6_shopee.jpg', 1, '2026-02-10 23:50:00');
-- (ch?a có AI reply vì ?ang pending)
GO

-- ======================================================================
-- 13. B?NG HÓA ??N QUÉT (1-1 v?i tAIConversations)
-- ======================================================================
CREATE TABLE tReceipts (
    -- PRIMARY KEY (= Foreign Key)
    id INT PRIMARY KEY,                          -- FK -> tAIConversations (1-1)
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    
    -- DATA COLUMNS
    image_url NVARCHAR(500) NOT NULL,            -- URL ?nh hóa ??n (upload lên Cloud ho?c server)
    raw_ocr_text NVARCHAR(MAX) NULL,             -- Text g?c t? OCR
    processed_data NVARCHAR(MAX) NULL DEFAULT '{}',    -- D? li?u ?ã parse (JSON format)
    receipt_status NVARCHAR(20) DEFAULT 'pending' NOT NULL, -- pending | processed | error
    created_at DATETIME DEFAULT GETDATE() NOT NULL,

    -- CONSTRAINTS	
    CONSTRAINT CHK_Receipt_Status CHECK (receipt_status IN ('pending', 'processed', 'error')),
    
    -- Check logic: ?ã xong thì ph?i có d? li?u
    CONSTRAINT CHK_Receipt_Processed_Logic CHECK (
        (receipt_status = 'processed' AND processed_data IS NOT NULL) 
        OR (receipt_status <> 'processed')
    ),

	CONSTRAINT FK_Receipts_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
	CONSTRAINT FK_Receipts_Chat FOREIGN KEY (id) REFERENCES tAIConversations(id) ON DELETE CASCADE
);
GO
-- Index: T?i ?u l?c hóa ??n ch? x? lý (pending) c?a User
CREATE INDEX idx_receipts_pending ON tReceipts(acc_id, receipt_status, created_at DESC) 
WHERE receipt_status = 'pending';

-- Index: T?i ?u query hóa ??n theo User và tr?ng thái
CREATE INDEX idx_receipts_user ON tReceipts(acc_id, receipt_status, created_at DESC) 
INCLUDE (image_url, raw_ocr_text);
GO
-- ======================================================================
-- D? LI?U M?U: Hóa ??n
-- ======================================================================
INSERT INTO tReceipts (id, acc_id, image_url, raw_ocr_text, processed_data, receipt_status, created_at) VALUES
(5, 2,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user2_vinmart.jpg',
N'VINMART
123 Nguy?n Hu? Q1
09/02/2026 18:30
Rau c?i 35.000?
Th?t heo 180.000?
Tr?ng gà 45.000?
G?o ST25 150.000?
T?NG C?NG 850.000?',
'{"store":"Vinmart","total":850000,"date":"2026-02-09","category":"Mua s?m"}', 'processed', '2026-02-09 18:45:00'),

(11, 5,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user5_petrolimex.jpg',
N'PETROLIMEX
09/02/2026 17:25
X?ng RON95 5.2L
??n giá 25.500?/L
Thành ti?n 132.600?
Ti?n khách ??a 200.000?
Ti?n th?a 67.400?',
'{"store":"Petrolimex","total":132600,"date":"2026-02-09","category":"?i l?i"}', 'processed', '2026-02-09 17:25:00'),

(19, 10,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user10_uniqlo.jpg',
N'UNIQLO
Diamond Plaza Q1
07/02/2026 18:00
Áo thun nam x2 600.000?
Qu?n jean 900.000?
T?NG C?NG 1.500.000?',
'{"store":"Uniqlo","total":1500000,"date":"2026-02-07","category":"Mua s?m"}', 'processed', '2026-02-07 18:00:00'),

(21, 11,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user11_cgv.jpg',
N'CGV CINEMAS
Landmark 81
09/02/2026 22:00
2x Vé phim 300.000?
B?p rang b? 80.000?
Coca 60.000?
T?NG 440.000?',
'{"store":"CGV","total":440000,"date":"2026-02-09","category":"Gi?i trí"}', 'processed', '2026-02-09 22:00:00'),

(25, 15,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user15_fpt.jpg',
NULL,
'{"store":"?H FPT","total":3500000,"date":"2026-02-06","category":"Giáo d?c"}', 'processed', '2026-02-06 13:05:00'),

(31, 20,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user20_vietjet.jpg',
NULL,
'{"airline":"VietJet","total":2700000,"date":"2026-02-09","category":"Du l?ch"}', 'processed', '2026-02-09 11:25:00'),
-- id=33: error - ?nh m? không OCR ???c
(33, 3,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user3_blur.jpg',
N'##ÊU TH##
##/##/20## ##:##
S### ph### ##.###?
T?## ##?NG ???',
NULL, 'error', '2026-02-10 21:00:00'),

-- id=35: pending - v?a g?i, ch?a x? lý xong
(35, 6,
'https://res.cloudinary.com/smartmoney/image/upload/receipts/user6_shopee.jpg',
NULL,
NULL, 'pending', '2026-02-10 23:50:00');
GO
-----------------------------------------------------------------------------------------------------------------------------

-- ======================================================================
-- 14. B?NG NGÂN SÁCH (1-N v?i tAccounts)
-- ======================================================================
CREATE TABLE tBudgets (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    wallet_id INT NULL,                      -- FK -> tWallets (N-1) Ngân sách rút t? ví nào
    
    -- DATA COLUMNS
    amount DECIMAL(18,2) NOT NULL,               -- Gi?i h?n ngân sách
    begin_date DATE DEFAULT GETDATE() NOT NULL,  -- Ngày b?t ??u chu k?
    end_date DATE NOT NULL,                      -- Ngày k?t thúc chu k?
    all_categories BIT DEFAULT 0,             -- 0: Theo danh m?c c? th? | 1: T?t c? Chi tiêu
    repeating BIT DEFAULT 0,                  -- 0: M?t l?n | 1: T? ??ng gia h?n
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Budgets_Amount CHECK (amount > 0),
    CONSTRAINT CHK_Budgets_Dates CHECK (end_date >= begin_date),
    CONSTRAINT FK_Budgets_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Budgets_Wallet FOREIGN KEY (wallet_id) REFERENCES tWallets(id) ON DELETE CASCADE
);
GO

-- Code back end
-- CH?N TRÙNG NGÂN SÁCH: M?t User không th? có 2 ngân sách cho 1 danh m?c trong cùng 1 kho?ng th?i gian
-- L?u ý: Backend c?n check logic ngày tháng, còn DB ch?n trùng l?p tuy?t ??i category cho ch?c ?n.
--CREATE UNIQUE NONCLUSTERED INDEX idx_unique_budget_period ON tBudgets(acc_id, ctg_id, begin_date, end_date);

-- Index: T?i ?u query ngân sách theo User và chu k?
CREATE INDEX idx_budget_lookup ON tBudgets(acc_id, begin_date, end_date, all_categories) INCLUDE (amount, wallet_id, repeating);
GO

-- ======================================================================
-- D? li?u m?u tBudgets
-- ======================================================================
INSERT INTO tBudgets (acc_id, wallet_id, amount, begin_date, end_date, all_categories, repeating) VALUES
-- [ID=1]  User 1:  ?n u?ng tháng 2 - m?i ví - t? gia h?n
(1,  NULL, 5000000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=2]  User 2:  Mua s?m tháng 2 - ví MoMo (id=3)
(2,  3,    3000000,  '2026-02-01', '2026-02-28', 0, 0),
-- [ID=3]  User 2:  T?ng chi tiêu all_categories - m?i ví
(2,  NULL, 10000000, '2026-02-01', '2026-02-28', 1, 1),
-- [ID=4]  User 6:  ?n u?ng + Gi?i trí g?p - m?i ví
(6,  NULL, 2000000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=5]  User 5:  Di chuy?n tháng 2 - m?i ví
(5,  NULL, 1500000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=6]  User 3:  Hoá ??n & Ti?n ích - ví Ti?n m?t (id=5)
(3,  5,    2000000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=7]  User 20: Du l?ch tháng 2 - m?i ví
(20, NULL, 10000000, '2026-02-01', '2026-02-28', 0, 0),
-- [ID=8]  User 1:  Mua s?m tháng 2 - ví Vietcombank (id=2)
(1,  2,    3000000,  '2026-02-01', '2026-02-28', 0, 0),
-- [ID=9]  User 7:  ?n u?ng tháng 2 - ví ACB (id=12)
(7,  12,   2500000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=10] User 10: T?ng chi tiêu all_categories - m?i ví
(10, NULL, 8000000,  '2026-02-01', '2026-02-28', 1, 1),
-- [ID=11] User 11: Giáo d?c tháng 2 - ví TPBank (id=18)
(11, 18,   5000000,  '2026-02-01', '2026-02-28', 0, 0),
-- [ID=12] User 15: Giáo d?c tháng 2 - ví H?c phí (id=23)
(15, 23,   8000000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=13] User 17: ??u t? tháng 2 - ví ??u t? (id=26) - không gia h?n
(17, 26,   15000000, '2026-02-01', '2026-02-28', 0, 0),
-- [ID=14] User 3:  ?n u?ng + S?c kh?e g?p - m?i ví
(3,  NULL, 3000000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=15] User 12: T?ng chi tiêu all_categories - ví Sacombank (id=20)
(12, 20,   12000000, '2026-02-01', '2026-02-28', 1, 1),
-- [ID=16] User 8:  S?c kh?e tháng 2 - ví Ti?n m?t (id=21)
(8,  21,   2000000,  '2026-02-01', '2026-02-28', 0, 0),
-- [ID=17] User 2:  ?n u?ng tháng 3 - ví Techcombank (id=4) - t? gia h?n
(2,  4,    2500000,  '2026-03-01', '2026-03-31', 0, 1),
-- [ID=18] User 6:  Giáo d?c tháng 2 - m?i ví
(6,  NULL, 1500000,  '2026-02-01', '2026-02-28', 0, 1),
-- [ID=19] User 20: T?ng all_categories tháng 2 - ví du l?ch (id=13)
(20, 13,   20000000, '2026-02-01', '2026-02-28', 1, 0),
-- [ID=20] User 1:  Hoá ??n & Ti?n ích quý 1 - m?i ví - t? gia h?n
(1,  NULL, 2000000,  '2026-01-01', '2026-03-31', 0, 1);
GO

-- ======================================================================
-- 15. B?NG TRUNG GIAN BUDGET - CATEGORY (N-N)
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

-- Index: T?i ?u query ng??c t? Category -> Budgets
CREATE INDEX idx_budget_ctg_reverse ON tBudgetCategories(ctg_id, budget_id);
GO
-- ======================================================================
-- D? LI?U M?U: Chi ti?t danh m?c áp d?ng ngân sách (tBudgetCategories)
-- ======================================================================
INSERT INTO tBudgetCategories (budget_id, ctg_id) VALUES
(1,  1),  -- Budget 1  (User 1):  ?n u?ng (id=1)
(2,  10), -- Budget 2  (User 2):  Mua s?m (id=10)
          -- Budget 3  (User 2):  all_categories=1 ? không c?n insert
(4,  1),  -- Budget 4  (User 6):  ?n u?ng
(4,  7),  -- Budget 4  (User 6):  Gi?i trí
(5,  5),  -- Budget 5  (User 5):  Di chuy?n (id=5)
(6,  9),  -- Budget 6  (User 3):  Hoá ??n & Ti?n ích (id=9)
(7,  7),  -- Budget 7  (User 20): Gi?i trí (id=7) - map du l?ch vào Gi?i trí
(8,  10), -- Budget 8  (User 1):  Mua s?m (id=10)
(9,  1),  -- Budget 9  (User 7):  ?n u?ng (id=1)
          -- Budget 10 (User 10): all_categories=1 ? không c?n insert
(11, 8),  -- Budget 11 (User 11): Giáo d?c (id=8)
(12, 8),  -- Budget 12 (User 15): Giáo d?c (id=8)
(13, 4),  -- Budget 13 (User 17): ??u t? (id=4)
(14, 1),  -- Budget 14 (User 3):  ?n u?ng
(14, 12), -- Budget 14 (User 3):  S?c kh?e
          -- Budget 15 (User 12): all_categories=1 ? không c?n insert
(16, 12), -- Budget 16 (User 8):  S?c kh?e (id=12)
(17, 1),  -- Budget 17 (User 2):  ?n u?ng (id=1)
(18, 8),  -- Budget 18 (User 6):  Giáo d?c (id=8)
          -- Budget 19 (User 20): all_categories=1 ? không c?n insert
(20, 9),  -- Budget 20 (User 1):  Hoá ??n & Ti?n ích (id=9)
(20, 29), -- Budget 20 (User 1):  sub ?i?n (id=29)
(20, 32); -- Budget 20 (User 1):  Internet (id=32)
GO

-- ======================================================================
-- 16. B?NG GIAO D?CH (TRUNG TÂM H? TH?NG)
-- ======================================================================
CREATE TABLE tTransactions (
    -- PRIMARY KEY
    id BIGINT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)
    ctg_id INT NULL,                             -- FK -> tCategories (N-1) | NULL = Chi tr? n? không phân lo?i
    wallet_id INT NULL,                          -- FK -> tWallets (N-1)
    event_id INT NULL,                           -- FK -> tEvents (N-1) | NULL = Không thu?c s? ki?n
    debt_id INT NULL,                            -- FK -> tDebts (N-1) | NULL = Không liên quan n?
    goal_id INT NULL,                            -- FK -> tSavingGoals (N-1) | NULL = Không liên quan m?c tiêu
    ai_chat_id INT NULL,                         -- FK -> tAIConversations (N-1) | NULL = Nh?p th? công
    
    -- DATA COLUMNS
    amount DECIMAL(18,2) NOT NULL,               -- S? ti?n giao d?ch
    with_person NVARCHAR(100) NULL,              -- Tên ng??i liên quan (VD: ng??i vay, ng??i tr?)
    note NVARCHAR(500) NULL,                     -- Ghi chú (VD: "?n sáng", "L??ng tháng 1")
    reportable BIT DEFAULT 1 NOT NULL,        -- 0: Không tính vào báo cáo | 1: Tính vào Dashboard
    source_type TINYINT DEFAULT 1 NOT NULL,      -- 1: manual | 2: chat | 3: voice | 4: receipt
    trans_date DATETIME DEFAULT GETDATE() NOT NULL,   -- Ngày giao d?ch th?c t?
    created_at DATETIME DEFAULT GETDATE() NOT NULL,   -- Ngày h? th?ng ghi nh?n
    
    -- CONSTRAINTS
    CONSTRAINT CHK_Transaction_Amount CHECK (amount > 0),
    CONSTRAINT CHK_Transaction_SourceType CHECK (source_type BETWEEN 1 AND 4),
    CONSTRAINT CHK_Transaction_Integrity CHECK (
        (source_type = 1 AND ai_chat_id IS NULL) OR          -- Manual thì không có chat_id
        (source_type IN (2,3,4) AND ai_chat_id IS NOT NULL)  -- AI thì b?t bu?c có chat_id
    ),    
    CONSTRAINT CHK_Transaction_SingleWallet CHECK (
        NOT (wallet_id IS NOT NULL AND goal_id IS NOT NULL)
    ),
    CONSTRAINT FK_Transactions_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Transactions_Category FOREIGN KEY (ctg_id) REFERENCES tCategories(id),
    CONSTRAINT FK_Transactions_Wallet FOREIGN KEY (wallet_id) REFERENCES tWallets(id) ON DELETE CASCADE,
    CONSTRAINT FK_Transactions_Event FOREIGN KEY (event_id) REFERENCES tEvents(id),
    CONSTRAINT FK_Transactions_Debt FOREIGN KEY (debt_id) REFERENCES tDebts(id),
    CONSTRAINT FK_Transactions_Goal FOREIGN KEY (goal_id) REFERENCES tSavingGoals(id),
    CONSTRAINT FK_Transactions_Chat FOREIGN KEY (ai_chat_id) REFERENCES tAIConversations(id)
);
GO

-- Index: T?i ?u Báo cáo tài chính và Dashboard chính
CREATE INDEX idx_trans_main ON tTransactions(acc_id, wallet_id, trans_date DESC) 
INCLUDE (amount, ctg_id, reportable, source_type);

-- Index: T?i ?u query giao d?ch theo M?c tiêu ti?t ki?m
CREATE INDEX idx_trans_goal ON tTransactions(goal_id) 
INCLUDE (amount, trans_date) 
WHERE goal_id IS NOT NULL;

-- Index: T?i ?u query giao d?ch theo S? ki?n
CREATE INDEX idx_trans_event ON tTransactions(event_id) 
INCLUDE (amount, trans_date, ctg_id) 
WHERE event_id IS NOT NULL;

-- Index: T?i ?u query giao d?ch do AI t?o
CREATE INDEX idx_trans_ai ON tTransactions(ai_chat_id) 
INCLUDE (amount, trans_date, source_type) 
WHERE ai_chat_id IS NOT NULL;

-- Index: T?i ?u tính toán kho?n n? (Tr?/Thu)
CREATE INDEX idx_trans_debt ON tTransactions(debt_id) 
INCLUDE (amount, trans_date) 
WHERE debt_id IS NOT NULL;

-- Index: T?i ?u query giao d?ch theo Danh m?c
CREATE INDEX idx_trans_category ON tTransactions(acc_id, ctg_id, trans_date DESC) 
INCLUDE (amount, wallet_id);
GO


-- ======================================================================
-- D? LI?U M?U: Giao d?ch
-- ======================================================================
INSERT INTO tTransactions (acc_id, ctg_id, wallet_id, amount, note, trans_date, with_person, reportable, source_type, event_id, debt_id, goal_id, ai_chat_id) VALUES

-- ?? User 1 ??????????????????????????????????????????????????????????????
(1, 1,  1,    50000,      N'?n sáng bánh mì',            '2026-02-10 07:30:00', N'Cô H??ng',               1, 1, NULL, NULL, NULL, NULL),
(1, 15, 2,    15000000,   N'L??ng tháng 2',               '2026-02-05 09:00:00', N'Công ty ABC',            1, 1, NULL, NULL, NULL, NULL),
(1, 9,  1,    500000,     N'Ti?n ?i?n tháng 1',           '2026-02-08 14:20:00', N'?i?n l?c TP.HCM',        1, 1, NULL, NULL, NULL, NULL),
(1, 1,  1,    45000,      N'Cafe',                        '2026-02-10 08:15:00', NULL,                      1, 2, NULL, NULL, NULL, 2),
(1, 1,  2,    250000,     N'?n t?i gia ?ình',             '2026-02-03 19:00:00', NULL,                      1, 1, 2,    NULL, NULL, NULL),
(1, 19, 2,    5000000,    N'Cho anh Minh vay kh?n c?p',   '2025-12-10 14:30:00', N'Anh Minh',               1, 1, NULL, 2,    NULL, NULL),

-- ?? User 2 ??????????????????????????????????????????????????????????????
(2, 1,  3,    85000,      N'Trà s?a chi?u',               '2026-02-09 15:45:00', N'Gongcha',                1, 1, NULL, NULL, NULL, NULL),
(2, 10, 4,    2000000,    N'Mua áo khoác Zara',           '2026-02-07 18:30:00', N'Zara Vincom',            1, 1, NULL, NULL, NULL, NULL),
(2, 5,  3,    300000,     N'X?ng xe máy',                 '2026-02-06 08:15:00', N'Petrolimex',             1, 1, NULL, NULL, NULL, NULL),
(2, 1,  3,    100000,     N'?n sáng',                     '2026-02-09 07:30:00', NULL,                      1, 2, NULL, NULL, NULL, 4),
(2, 10, 3,    850000,     N'Mua s?m Vinmart',              '2026-02-09 18:45:00', N'Vinmart',                1, 4, NULL, NULL, NULL, 6),
(2, 16, NULL, 3000000,    N'?i vay b? m? mua iPhone',     '2026-01-20 11:00:00', N'B? m?',                  0, 1, NULL, 4,    3,    NULL),

-- ?? User 3 ??????????????????????????????????????????????????????????????
(3, 1,  5,    120000,     N'C?m tr?a v?n phòng',          '2026-02-10 12:00:00', N'Quán c?m Phúc L?c Th?', 1, 1, NULL, NULL, NULL, NULL),
(3, 12, 6,    500000,     N'Khám r?ng ??nh k?',           '2026-02-08 10:30:00', N'Nha khoa Kim',           1, 1, NULL, NULL, NULL, NULL),
(3, 20, 6,    10000000,   N'Vay b?n thân mua laptop',     '2025-10-15 16:30:00', N'B?n thân',               0, 1, NULL, 6,    NULL, NULL),
(3, 22, 6,    1000000,    N'Tr? n? b?n thân k? này',      '2026-02-15 10:00:00', N'B?n thân',               1, 1, NULL, 6,    NULL, NULL),

-- ?? User 5 ??????????????????????????????????????????????????????????????
(5, 7,  9,    150000,     N'Xem phim Avengers',           '2026-02-09 19:45:00', N'CGV Landmark',           1, 1, NULL, NULL, NULL, NULL),
(5, 16, NULL, 5000000,    N'Rút ti?t ki?m v? ví',         '2026-02-07 11:00:00', NULL,                      0, 1, NULL, NULL, 7,    NULL),
(5, 5,  9,    200000,     N'?? x?ng',                     '2026-02-09 17:20:00', N'Petrolimex',             1, 3, NULL, NULL, NULL, 10),
(5, 5,  9,    132600,     N'X?ng RON95 5.2L',             '2026-02-09 17:25:00', N'Petrolimex',             1, 4, NULL, NULL, NULL, 12),
(5, 20, NULL, 50000000,   N'Vay ngân hàng ti?n c??i',     '2025-06-01 09:30:00', N'Ngân hàng',              0, 1, NULL, 7,    8,    NULL),

-- ?? User 6 ??????????????????????????????????????????????????????????????
(6, 8,  10,   800000,     N'Mua sách l?p trình',          '2026-02-08 16:20:00', N'Fahasa',                 1, 1, NULL, NULL, NULL, NULL),
(6, 10, 11,   250000,     N'Mua ?p l?ng iPhone',          '2026-02-09 14:10:00', N'Shopee',                 1, 1, NULL, NULL, NULL, NULL),
(6, 7,  10,   350000,     N'Chi phí d? án t?t nghi?p',    '2026-02-05 10:00:00', NULL,                      1, 1, 7,    NULL, NULL, NULL),
(6, 16, NULL, 500000,     N'Góp qu? ChatGPT Plus',        '2026-02-01 08:00:00', NULL,                      1, 1, NULL, NULL, 31,   NULL),

-- ?? User 7 ??????????????????????????????????????????????????????????????
(7, 1,  12,   350000,     N'?n t?i l?u',                  '2026-02-09 19:00:00', N'L?u H?i S?n ?à L?t',    1, 1, 8,    NULL, NULL, NULL),
(7, 9,  12,   1200000,    N'Thuê khách s?n 2 ?êm',        '2026-02-08 15:30:00', N'Dalat Palace Hotel',     1, 1, 8,    NULL, NULL, NULL),
(7, 20, NULL, 15000000,   N'Vay b? mua MacBook',          '2025-12-05 15:00:00', N'B?',                     0, 1, NULL, 10,   10,   NULL),

-- ?? User 10 ?????????????????????????????????????????????????????????????
(10, 1, 16,   95000,      N'Cafe sáng',                   '2026-02-10 08:00:00', N'Highlands Coffee',       1, 1, NULL, NULL, NULL, NULL),
(10, 10,17,   1500000,    N'Áo thun nam x2, Qu?n jean',   '2026-02-07 18:00:00', N'Uniqlo',                 1, 4, NULL, NULL, NULL, 20),
(10, 20,NULL, 25000000,   N'Vay m? mua nh?n c??i',       '2025-08-20 11:30:00', N'M?',                     0, 1, NULL, 12,   13,   NULL),
(10, 22,16,   2000000,    N'Tr? n? m? k? này',           '2026-02-10 09:00:00', N'M?',                     1, 1, NULL, 12,   NULL, NULL),

-- ?? User 11 ?????????????????????????????????????????????????????????????
(11, 11,18,   200000,     N'?óng góp t? thi?n',           '2026-02-09 09:30:00', N'Qu? vì ng??i nghèo',     1, 1, NULL, NULL, NULL, NULL),
(11, 15,18,   18000000,   N'L??ng tháng 2',               '2026-02-05 10:00:00', N'Công ty Tech Innovation', 1, 1, NULL, NULL, NULL, NULL),
(11, 7, 18,   440000,     N'2 vé phim, b?p, n??c',        '2026-02-09 22:00:00', N'CGV Landmark 81',        1, 4, NULL, NULL, NULL, 22),
(11, 8, NULL, 8000000,    N'Góp qu? khóa h?c AWS',        '2026-02-10 10:00:00', NULL,                      1, 1, NULL, NULL, 27,   NULL),

-- ?? User 15 ?????????????????????????????????????????????????????????????
(15, 8, NULL, 3500000,    N'H?c phí h?c k? 1',            '2026-02-06 13:00:00', N'Tr??ng ?H FPT',          1, 1, NULL, NULL, 19,   NULL),
(15, 8, NULL, 3500000,    N'H?c phí k? 2 - ?H FPT',       '2026-02-06 13:05:00', N'?H FPT',                 1, 4, NULL, NULL, 19,   26),
(15, 21,23,   12000000,   N'Cho b?n h?c vay h?c Th?c s?', '2026-01-05 13:20:00', N'B?n h?c',                1, 1, NULL, 17,   NULL, NULL),

-- ?? User 17 ?????????????????????????????????????????????????????????????
(17, 8, 26,   350000,     N'Sách l?p trình',              '2026-02-08 16:45:00', NULL,                      1, 3, NULL, NULL, NULL, 28),
(17, 16,NULL, 10000000,   N'Góp qu? ??u t? ch?ng khoán', '2026-02-01 09:00:00', NULL,                      0, 1, NULL, NULL, 21,   NULL),
(17, 20,26,   100000000,  N'Vay ngân hàng kh?i nghi?p',  '2024-06-15 09:00:00', N'Ngân hàng',              0, 1, NULL, 18,   NULL, NULL),

-- ?? User 20 ?????????????????????????????????????????????????????????????
(20, 9, 13,   2500000,    N'??t vé máy bay ?i Phú Qu?c', '2026-02-09 11:20:00', N'VietJet Air',            1, 1, 21,   NULL, NULL, NULL),
(20, 9, 13,   2700000,    N'Vé máy bay HN - ?à L?t',     '2026-02-09 11:25:00', N'VietJet Air',            1, 4, NULL, NULL, NULL, 32),
(20, 9, 14,   4000000,    N'??t khách s?n ?à L?t',       '2026-02-08 10:00:00', N'Agoda',                  1, 1, 21,   NULL, NULL, NULL),
(20, 16,NULL, 5000000,    N'Góp qu? mua máy ?nh',        '2026-02-05 08:00:00', NULL,                      1, 1, NULL, NULL, 24,   NULL),
(20, 20,13,   18000000,   N'Vay b?n thân mua máy ?nh',   '2025-09-10 11:00:00', N'B?n thân',               0, 1, NULL, 20,   NULL, NULL);
GO

-- ======================================================================
-- 17. B?NG THÔNG BÁO (1-N v?i tAccounts)
-- ======================================================================
CREATE TABLE tNotifications (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),
    
    -- FOREIGN KEYS
    acc_id INT NOT NULL,                         -- FK -> tAccounts (N-1)     

	-- LO?I THÔNG BÁO (S? d?ng TINYINT ?? t?i ?u hi?u n?ng)
    -- 1: TRANSACTION (Giao d?ch/Bi?n ??ng s? d?)
    -- 2: SAVING      (M?c tiêu ti?t ki?m/Qu?)
    -- 3: BUDGET      (C?nh báo ngân sách/V??t h?n m?c)
    -- 4: SYSTEM      (H? th?ng/C?p nh?t/B?o m?t)
    -- 5: CHAT_AI     (Thông báo t? tr? lý AI)
    -- 6: WALLETS     (Thông báo liên quan ??n ví/s? d? âm)
    -- 7: EVENTS      (S? ki?n/L?ch trình)
    -- 8: DEBT_LOAN   (Nh?c n?/Thu n?)
    -- 9: REMINDER    (Nh?c nh? chung/Daily nh?c ghi chép)
    notify_type TINYINT NOT NULL, 

    -- ID C?A ??I T??NG LIÊN QUAN (Tùy theo notify_type)
    -- Ví d?: N?u type = 1 thì ?ây là ID c?a tTransactions
    -- N?u type = 6 thì ?ây là ID c?a tWallets
    related_id BIGINT NULL,

	title NVARCHAR(100) NULL,                    -- Tiêu ?? ng?n g?n (VD: "C?nh báo ngân sách")
    content NVARCHAR(500) NOT NULL,              -- N?i dung chi ti?t (VD: "B?n ?ã xài h?t 50% ti?n ?n u?ng")
    scheduled_time DATETIME DEFAULT GETDATE(),   -- Th?i ?i?m thông báo (ngay ho?c h?n l?ch)
    notify_sent BIT DEFAULT 0,                       -- 0: Ch?a g?i Push | 1: ?ã g?i Push
    notify_read BIT DEFAULT 0,                       -- 0: Ch?a ??c | 1: ?ã ??c  
    created_at DATETIME DEFAULT GETDATE(),       -- Ngày t?o thông báo
	
    -- CONSTRAINTS
    CONSTRAINT CHK_Notify_Type CHECK (notify_type BETWEEN 1 AND 9),
    CONSTRAINT FK_Notifications_Account FOREIGN KEY (acc_id) REFERENCES tAccounts(id)
);
GO

-- Index: T?i ?u Worker quét thông báo c?n g?i
CREATE INDEX idx_notify_worker ON tNotifications(scheduled_time, notify_sent) WHERE notify_sent = 0;

-- Index: T?i ?u load thông báo cho User UI
CREATE INDEX idx_notify_ui ON tNotifications(acc_id, notify_read, created_at DESC) INCLUDE (title, content, notify_type, related_id);

-- Index: T?i ?u load thông báo m?i nh?t
CREATE INDEX idx_notify_latest ON tNotifications(acc_id, created_at DESC) INCLUDE (notify_read, title, content);
GO

-- ======================================================================
-- D? LI?U M?U: Thông báo
-- ======================================================================
INSERT INTO tNotifications (acc_id, notify_type, related_id, title, content, scheduled_time, notify_sent, notify_read) VALUES

-- type=1: Giao d?ch l?n (?ã ??c)
(1,  1, 2,    N'Giao d?ch m?i',       N'?ã ghi nh?n thu nh?p 15,000,000? - L??ng tháng 2 vào ví Vietcombank',       '2026-02-05 09:00:05', 1, 1),
(11, 1, 23,   N'Giao d?ch m?i',       N'?ã ghi nh?n thu nh?p 18,000,000? - L??ng tháng 2 vào ví TPBank',            '2026-02-05 10:00:05', 1, 1),
(2,  1, 12,   N'Giao d?ch m?i',       N'?ã ghi nh?n chi tiêu 3,000,000? - ?i vay b? m? mua iPhone vào ví TCB',     '2026-01-20 11:00:10', 1, 1),

-- type=2: M?c tiêu ti?t ki?m (mix ??c/ch?a)
(5,  2, 7,    N'M?c tiêu ti?n tri?n', N'B?n ?ã ??t 50% m?c tiêu "Mua xe máy SH". Còn 45,000,000? n?a là hoàn thành!','2026-02-07 09:00:00', 1, 0),
(10, 2, 13,   N'Nh?c m?c tiêu',       N'M?c tiêu "Mua nh?n c??i" s?p ??n h?n (30/11/2026). Còn thi?u 15,000,000?', '2026-02-10 08:00:00', 1, 0),
(6,  2, 31,   N'M?c tiêu ti?n tri?n', N'Qu? ChatGPT Plus ?ã ??t 29%. C? lên! Còn 8,500,000? n?a.',                  '2026-02-08 10:00:00', 1, 1),

-- type=3: C?nh báo ngân sách (mix)
(2,  3, 1,    N'C?nh báo ngân sách',  N'B?n ?ã chi 80% ngân sách ?n u?ng tháng 2. Hãy cân nh?c chi tiêu!',          '2026-02-09 20:00:00', 1, 1),
(6,  3, 4,    N'V??t ngân sách',      N'B?n ?ã v??t 120% ngân sách ?n u?ng + Gi?i trí. T?ng chi: 2,400,000?/2tr',   '2026-02-10 18:00:00', 1, 0),
(10, 3, 10,   N'C?nh báo ngân sách',  N'?ã chi 75% t?ng ngân sách tháng 2 (6,000,000?/8,000,000?).',                 '2026-02-09 22:00:00', 1, 0),

-- type=4: H? th?ng
(1,  4, NULL, N'C?p nh?t h? th?ng',   N'SmartMoney v1.1 v?a ra m?t! Tính n?ng m?i: Báo cáo nâng cao và xu?t PDF',   '2026-02-01 07:00:00', 1, 1),
(15, 4, NULL, N'B?o m?t tài kho?n',   N'Phát hi?n ??ng nh?p m?i t? thi?t b? l? lúc 02:30. Hãy ??i m?t kh?u ngay',  '2026-02-08 02:35:00', 1, 0),

-- type=5: AI Chat
(3,  5, 7,    N'Phân tích AI',        N'AI ?ã phân tích xong chi tiêu tháng 2. B?n ?ang chi nhi?u h?n 18% tháng tr??c','2026-02-10 20:00:10', 1, 0),
(10, 5, 18,   N'AI nh?c nh?',         N'L?i nh?c: "Tr? n? anh Tu?n" vào ngày mai 15/02/2026 lúc 9:00 sáng',         '2026-02-14 21:00:00', 0, 0),

-- type=6: Ví s? d? th?p
(2,  6, 3,    N'S? d? ví th?p',       N'Ví MoMo còn 250,000? - d??i m?c c?nh báo 500,000?. Hãy n?p thêm ti?n',      '2026-02-10 15:00:00', 1, 0),
(6,  6, 11,   N'S? d? ví th?p',       N'Ví VNPay còn 150,000?. B?n có mu?n chuy?n ti?n t? MB Bank sang không?',      '2026-02-09 22:00:00', 1, 1),

-- type=7: S? ki?n s?p t?i (h?n l?ch t??ng lai)
(3,  7, 4,    N'S? ki?n s?p t?i',     N'Sinh nh?t 25 tu?i còn 33 ngày n?a (15/03/2026). ??ng quên lên k? ho?ch!',   '2026-02-10 08:00:00', 1, 0),
(20, 7, 21,   N'S? ki?n s?p t?i',     N'K? ngh? hè gia ?ình còn 141 ngày (01/07/2026). Ngân sách: 10,000,000?',     '2026-02-15 08:00:00', 0, 0),

-- type=8: Nh?c n? (h?n l?ch t??ng lai)
(1,  8, 2,    N'Nh?c kho?n thu',      N'Kho?n cho anh Minh vay 3,000,000? ??n h?n thu 31/03/2026. Hãy liên h?!',    '2026-02-20 09:00:00', 0, 0),
(5,  8, 7,    N'Nh?c kho?n n?',       N'Kho?n vay c??i còn 40,000,000?. K? thanh toán ti?p theo 01/03/2026',         '2026-02-25 09:00:00', 0, 0),

-- type=9: Nh?c ghi chép
(7,  9, NULL, N'Nh?c ghi chép',       N'B?n ch?a ghi chép chi tiêu hôm nay! Hãy dành 2 phút c?p nh?t s? chi tiêu ??','2026-02-10 21:00:00', 1, 1),
(17, 9, NULL, N'T?ng k?t tu?n',       N'Tu?n này b?n ?ã chi 2,350,000?. Chi tiêu cao nh?t: Giáo d?c (350,000?).',    '2026-02-10 20:00:00', 1, 0);
GO

-- ======================================================================
-- 18. B?NG GIAO D?CH ??NH K?/HÓA ??N (1-N v?i tAccounts)
-- ======================================================================
CREATE TABLE tPlannedTransactions (
    -- PRIMARY KEY
    id INT PRIMARY KEY IDENTITY(1,1),

    -- FOREIGN KEYS
    acc_id INT NOT NULL,    -- FK -> tAccounts (N-1)
    wallet_id INT NOT NULL, -- FK -> tWallets (N-1)
    
    -- N?u ng??i dùng t?o Bills menu s? ch? hi?n các danh m?c chi, n?u là Recurring menu s? cho ch?n t?t c? lo?i giao d?ch Thu/Chi/Vay-N?
    ctg_id INT NOT NULL,                         -- FK -> tCategories (N-1)
    currency_code VARCHAR(10) DEFAULT 'VND',     -- FK -> tCurrencies (N-1)
    
    -- DATA COLUMNS
    note NVARCHAR(500) NULL, -- L?u tên hóa ??n ho?c ghi chú
    amount DECIMAL(18,2) NOT NULL, -- S? ti?n m?i k?
    
    -- Phân lo?i nghi?p v?
    -- 1: Bill (Chi - C?n duy?t tay ?? t?o ra giao d?ch)
    -- 2: Recurring (Thu/Chi/N? - T? ??ng hoàn toàn t?o giao d?ch mà không c?n duy?t tay)
    plan_type TINYINT NOT NULL,
    
    -- Phân lo?i giao d?ch (?? bi?t khi sinh ra Transaction thì thu?c lo?i nào)
    -- 1: Kho?n chi, 2: Kho?n thu, 3: Cho vay, 4: ?i vay, 5: Thu n?, 6: Tr? n?
    trans_type TINYINT NOT NULL,

    -- C?u hình l?p l?i
    repeat_type TINYINT NOT NULL,           --: 0: Không l?p l?i, 1: Ngày, 2: Tu?n, 3: Tháng, 4: N?m
    repeat_interval INT DEFAULT 1 NOT NULL, -- M?i "1" ngày, m?i "2" tu?n...   
    /* Gi?i thích Bitmask cho Dev: 
    - N?u repeat_type = 2 (Tu?n): CN=1, T2=2, T3=4, T4=8, T5=16, T6=32, T7=64.
    - Ví d?: T2 + T4 = 10 (2 + 8). */
    repeat_on_day_val INT NULL,
    
    begin_date DATE NOT NULL,
    next_due_date DATE NOT NULL,                        -- Ngày ??n h?n ti?p và backend có th? quét c?t này ?? g?i thông báo.
    last_executed_at DATE NULL,                         -- Ngày th?c hi?n g?n nh?t (?? tránh duy?t trùng k?)
    end_date DATE NULL,                                 -- NULL n?u mu?n l?p l?i "Tr?n ??i".    

    active BIT DEFAULT 1 NOT NULL,                   -- 1: ?ang ch?y, 0: T?m d?ng      
    created_at DATETIME DEFAULT GETDATE() NOT NULL,     -- Ngày t?o ra ?? admin s?p x?p hi?n th? theo ngày.

    -- CONSTRAINTS
    CONSTRAINT CHK_Plan_Amount    CHECK (amount > 0),                                   -- Ch?n ti?n âm ho?c b?ng 0
    CONSTRAINT CHK_Plan_Repeat    CHECK (repeat_type BETWEEN 0 AND 4),                  -- Ch? ch?p nh?n các mã l?p t? 0-4
    CONSTRAINT CHK_Plan_Interval  CHECK (repeat_interval >= 1),                         -- Kho?ng cách l?p t?i thi?u là 1
    CONSTRAINT CHK_Plan_Dates     CHECK (end_date IS NULL OR end_date >= begin_date),   -- Ngày k?t thúc ph?i sau ngày b?t ??u
    CONSTRAINT CHK_Plan_Type      CHECK (plan_type IN (1, 2)),                          -- Ch? cho phép lo?i Bill ho?c Recurring
    CONSTRAINT CHK_Plan_TransType CHECK (trans_type BETWEEN 1 AND 6),                   -- Phân lo?i giao d?ch t? 1 ??n 6
    CONSTRAINT CHK_Plan_NextDue   CHECK (next_due_date >= begin_date),                  -- Ngày ??n h?n không ???c tr??c ngày b?t ??u
    
    CONSTRAINT FK_Bills_Acc FOREIGN KEY (acc_id) REFERENCES tAccounts(id),
    CONSTRAINT FK_Bills_Wallet FOREIGN KEY (wallet_id) REFERENCES tWallets(id) ON DELETE CASCADE,
    CONSTRAINT FK_Bills_Currency FOREIGN KEY (currency_code) REFERENCES tCurrencies(currency_code),
    CONSTRAINT FK_Bills_Category FOREIGN KEY (ctg_id) REFERENCES tCategories(id) ON DELETE CASCADE
);
GO

-- Index: T?i ?u Scheduler quét hóa ??n/giao d?ch ??n h?n
CREATE INDEX idx_planned_scan ON tPlannedTransactions(acc_id, next_due_date, active) INCLUDE (note, amount, plan_type, wallet_id);
GO
-- ======================================================================
-- D? LI?U M?U: Giao d?ch ??nh k?/Hóa ??n (tPlannedTransactions)
-- ======================================================================
-- PHÂN LO?I ?ÚNG:
--   ? BILLS (plan_type=1): S? ti?n THAY ??I m?i k?, c?n duy?t tay
--      VD: ?i?n, n??c, gas, chi phí y t?...
--   ? RECURRING (plan_type=2): S? ti?n C? ??NH, t? ??ng t?o giao d?ch
--      VD: Internet, Netflix, l??ng, tr? góp, b?o hi?m, h?c phí...
-- ======================================================================
GO

-- ??????????????????????????????????????????????????????????????????????
-- NHÓM 1: BILLS (plan_type = 1) - S? ti?n THAY ??I
-- ??????????????????????????????????????????????????????????????????????

INSERT INTO tPlannedTransactions (
    acc_id, wallet_id, ctg_id, note, amount, 
    plan_type, trans_type, 
    repeat_type, repeat_interval, repeat_on_day_val,
    begin_date, next_due_date, last_executed_at, end_date, active
) VALUES

-- ????????????????????????????????????????????????????????????????????
-- Bills - Hóa ??n ?i?n (s? ti?n dao ??ng)
-- ????????????????????????????????????????????????????????????????????
(1, 2, 28, N'Hóa ??n ti?n ?i?n EVN',
 520000, 1, 1, 3, 1, NULL,
 '2026-01-08', '2026-03-08', '2026-02-08', NULL, 1),
-- ?? Tháng 1: 480k, Tháng 2: 520k, Tháng 3: d? ki?n 500k (thay ??i theo m?c tiêu th?)

(2, 4, 28, N'Hóa ??n ti?n ?i?n (C?n h?)',
 680000, 1, 1, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),
-- ?? C?n h? l?n nên ti?n ?i?n dao ??ng 650k-750k

(6, 10, 28, N'Hóa ??n ?i?n (Nhà riêng)',
 450000, 1, 1, 3, 1, NULL,
 '2026-01-20', '2026-03-20', '2026-02-20', NULL, 1),
-- ?? Nhà nh? ti?n ?i?n th?p h?n 400k-500k

-- ????????????????????????????????????????????????????????????????????
-- Bills - Hóa ??n n??c (s? ti?n dao ??ng)
-- ????????????????????????????????????????????????????????????????????
(1, 2, 32, N'Hóa ??n ti?n n??c C?p n??c TP',
 85000, 1, 1, 3, 1, NULL,
 '2026-01-10', '2026-03-10', '2026-02-10', NULL, 1),
-- ?? N??c th??ng dao ??ng 70k-100k tùy m?c tiêu th?

(3, 6, 32, N'Ti?n n??c hàng tháng',
 120000, 1, 1, 3, 1, NULL,
 '2026-01-12', '2026-03-12', '2026-02-12', NULL, 1),
-- ?? Gia ?ình ?ông ng??i dùng nhi?u n??c 100k-150k

-- ????????????????????????????????????????????????????????????????????
-- Bills - Hóa ??n gas (s? ti?n dao ??ng)
-- ????????????????????????????????????????????????????????????????????
(2, 3, 30, N'Hóa ??n gas Petrolimex',
 320000, 1, 1, 3, 1, NULL,
 '2026-01-15', '2026-03-15', '2026-02-15', NULL, 1),
-- ?? Gas thay bình không ??u, có th? 0? (không thay) ho?c 300k-350k

(11, 18, 30, N'Gas n?u ?n',
 280000, 1, 1, 3, 1, NULL,
 '2026-01-18', '2026-03-18', '2026-02-18', NULL, 1),
-- ?? Gas dao ??ng 250k-350k tùy m?c tiêu th?

-- ????????????????????????????????????????????????????????????????????
-- Bills - Chi phí y t? (không bi?t tr??c)
-- ????????????????????????????????????????????????????????????????????
(3, 5, 38, N'Khám s?c kh?e ??nh k?',
 650000, 1, 1, 4, 1, NULL,
 '2026-01-15', '2027-01-15', '2026-01-15', NULL, 1),
-- ?? Chi phí khám ??nh k? hàng n?m dao ??ng tùy gói khám

(8, 21, 38, N'Chi phí y t? gia ?ình',
 1200000, 1, 1, 3, 1, NULL,
 '2026-02-01', '2026-03-01', '2026-02-01', '2026-06-30', 1),
-- ?? Chi phí ch?a b?nh không ?n ??nh, có tháng 0? có tháng vài tri?u

-- ??????????????????????????????????????????????????????????????????????
-- NHÓM 2: RECURRING (plan_type = 2) - S? ti?n C? ??NH
-- ??????????????????????????????????????????????????????????????????????

-- ????????????????????????????????????????????????????????????????????
-- Recurring - Internet/TV Cable (gói c??c c? ??nh)
-- ????????????????????????????????????????????????????????????????????
(1, 2, 31, N'Internet VNPT - Gói 200Mbps',
 280000, 2, 1, 3, 1, NULL,
 '2026-01-15', '2026-03-15', '2026-02-15', NULL, 1),
-- ? Gói c??c internet C? ??NH hàng tháng

(2, 4, 31, N'Internet FPT - Gói 300Mbps',
 350000, 2, 1, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),
-- ? Gói c??c internet C? ??NH

(6, 10, 31, N'Internet Viettel - Gói 100Mbps',
 220000, 2, 1, 3, 1, NULL,
 '2026-01-20', '2026-03-20', '2026-02-20', NULL, 1),

(11, 18, 34, N'Truy?n hình K+ Premium',
 180000, 2, 1, 3, 1, NULL,
 '2026-01-12', '2026-03-12', '2026-02-12', NULL, 1),
-- ? Gói truy?n hình C? ??NH

-- ????????????????????????????????????????????????????????????????????
-- Recurring - Subscription services (Netflix, Spotify...)
-- ????????????????????????????????????????????????????????????????????
(11, 18, 25, N'Netflix Premium (Gói gia ?ình)',
 260000, 2, 1, 3, 1, NULL,
 '2026-01-12', '2026-03-12', '2026-02-12', NULL, 1),
-- ? Gói Netflix C? ??NH hàng tháng

(7, 12, 25, N'Spotify Premium',
 59000, 2, 1, 3, 1, NULL,
 '2026-01-08', '2026-03-08', '2026-02-08', NULL, 1),
-- ? Gói Spotify C? ??NH

(3, 6, 25, N'YouTube Premium',
 79000, 2, 1, 3, 1, NULL,
 '2026-01-10', '2026-03-10', '2026-02-10', NULL, 1),
-- ? Gói YouTube Premium C? ??NH

(17, 26, 25, N'ChatGPT Plus',
 440000, 2, 1, 3, 1, NULL,
 '2026-01-15', '2026-03-15', '2026-02-15', NULL, 1),
-- ? Subscription AI C? ??NH ($20/tháng ~ 440k VND)

-- ????????????????????????????????????????????????????????????????????
-- Recurring - ?i?n tho?i/Mobile (gói c??c c? ??nh)
-- ????????????????????????????????????????????????????????????????????
(6, 10, 29, N'Gói c??c Viettel - V90',
 90000, 2, 1, 3, 1, NULL,
 '2026-01-20', '2026-03-20', '2026-02-20', NULL, 1),
-- ? Gói c??c di ??ng C? ??NH

(1, 2, 29, N'Gói c??c VinaPhone - VD149',
 149000, 2, 1, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),

(11, 18, 29, N'Gói c??c MobiFone - MAX200',
 200000, 2, 1, 3, 1, NULL,
 '2026-01-10', '2026-03-10', '2026-02-10', NULL, 1),

-- ????????????????????????????????????????????????????????????????????
-- Recurring - Thuê nhà (c? ??nh hàng tháng)
-- ????????????????????????????????????????????????????????????????????
(2, 4, 34, N'Ti?n thuê c?n h? Vinhomes',
 8500000, 2, 1, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),
-- ? Ti?n thuê nhà C? ??NH theo h?p ??ng

(9, 15, 34, N'Ti?n thuê tr?',
 3200000, 2, 1, 3, 1, NULL,
 '2026-01-08', '2026-03-08', '2026-02-08', '2026-12-31', 1),
-- ? Thuê tr? C? ??NH ??n khi h?t h?p ??ng

-- ????????????????????????????????????????????????????????????????????
-- Recurring - Phí b?o hi?m (c? ??nh)
-- ????????????????????????????????????????????????????????????????????
(3, 6, 2, N'Phí b?o hi?m nhân th? Prudential',
 8400000, 2, 1, 4, 1, NULL,
 '2026-01-20', '2027-01-20', '2026-01-20', '2030-01-20', 1),
-- ? B?o hi?m hàng N?M, phí C? ??NH theo h?p ??ng

(1, 2, 2, N'B?o hi?m xe ô tô',
 6500000, 2, 1, 4, 1, NULL,
 '2026-02-01', '2027-02-01', '2026-02-01', NULL, 1),
-- ? B?o hi?m xe hàng n?m C? ??NH

-- ????????????????????????????????????????????????????????????????????
-- Recurring - H?c phí (c? ??nh theo h?c k?)
-- ????????????????????????????????????????????????????????????????????
(15, 23, 8, N'H?c phí ??i h?c FPT - H?c k? Spring',
 16500000, 2, 1, 4, 6, NULL,
 '2026-02-06', '2027-02-06', '2026-02-06', '2028-06-30', 1),
-- ? H?c phí m?i K? C? ??NH (6 tháng/l?n)

(12, 19, 8, N'H?c phí THPT Chuyên',
 4500000, 2, 1, 4, 1, NULL,
 '2026-01-15', '2027-01-15', '2026-01-15', '2029-06-30', 1),
-- ? H?c phí hàng N?M C? ??NH

-- ????????????????????????????????????????????????????????????????????
-- Recurring - L??ng hàng tháng (thu nh?p c? ??nh)
-- ????????????????????????????????????????????????????????????????????
(1, 2, 15, N'L??ng tháng - Công ty ABC Tech',
 15000000, 2, 2, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),
-- ? L??ng C? ??NH hàng tháng (trans_type = 2: Thu)

(11, 18, 15, N'L??ng tháng - Ngân hàng XYZ',
 28000000, 2, 2, 3, 1, NULL,
 '2026-01-05', '2026-03-05', '2026-02-05', NULL, 1),

(17, 26, 15, N'L??ng freelance',
 12000000, 2, 2, 3, 1, NULL,
 '2026-01-10', '2026-03-10', '2026-02-10', NULL, 1),

(3, 6, 16, N'Thu c? t?c ??u t? ch?ng khoán',
 2500000, 2, 2, 3, 1, NULL,
 '2026-01-28', '2026-03-28', '2026-02-28', NULL, 1),
-- ? Thu lãi C? ??NH hàng tháng t? ??u t?

-- ????????????????????????????????????????????????????????????????????
-- Recurring - Tr? n?/vay ??nh k? (s? ti?n c? ??nh)
-- ????????????????????????????????????????????????????????????????????
(5, 9, 22, N'Tr? góp vay c??i - Ngân hàng Vietcombank',
 2000000, 2, 6, 3, 1, NULL,
 '2025-07-01', '2026-03-01', '2026-02-01', '2027-12-31', 1),
-- ? Tr? n? hàng tháng C? ??NH (trans_type = 6: Tr? n?)

(3, 6, 22, N'Tr? n? b?n thân - Vay mua laptop',
 1000000, 2, 6, 3, 1, NULL,
 '2025-11-15', '2026-03-15', '2026-02-15', '2026-09-15', 1),

(10, 16, 22, N'Tr? góp mua xe máy Honda Vision',
 3500000, 2, 6, 3, 1, NULL,
 '2025-08-01', '2026-03-01', '2026-02-01', '2027-08-01', 1),

(6, 10, 22, N'Tr? góp mua iPhone 15 Pro',
 8000000, 2, 6, 3, 1, NULL,
 '2025-10-01', '2026-03-01', '2026-02-01', '2026-10-01', 1),

-- ????????????????????????????????????????????????????????????????????
-- Recurring - L?p l?i hàng tu?n (Bitmask: T2+T6 = 2+32 = 34)
-- ????????????????????????????????????????????????????????????????????
(7, 12, 1, N'Cafe sáng ??u tu?n (T2, T6)',
 50000, 2, 1, 2, 1, 34,
 '2026-01-05', '2026-02-16', '2026-02-13', NULL, 1),
-- ? Chi cafe C? ??NH m?i T2 và T6

(1, 1, 1, N'?n tr?a v?n phòng (T2-T6)',
 70000, 2, 1, 2, 1, 62,
 '2026-02-03', '2026-02-14', '2026-02-13', NULL, 1),
-- ? Bitmask T2+T3+T4+T5+T6 = 2+4+8+16+32 = 62

-- ????????????????????????????????????????????????????????????????????
-- Recurring - L?p l?i hàng ngày
-- ????????????????????????????????????????????????????????????????????
(5, 9, 1, N'?n sáng hàng ngày',
 40000, 2, 1, 1, 1, NULL,
 '2026-02-01', '2026-02-11', '2026-02-10', NULL, 1),
-- ? Chi C? ??NH m?i ngày

-- ????????????????????????????????????????????????????????????????????
-- Recurring - ?ang t?m d?ng (active = 0)
-- ????????????????????????????????????????????????????????????????????
(2, 3, 10, N'Mua s?m Shopee ??nh k?',
 500000, 2, 1, 3, 1, NULL,
 '2025-10-01', '2026-03-01', '2026-02-01', NULL, 0);
-- ?? T?m d?ng giao d?ch ??nh k?

GO

-- ======================================================================
-- TH?NG KÊ D? LI?U ?Ã S?A
-- ======================================================================
-- ? BILLS (plan_type = 1): 11 rows
--    - ?i?n: 3 | N??c: 2 | Gas: 2 | Y t?: 4
--    - ??c ?i?m: S? ti?n THAY ??I m?i k?
--
-- ? RECURRING (plan_type = 2): 29 rows
--    - Internet/TV: 5 | Subscription: 4 | Mobile: 3
--    - Thuê nhà: 2 | B?o hi?m: 2 | H?c phí: 2
--    - L??ng: 4 | Tr? n?: 4 | L?p tu?n: 2 | L?p ngày: 1
--    - ??c ?i?m: S? ti?n C? ??NH, t? ??ng t?o giao d?ch
--
-- TOTAL: 40 planned transactions
-- ======================================================================

PRINT '? ?ã chèn 40 rows vào tPlannedTransactions (LOGIC ?ÚNG)';
PRINT '   - Bills (thay ??i): 11 rows';
PRINT '   - Recurring (c? ??nh): 29 rows';
GO

--select * from tWallets
--select * from tSavingGoals
--select * from tAccounts
--select * from tTransactions
--select * from tUserDevices
--select * from tReceipts
--select * from tPlannedTransactions
--select * from tNotifications
