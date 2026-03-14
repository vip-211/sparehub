package com.spareparts.inventory.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "order_requests")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CustomOrderRequest {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private User customer;

    @Column(columnDefinition = "TEXT")
    private String text;

    private String photoPath;

    @Enumerated(EnumType.STRING)
    private RequestStatus status = RequestStatus.NEW;

    private LocalDateTime createdAt = LocalDateTime.now();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_staff_id")
    private User assignedStaff;

    public enum RequestStatus {
        NEW, PROCESSING, COMPLETED, CANCELLED
    }
}
