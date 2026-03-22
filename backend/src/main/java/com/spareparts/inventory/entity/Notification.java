package com.spareparts.inventory.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Table(name = "notifications")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Notification {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false, length = 1000)
    private String message;

    @Column(name = "user_id")
    private Long userId;

    @Column(name = "target_role")
    private String targetRole;

    @Column(name = "is_broadcast")
    private Boolean isBroadcast = false;

    @PrePersist
    public void prePersist() {
        if (isBroadcast == null) {
            isBroadcast = false;
        }
    }

    @PostLoad
    public void postLoad() {
        if (isBroadcast == null) {
            isBroadcast = false;
        }
    }

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
