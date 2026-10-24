package com.medcore.hms.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "app_user")
public class AppUser {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String username;

    @Column(nullable = false)
    private String password; // BCrypt hash

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.VARCHAR)   // plain VARCHAR column, so adding a role never needs a table change
    @Column(nullable = false)
    private Role role;

    // The hospital this account belongs to (empty only for SUPER_ADMIN)
    @Column(name = "hospital_id")
    private Long hospitalId;

    // Link to the patient record (PATIENT accounts only)
    @Column(name = "patient_id")
    private Long patientId;

    // Link to the doctor record (DOCTOR accounts only)
    @Column(name = "doctor_id")
    private Long doctorId;

    // Email for password reset codes (optional; without one the password cannot be reset)
    @Column(name = "email", length = 160)
    private String email;

    public AppUser() {
    }

    public AppUser(String username, String password, Role role) {
        this.username = username;
        this.password = password;
        this.role = role;
    }

    public Long getId() { return id; }
    public String getUsername() { return username; }
    public String getPassword() { return password; }
    public Role getRole() { return role; }
    public Long getHospitalId() { return hospitalId; }
    public Long getPatientId() { return patientId; }
    public Long getDoctorId() { return doctorId; }
    public String getEmail() { return email; }

    public void setUsername(String username) { this.username = username; }
    public void setPassword(String password) { this.password = password; }
    public void setRole(Role role) { this.role = role; }
    public void setHospitalId(Long hospitalId) { this.hospitalId = hospitalId; }
    public void setPatientId(Long patientId) { this.patientId = patientId; }
    public void setDoctorId(Long doctorId) { this.doctorId = doctorId; }
    public void setEmail(String email) { this.email = email; }

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hospital_id", insertable = false, updatable = false,
            foreignKey = @ForeignKey(name = "fk_app_user_hospital"))
    private Hospital hospital;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "patient_id", insertable = false, updatable = false,
            foreignKey = @ForeignKey(name = "fk_app_user_patient"))
    private Patient patient;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "doctor_id", insertable = false, updatable = false,
            foreignKey = @ForeignKey(name = "fk_app_user_doctor"))
    private Doctor doctor;
}
