package fpt.aptech.server.utils;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Date;

@Component
public class JwtUtils {
    private final String secret="AIeyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9";
    public String generateToken(String username) {
        return Jwts.builder().setSubject(username).setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis()+1000*60*60*10))
                .signWith(secretKey(secret)).compact();
    }
    private SecretKey secretKey(String secret) {
        var bytes=secret.getBytes(StandardCharsets.UTF_8);
        try {
            var key= Keys.hmacShaKeyFor(bytes);
            return  key;
        }catch (Exception e){
            return Keys.hmacShaKeyFor(Arrays.copyOf(bytes,64));
        }
    }

    public String extractUsername(String token) {
        return Jwts.parser().setSigningKey(secretKey(secret))
                .parseClaimsJws(token).getBody().getSubject();
    }
    public Date extractExpiration(String token) {
        return Jwts.parser().setSigningKey(secretKey(secret))
                .parseClaimsJws(token).getBody().getExpiration();
    }
    public boolean isTokenExpire(String token) {
        return extractExpiration(token).before(new Date());
    }
    public boolean validateToken(String token, String username) {
        return (username.equals(extractUsername(token)) && !isTokenExpire(token));
    }
}
