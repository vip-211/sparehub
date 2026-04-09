package com.spareparts.inventory.config;

import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.Statement;

@Component
public class DatabaseMigrationRunner implements CommandLineRunner {
    private final DataSource dataSource;

    public DatabaseMigrationRunner(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public void run(String... args) {
        try (Connection conn = dataSource.getConnection();
             Statement stmt = conn.createStatement()) {
            stmt.executeUpdate("UPDATE notifications SET is_broadcast = 0 WHERE is_broadcast IS NULL");

            try {
                stmt.execute("ALTER TABLE categories ADD COLUMN showOnHome INTEGER DEFAULT 1");
            } catch (Exception ignored) {
            }
            
            // Seed CMS settings if they don't exist
            stmt.execute("CREATE TABLE IF NOT EXISTS system_settings (setting_key VARCHAR(255) PRIMARY KEY, setting_value TEXT NOT NULL)");
            
            String[] keys = {"mechanic_home_title", "mechanic_banner_text", "mechanic_banner_btn", "mechanic_home_layout", "hide_chat_support"};
            String[] values = {"Parts Mitra", "मार्केटमध्ये दर वाढले,\nparts mitra ॲप वर नाही.", "आता खरेदी करा", "header,search_bar,categories,banner,hot_deals", "false"};
            
            for (int i = 0; i < keys.length; i++) {
                String sql = String.format("INSERT INTO system_settings (setting_key, setting_value) SELECT '%s', '%s' WHERE NOT EXISTS (SELECT 1 FROM system_settings WHERE setting_key = '%s')", 
                    keys[i], values[i], keys[i]);
                stmt.execute(sql);
            }
        } catch (Exception ignored) {
        }
    }
}
