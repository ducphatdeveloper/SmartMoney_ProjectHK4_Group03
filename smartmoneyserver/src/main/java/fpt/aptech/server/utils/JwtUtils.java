package fpt.aptech.server.utils;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Function;

@Service
public class JwtUtils {

    // Lấy secret key từ cấu hình để bảo mật hơn
    @Value("${jwt.secret:AIeyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9YmFzZTY0ZW5jb2RlZA==}")
    private String SECRET_KEY;

    private static final long ACCESS_TOKEN_EXP = 1000 * 60 * 60; // 1 giờ
    private static final long REFRESH_TOKEN_EXP = 1000 * 60 * 60 * 24; // 24 giờ

    // 1. Tạo Access Token kèm theo Roles và UserId
    public String generateAccessToken(UserDetails userDetails, Integer userId) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("tokenType", "ACCESS");

        // Lưu danh sách quyền (Roles) vào token
        var authorities = userDetails.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .toList();
        claims.put("authorities", authorities);

        return buildToken(claims, userDetails.getUsername(), ACCESS_TOKEN_EXP);
    }

    // 2. Tạo Refresh Token để gia hạn phiên đăng nhập
    public String generateRefreshToken(UserDetails userDetails, Integer userId) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("tokenType", "REFRESH");
        return buildToken(claims, userDetails.getUsername(), REFRESH_TOKEN_EXP);
    }

    private String buildToken(Map<String, Object> extraClaims, String subject, long expiration) {
        return Jwts.builder()
                .setClaims(extraClaims)
                .setSubject(subject)
                .setIssuedAt(new Date(System.currentTimeMillis()))
                .setExpiration(new Date(System.currentTimeMillis() + expiration))
                .signWith(getSigningKey(), io.jsonwebtoken.SignatureAlgorithm.HS256) // Đổi SIG thành SignatureAlgorithm
                .compact();
    }

    // 3. Các hàm giải mã (Extraction)
    public String extractUsername(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    public Integer extractUserId(String token) {
        return extractClaim(token, claims -> claims.get("userId", Integer.class));
    }

    public <T> T extractClaim(String token, Function<Claims, T> claimsResolver) {
        final Claims claims = extractAllClaims(token);
        return claimsResolver.apply(claims);
    }

    private Claims extractAllClaims(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody();
    }

    // 4. Kiểm tra tính hợp lệ
    public boolean isTokenValid(String token, UserDetails userDetails) {
        final String username = extractUsername(token);
        return (username.equals(userDetails.getUsername())) && !isTokenExpired(token);
    }

    private boolean isTokenExpired(String token) {
        return extractClaim(token, Claims::getExpiration).before(new Date());
    }

    private SecretKey getSigningKey() {
        byte[] keyBytes = Decoders.BASE64.decode(SECRET_KEY);
        return Keys.hmacShaKeyFor(keyBytes);
    }
}