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

    @PostConstruct
    public void initialize() {
        InputStream serviceAccount = null;
        try {
            if (serviceAccountJson != null && !serviceAccountJson.isEmpty()) {
                log.info("FirebaseConfig: Initializing with service account JSON from environment.");
                serviceAccount = new ByteArrayInputStream(serviceAccountJson.getBytes(StandardCharsets.UTF_8));
            } else if (serviceAccountPath != null && !serviceAccountPath.isEmpty()) {
                log.info("FirebaseConfig: Initializing with service account file: {}", serviceAccountPath);
                serviceAccount = new FileInputStream(serviceAccountPath);
            }

            if (serviceAccount == null) {
                log.info("FirebaseConfig: No service account provided, skipping initialization.");
                return;
            }

            // Read the content once to check for common mistakes (like using google-services.json instead of service account key)
            byte[] content = serviceAccount.readAllBytes();
            String jsonContent = new String(content, StandardCharsets.UTF_8);
            if (jsonContent.contains("\"project_info\"") || jsonContent.contains("\"client\"")) {
                log.error("FirebaseConfig: ERROR! It looks like you're using 'google-services.json' (the mobile client config) " +
                        "instead of a 'Firebase Service Account Key' (the server/admin config).");
                log.error("FirebaseConfig: Please download the correct JSON from: Firebase Console -> Project Settings -> Service Accounts -> Generate New Private Key.");
                return;
            }

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(new ByteArrayInputStream(content)))
                    .build();

            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp app = FirebaseApp.initializeApp(options);
                log.info("FirebaseConfig: Firebase has been initialized for project: {}", app.getOptions().getProjectId());
            } else {
                log.info("FirebaseConfig: Firebase already initialized for project: {}", FirebaseApp.getInstance().getOptions().getProjectId());
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
