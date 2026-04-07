package com.spareparts.inventory.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "ai_training_corrections")
public class AITrainingCorrection {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(columnDefinition = "TEXT")
    private String prompt;

    @Column(columnDefinition = "TEXT")
    private String originalResponse;

    @Column(columnDefinition = "TEXT")
    private String correctedResponse;

    private LocalDateTime createdAt = LocalDateTime.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getPrompt() { return prompt; }
    public void setPrompt(String prompt) { this.prompt = prompt; }
    public String getOriginalResponse() { return originalResponse; }
    public void setOriginalResponse(String originalResponse) { this.originalResponse = originalResponse; }
    public String getCorrectedResponse() { return correctedResponse; }
    public void setCorrectedResponse(String correctedResponse) { this.correctedResponse = correctedResponse; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
