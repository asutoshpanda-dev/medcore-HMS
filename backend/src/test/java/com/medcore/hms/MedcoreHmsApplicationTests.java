package com.medcore.hms;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

// Starts the whole application on the test database (H2, see src/test/resources/application-test.properties).
// No MySQL and no passwords from the environment are needed. If this fails, the application cannot start:
// read the first "Caused by" line in the log.
@SpringBootTest
@ActiveProfiles("test")
class MedcoreHmsApplicationTests {

    @Test
    void contextLoads() {
    }
}
