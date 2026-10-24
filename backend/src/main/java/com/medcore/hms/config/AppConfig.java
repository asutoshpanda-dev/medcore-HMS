package com.medcore.hms.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

// Turns on the checked application settings (see AppProperties) and the scheduled cleanup jobs
@Configuration
@EnableConfigurationProperties(AppProperties.class)
@EnableScheduling
public class AppConfig {
}
