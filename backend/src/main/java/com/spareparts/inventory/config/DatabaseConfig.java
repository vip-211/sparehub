package com.spareparts.inventory.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;
import java.net.URI;

@Configuration
public class DatabaseConfig {
    private static final Logger log = LoggerFactory.getLogger(DatabaseConfig.class);

    @Bean
    @Primary
    public DataSource dataSource() {
        String springUrl = System.getenv("SPRING_DATASOURCE_URL");
        String databaseUrl = System.getenv("DATABASE_URL");
        
        String urlToParse = (springUrl != null && !springUrl.isEmpty()) ? springUrl : databaseUrl;

        if (urlToParse != null && !urlToParse.isEmpty()) {
            try {
                log.info("DatabaseConfig: Attempting to parse database URL");
                
                // Remove all possible prefixes to get a clean user:pass@host:port/db string
                String cleanUrl = urlToParse
                        .replace("jdbc:postgresql://", "")
                        .replace("jdbc:postgres://", "")
                        .replace("postgresql://", "")
                        .replace("postgres://", "");
                
                // Re-add a standard prefix for URI parsing
                cleanUrl = "postgresql://" + cleanUrl;
                URI uri = new URI(cleanUrl);
                
                if (uri.getUserInfo() == null) {
                    log.info("DatabaseConfig: No userInfo found, using as standard JDBC URL");
                    return DataSourceBuilder.create()
                            .url(urlToParse.startsWith("jdbc:") ? urlToParse : "jdbc:postgresql://" + cleanUrl.replace("postgresql://", ""))
                            .build();
                }

                // Extract components
                String jdbcUrl = "jdbc:postgresql://" + uri.getHost() + (uri.getPort() != -1 ? ":" + uri.getPort() : "") + uri.getPath();
                String[] userInfo = uri.getUserInfo().split(":");
                String username = userInfo[0];
                String password = userInfo.length > 1 ? userInfo[1] : "";

                log.info("DatabaseConfig: Successfully parsed components. Host: {}", uri.getHost());
                
                return DataSourceBuilder.create()
                        .url(jdbcUrl)
                        .username(username)
                        .password(password)
                        .driverClassName("org.postgresql.Driver")
                        .build();
            } catch (Exception e) {
                log.error("DatabaseConfig: Critical error parsing database URL: {}", e.getMessage());
            }
        }

        log.info("DatabaseConfig: Falling back to application.properties defaults");
        return DataSourceBuilder.create().build();
    }
}
