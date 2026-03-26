package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.time.LocalDateTime;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {
    List<Notification> findByTargetRoleOrTargetRoleOrderByCreatedAtDesc(String targetRole, String allRole);
    List<Notification> findByUserIdOrTargetRoleOrTargetRoleOrderByCreatedAtDesc(Long userId, String targetRole, String allRole);
    
    @org.springframework.data.jpa.repository.Query("SELECT COUNT(n) FROM Notification n WHERE (n.userId = :userId OR n.targetRole = :role OR n.targetRole = 'ALL') AND n.createdAt > :date")
    long countUnread(@org.springframework.data.repository.query.Param("userId") Long userId, @org.springframework.data.repository.query.Param("role") String role, @org.springframework.data.repository.query.Param("date") LocalDateTime date);
    
    @org.springframework.data.jpa.repository.Query("SELECT COUNT(n) FROM Notification n WHERE n.userId = :userId OR n.targetRole = :role OR n.targetRole = 'ALL'")
    long countAll(@org.springframework.data.repository.query.Param("userId") Long userId, @org.springframework.data.repository.query.Param("role") String role);
}
