package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.VoiceTrainingSample;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;

public interface VoiceTrainingSampleRepository extends JpaRepository<VoiceTrainingSample, Long> {
    @Query("SELECT v FROM VoiceTrainingSample v " +
            "WHERE (?1 IS NULL OR v.role = ?1) " +
            "AND (CAST(?2 AS timestamp) IS NULL OR v.createdAt >= ?2) " +
            "AND (CAST(?3 AS timestamp) IS NULL OR v.createdAt <= ?3) " +
            "ORDER BY v.createdAt DESC")
    Page<VoiceTrainingSample> findFiltered(String role,
                                           LocalDateTime from,
                                           LocalDateTime to,
                                           Pageable pageable);
}
