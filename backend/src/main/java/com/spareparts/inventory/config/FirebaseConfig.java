package com.spareparts.inventory.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

import javax.annotation.PostConstruct;
import java.io.ByteArrayInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

@Configuration
public class FirebaseConfig {
    private static final Logger log = LoggerFactory.getLogger(FirebaseConfig.class);

    @Value("${firebase.service-account.path:}")
    private String serviceAccountPath;

    @Value("${firebase.service-account.json:}")
    private String serviceAccountJson;

    @Value("${firebase.project-id:}")
    private String firebaseProjectId;

    @PostConstruct
    public void initialize() {
        InputStream serviceAccount = null;
        try {
            if (serviceAccountJson != null && !serviceAccountJson.isEmpty()) {
                log.info("FirebaseConfig: Initializing with service account JSON from environment variable.");
                serviceAccount = new ByteArrayInputStream(serviceAccountJson.getBytes(StandardCharsets.UTF_8));
            } else if (serviceAccountPath != null && !serviceAccountPath.isEmpty()) {
                log.info("FirebaseConfig: Initializing with service account file: {}", serviceAccountPath);
                serviceAccount = new FileInputStream(serviceAccountPath);
            } else {
                // Try default Render secret path as a fallback
                java.io.File renderSecret = new java.io.File("/etc/secrets/serviceAccountKey.json");
                if (renderSecret.exists()) {
                    log.info("FirebaseConfig: Found service account at Render secret path: /etc/secrets/serviceAccountKey.json");
                    serviceAccount = new FileInputStream(renderSecret);
                }
            }

            if (serviceAccount == null) {
                log.warn("FirebaseConfig: No service account provided (Checked FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_SERVICE_ACCOUNT_PATH, and /etc/secrets/serviceAccountKey.json). Skipping initialization.");
                return;
            }

            // Read the content once to check for common mistakes (like using google-services.json instead of service account key)
            byte[] content = serviceAccount.readAllBytes();
            if (content.length == 0) {
                log.error("FirebaseConfig: The service account file is empty. Skipping Firebase initialization.");
                return;
            }

            String jsonContent = new String(content, StandardCharsets.UTF_8);
            if (jsonContent.contains("\"project_info\"") || jsonContent.contains("\"client\"")) {
                log.error("FirebaseConfig: It looks like you're using 'google-services.json' (the mobile client config) " +
                        "instead of a 'Firebase Service Account Key' (the server/admin config). " +
                        "Please download the correct JSON from: Firebase Console -> Project Settings -> Service Accounts -> Generate New Private Key.");
                return;
            }

            if (!jsonContent.contains("\"private_key\"") || !jsonContent.contains("\"client_email\"")) {
                log.error("FirebaseConfig: The provided JSON is NOT a valid Firebase Service Account Key. " +
                        "A valid key must contain 'private_key' and 'client_email' fields. " +
                        "Please download the correct JSON from: Firebase Console -> Project Settings -> Service Accounts -> Generate New Private Key.");
                return;
            }

            String projectId = null;
            try {
                com.fasterxml.jackson.databind.JsonNode root = new com.fasterxml.jackson.databind.ObjectMapper().readTree(content);
                if (root.hasNonNull("project_id")) {
                    projectId = root.get("project_id").asText();
                }
            } catch (Exception e) {
                log.error("FirebaseConfig: Failed to parse service account JSON. Ensure the file is a valid Firebase Service Account Key (not google-services.json). Error: {}", e.getMessage());
                return;
            }

            if ((projectId == null || projectId.isBlank()) && firebaseProjectId != null && !firebaseProjectId.isBlank()) {
                projectId = firebaseProjectId.trim();
            }

            if (projectId == null || projectId.isBlank()) {
                log.error("FirebaseConfig: Project ID is missing from service account key. Check if the JSON file contains the 'project_id' field or set FIREBASE_PROJECT_ID. Skipping Firebase initialization.");
                return;
            }

            FirebaseOptions options;
            try {
                options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(new ByteArrayInputStream(content)))
                        .setProjectId(projectId)
                        .build();
            } catch (Exception e) {
                log.error("FirebaseConfig: Failed to parse service account JSON. Ensure the file is a valid Firebase Service Account Key (not google-services.json). Error: {}", e.getMessage());
                return;
            }

            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp app = FirebaseApp.initializeApp(options);
                log.info("FirebaseConfig: Firebase has been initialized for project: {}", app.getOptions().getProjectId());
            } else {
                String existingProjectId = FirebaseApp.getInstance().getOptions().getProjectId();
                if (existingProjectId == null || existingProjectId.isEmpty()) {
                    log.warn("FirebaseConfig: Existing Firebase instance has no Project ID.");
                    return;
                }
                log.info("FirebaseConfig: Firebase already initialized for project: {}", existingProjectId);
            }
        } catch (IOException e) {
            log.error("FirebaseConfig: Error initializing Firebase: {}", e.getMessage());
        } finally {
            if (serviceAccount != null) {
                try {
                    serviceAccount.close();
                } catch (IOException e) {
                    // Ignore close error
                }
            }
        }
    }
}
