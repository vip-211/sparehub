package com.spareparts.inventory.controller;

import com.spareparts.inventory.entity.User;
import com.spareparts.inventory.entity.UserActivity;
import com.spareparts.inventory.repository.UserActivityRepository;
import com.spareparts.inventory.repository.UserRepository;
import com.spareparts.inventory.security.UserDetailsImpl;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping(value = "/api/user-activities", produces = "application/json")
public class UserActivityController {

    @Autowired
    private UserActivityRepository userActivityRepository;

    @Autowired
    private UserRepository userRepository;

    // Endpoint to start a new session (called when user opens app)
    @PostMapping("/start-session")
    public ResponseEntity<UserActivity> startSession(
            @AuthenticationPrincipal UserDetailsImpl userDetails,
            @RequestParam(required = false) String deviceInfo,
            @RequestParam(required = false) String ipAddress,
            @RequestParam(required = false) String appVersion) {
        
        User user = userRepository.findById(userDetails.getId())
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        UserActivity activity = new UserActivity();
        activity.setUser(user);
        activity.setSessionStart(LocalDateTime.now());
        activity.setDeviceInfo(deviceInfo);
        activity.setIpAddress(ipAddress);
        activity.setAppVersion(appVersion);
        
        return ResponseEntity.ok(userActivityRepository.save(activity));
    }

    // Endpoint to end an existing session (called when user closes app)
    @PutMapping("/end-session/{activityId}")
    public ResponseEntity<UserActivity> endSession(@PathVariable Long activityId) {
        UserActivity activity = userActivityRepository.findById(activityId)
                .orElseThrow(() -> new RuntimeException("Activity not found"));
        
        activity.setSessionEnd(LocalDateTime.now());
        Duration duration = Duration.between(activity.getSessionStart(), activity.getSessionEnd());
        activity.setDurationSeconds(duration.getSeconds());
        
        return ResponseEntity.ok(userActivityRepository.save(activity));
    }

    // Admin endpoint to get daily activity stats grouped by date and user
    @GetMapping("/daily-stats")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<List<Map<String, Object>>> getDailyActivityStats() {
        List<Object[]> results = userActivityRepository.findDailyActivityStatsGroupedByUser();
        List<Map<String, Object>> stats = new ArrayList<>();
        
        for (Object[] row : results) {
            Map<String, Object> stat = new HashMap<>();
            stat.put("date", row[0].toString());
            stat.put("sessionCount", ((Number) row[1]).longValue());
            stat.put("totalDurationSeconds", row[2] != null ? ((Number) row[2]).longValue() : 0L);
            stat.put("userId", ((Number) row[3]).longValue());
            stat.put("userName", row[4].toString());
            
            // Calculate total duration in minutes/hours for easier reading
            long totalSeconds = stat.get("totalDurationSeconds") != null ? (Long) stat.get("totalDurationSeconds") : 0L;
            long totalMinutes = totalSeconds / 60;
            long totalHours = totalMinutes / 60;
            stat.put("totalDurationMinutes", totalMinutes);
            stat.put("totalDurationHours", totalHours);
            
            stats.add(stat);
        }
        
        return ResponseEntity.ok(stats);
    }

    // Admin endpoint to get detailed activities for a specific date
    @GetMapping("/date/{date}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<List<UserActivity>> getActivitiesByDate(@PathVariable String date) {
        LocalDate localDate = LocalDate.parse(date);
        return ResponseEntity.ok(userActivityRepository.findByDate(localDate));
    }

    // Get activities for a specific user and date
    @GetMapping("/date/{date}/user/{userId}")
    @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_MANAGER') or hasRole('STAFF')")
    public ResponseEntity<List<UserActivity>> getActivitiesByDateAndUser(
            @PathVariable String date,
            @PathVariable Long userId) {
        LocalDate localDate = LocalDate.parse(date);
        return ResponseEntity.ok(userActivityRepository.findByDateAndUserId(localDate, userId));
    }
}
