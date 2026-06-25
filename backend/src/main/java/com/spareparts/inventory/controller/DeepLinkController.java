package com.spareparts.inventory.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.servlet.view.RedirectView;

@Controller
public class DeepLinkController {
    
    // Play Store URL for Parts Mitra app
    private static final String PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.partsmitra.app";
    
    // App Store URL (replace with your actual app's App Store URL if iOS)
    private static final String APP_STORE_URL = "https://apps.apple.com/app/your-app-id";

    @GetMapping("/product/{id}")
    public RedirectView redirectToProduct(@PathVariable Long id) {
        // For Android App Links, if the app is installed, the system will open it
        // If not, it will load this page which will redirect to Play Store
        return new RedirectView(PLAY_STORE_URL);
    }
}
