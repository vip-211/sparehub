package com.spareparts.inventory.controller;

import com.spareparts.inventory.service.AIService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;

@RestController
@RequestMapping("/api/ai")
public class AIController {

    @Autowired
    private AIService aiService;

    @PostMapping("/chat")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Map<String, String>> chat(@RequestBody Map<String, String> request,
                                                    @RequestHeader(value = "X-AI-Provider", required = false) String provider) {
        String prompt = request.get("prompt");
        String response = aiService.askAI(prompt, provider);
        return ResponseEntity.ok(Map.of("response", response));
    }

    @PostMapping("/search/photo")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Map<String, String>> searchByPhoto(@RequestParam("image") MultipartFile image,
                                                             @RequestHeader(value = "X-AI-Provider", required = false) String provider) {
        String response = aiService.searchByPhoto(image, provider);
        return ResponseEntity.ok(Map.of("response", response));
    }

    @PostMapping("/search/voice")
    @PreAuthorize("isAuthenticated()")
    public ResponseEntity<Map<String, String>> searchByVoice(@RequestParam("audio") MultipartFile audio,
                                                             @RequestHeader(value = "X-AI-Provider", required = false) String provider) {
        String response = aiService.searchByVoice(audio, provider);
        return ResponseEntity.ok(Map.of("response", response));
    }
}
