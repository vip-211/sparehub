package com.spareparts.inventory.repository;

import com.spareparts.inventory.entity.AITrainingCorrection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface AITrainingCorrectionRepository extends JpaRepository<AITrainingCorrection, Long> {
    Optional<AITrainingCorrection> findTopByPromptIgnoreCaseOrderByCreatedAtDesc(String prompt);
}
