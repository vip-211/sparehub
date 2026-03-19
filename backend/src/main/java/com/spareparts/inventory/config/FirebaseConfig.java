package com.spareparts.inventory.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
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

    @Value("${firebase.service-account.path:}")
    private String serviceAccountPath;

    @Value("${firebase.service-account.json:}")
    private String serviceAccountJson;

    @PostConstruct
    public void initialize() {
        InputStream serviceAccount = null;
        try {
            if (serviceAccountJson != null && !serviceAccountJson.isEmpty()) {
                System.out.println("FirebaseConfig: Initializing with service account JSON from environment.");
                serviceAccount = new ByteArrayInputStream(serviceAccountJson.getBytes(StandardCharsets.UTF_8));
            } else if (serviceAccountPath != null && !serviceAccountPath.isEmpty()) {
                System.out.println("FirebaseConfig: Initializing with service account file: " + serviceAccountPath);
                serviceAccount = new FileInputStream(serviceAccountPath);
            }

            if (serviceAccount == null) {
                System.out.println("FirebaseConfig: No service account provided, skipping initialization.");
                return;
            }

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
                System.out.println("FirebaseConfig: Firebase has been initialized.");
            }
        } catch (IOException e) {
            System.err.println("FirebaseConfig: Error initializing Firebase: " + e.getMessage());
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
