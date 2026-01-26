package fpt.aptech.server.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Entity
@Table(name = "tEvents")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Event {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "acc_id", nullable = false)
    private Account account;

    @ManyToOne
    @JoinColumn(name = "currency", nullable = false)
    private Currency currency;

    @Column(name = "event_name", nullable = false, length = 200)
    private String eventName;

    @Column(name = "event_icon_url", length = 2048)
    private String eventIconUrl = "icon_event_default.svg";

    @Column(name = "begin_date")
    private LocalDate beginDate = LocalDate.now();

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    @Column(name = "finished")
    private Boolean finished = false;
}