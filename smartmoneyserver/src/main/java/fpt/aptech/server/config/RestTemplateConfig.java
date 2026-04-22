package fpt.aptech.server.config;

import org.springframework.ai.ollama.api.OllamaApi;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;

import java.time.Duration;

@Configuration
public class RestTemplateConfig {

    @Bean
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder
                .connectTimeout(Duration.ofMinutes(10))
                .readTimeout(Duration.ofMinutes(10))
                .build();
    }

    @Bean
    @Primary
    public OllamaApi ollamaApi(@Value("${spring.ai.ollama.base-url}") String baseUrl) {
        // 1. Tạo HttpClient của Netty với Timeout 10 phút
        HttpClient httpClient = HttpClient.create()
                .responseTimeout(Duration.ofMinutes(10))
                .option(io.netty.channel.ChannelOption.CONNECT_TIMEOUT_MILLIS, 600000);

        // 2. Tạo WebClient Builder
        WebClient.Builder webClientBuilder = WebClient.builder()
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(50 * 1024 * 1024));

        // 3. DÙNG BUILDER VỚI TÊN PHƯƠNG THỨC MỚI (Bản 1.1.4)
        return OllamaApi.builder()
                .baseUrl(baseUrl)            // Đã đổi từ withBaseUrl thành baseUrl
                .webClientBuilder(webClientBuilder) // Đã đổi từ withWebClientBuilder thành webClientBuilder
                .build();
    }
}