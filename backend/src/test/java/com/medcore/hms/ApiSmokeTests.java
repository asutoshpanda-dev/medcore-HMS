package com.medcore.hms;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// Starts the whole application on the test database (H2, see application-test.properties) and checks
// the main API rules: public docs, login, protected endpoints, and role checks.
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ApiSmokeTests {

    // Must match application-test.properties
    private static final String ADMIN_USER = "testadmin";
    private static final String ADMIN_PASSWORD = "test-admin-password";

    @Autowired
    private MockMvc mvc;

    @Test
    void apiDocumentationIsPublic() throws Exception {
        mvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk());
    }

    @Test
    void protectedEndpointRefusesARequestWithoutAToken() throws Exception {
        mvc.perform(get("/api/patients"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void wrongPasswordIsRefused() throws Exception {
        mvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody(ADMIN_USER, "wrong-password")))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void loginReturnsATokenAndTheRole() throws Exception {
        mvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody(ADMIN_USER, ADMIN_PASSWORD)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.token").isNotEmpty())
                .andExpect(jsonPath("$.data.role").value("SUPER_ADMIN"));
    }

    @Test
    void meReturnsTheLoggedInAccount() throws Exception {
        String token = login();

        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.username").value(ADMIN_USER))
                .andExpect(jsonPath("$.data.role").value("SUPER_ADMIN"));
    }

    @Test
    void superAdminGetsAPagedHospitalList() throws Exception {
        String token = login();

        mvc.perform(get("/api/hospitals").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data").isArray())
                .andExpect(jsonPath("$.page.number").value(0));
    }

    @Test
    void superAdminIsRefusedHospitalPatientData() throws Exception {
        // Patient lists belong to hospital staff. The platform super admin is not hospital staff.
        String token = login();

        mvc.perform(get("/api/patients").header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }

    // Logs in as the test super admin and returns the access token
    private String login() throws Exception {
        MvcResult result = mvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(loginBody(ADMIN_USER, ADMIN_PASSWORD)))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.data.token");
    }

    private static String loginBody(String username, String password) {
        return "{\"username\":\"" + username + "\",\"password\":\"" + password + "\"}";
    }
}
