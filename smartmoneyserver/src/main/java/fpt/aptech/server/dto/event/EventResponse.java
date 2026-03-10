package fpt.aptech.server.dto.event;

import lombok.Builder;
import lombok.Getter;

import java.time.LocalDate;

@Getter
@Builder
public class EventResponse {
    private Integer id;
    private String eventName;
    private String eventIconUrl;
    private LocalDate beginDate;
    private LocalDate endDate;
    private Boolean finished;
    private String currencyCode;
}