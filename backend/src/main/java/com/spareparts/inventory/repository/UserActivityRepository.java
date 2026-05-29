package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.UserActivity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface UserActivityRepository extends JpaRepository<UserActivity, Long> {

    List<UserActivity> findByUserIdOrderBySessionStartDesc(Long userId);

    List<UserActivity> findBySessionStartBetweenOrderBySessionStartDesc(java.time.LocalDateTime start, java.time.LocalDateTime end);

    @Query("SELECT ua FROM UserActivity ua WHERE DATE(ua.sessionStart) = :date ORDER BY ua.sessionStart DESC")
    List<UserActivity> findByDate(@Param("date") LocalDate date);

    @Query("SELECT DATE(ua.sessionStart) as date, COUNT(ua) as sessionCount, SUM(ua.durationSeconds) as totalDurationSeconds, ua.user.id as userId, ua.user.name as userName " +
           "FROM UserActivity ua " +
           "GROUP BY DATE(ua.sessionStart), ua.user.id, ua.user.name " +
           "ORDER BY date DESC")
    List<Object[]> findDailyActivityStatsGroupedByUser();

    @Query("SELECT ua FROM UserActivity ua WHERE DATE(ua.sessionStart) = :date AND ua.user.id = :userId ORDER BY ua.sessionStart DESC")
    List<UserActivity> findByDateAndUserId(@Param("date") LocalDate date, @Param("userId") Long userId);
}
