package com.medcore.hms.controller;

import com.medcore.hms.api.ApiResponse;
import com.medcore.hms.api.PageResponse;
import com.medcore.hms.dto.AppointmentDtos.AppointmentResponse;
import com.medcore.hms.dto.AppointmentDtos.PatientBookingRequest;
import com.medcore.hms.dto.BillDtos.BillResponse;
import com.medcore.hms.dto.MedicalRecordDtos.MedicalRecordResponse;
import com.medcore.hms.dto.PatientDtos.PatientRequest;
import com.medcore.hms.dto.PatientDtos.PatientResponse;
import com.medcore.hms.dto.PrescriptionDtos.PrescriptionResponse;
import com.medcore.hms.repository.AppointmentRepository;
import com.medcore.hms.repository.BillRepository;
import com.medcore.hms.repository.PrescriptionRepository;
import com.medcore.hms.service.AppointmentService;
import com.medcore.hms.service.CurrentUserService;
import com.medcore.hms.service.MedicalRecordService;
import com.medcore.hms.service.PatientService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

// The logged-in patient's own data. The patient id always comes from the account, never from the request.
@RestController
@RequestMapping("/api/me")
public class MeController {

    private final CurrentUserService currentUserService;
    private final PatientService patientService;
    private final AppointmentService appointmentService;
    private final MedicalRecordService medicalRecordService;
    private final AppointmentRepository appointmentRepository;
    private final PrescriptionRepository prescriptionRepository;
    private final BillRepository billRepository;

    public MeController(CurrentUserService currentUserService,
                        PatientService patientService,
                        AppointmentService appointmentService,
                        MedicalRecordService medicalRecordService,
                        AppointmentRepository appointmentRepository,
                        PrescriptionRepository prescriptionRepository,
                        BillRepository billRepository) {
        this.currentUserService = currentUserService;
        this.patientService = patientService;
        this.appointmentService = appointmentService;
        this.medicalRecordService = medicalRecordService;
        this.appointmentRepository = appointmentRepository;
        this.prescriptionRepository = prescriptionRepository;
        this.billRepository = billRepository;
    }

    @GetMapping("/patient")
    public ApiResponse<PatientResponse> myDetails() {
        return ApiResponse.of(PatientResponse.from(patientService.getPatient(myPatientId())));
    }

    // Delete this method to make patients fully read-only
    @PutMapping("/patient")
    public ApiResponse<PatientResponse> updateMyDetails(@Valid @RequestBody PatientRequest request) {
        return ApiResponse.of(PatientResponse.from(
                patientService.updatePatient(myPatientId(), request.toEntity())));
    }

    @GetMapping("/appointments")
    public PageResponse<AppointmentResponse> myAppointments(
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.DESC) Pageable pageable) {
        return PageResponse.of(appointmentRepository.findByPatientId(myPatientId(), pageable),
                AppointmentResponse::from);
    }

    // The new appointment starts PENDING; reception confirms it
    @PostMapping("/appointments")
    public ApiResponse<AppointmentResponse> bookMyAppointment(@Valid @RequestBody PatientBookingRequest request) {
        return ApiResponse.of(AppointmentResponse.from(
                appointmentService.bookByPatient(myPatientId(), request)));
    }

    @PatchMapping("/appointments/{id}/cancel")
    public ApiResponse<AppointmentResponse> cancelMyAppointment(@PathVariable Long id) {
        return ApiResponse.of(AppointmentResponse.from(
                appointmentService.cancelByPatient(id, myPatientId())));
    }

    @GetMapping("/medical-records")
    public PageResponse<MedicalRecordResponse> myMedicalRecords(
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.DESC) Pageable pageable) {
        return PageResponse.of(medicalRecordService.myRecords(myPatientId(), pageable),
                MedicalRecordResponse::from);
    }

    @GetMapping("/prescriptions")
    public PageResponse<PrescriptionResponse> myPrescriptions(
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.DESC) Pageable pageable) {
        return PageResponse.of(prescriptionRepository.findByPatientId(myPatientId(), pageable),
                PrescriptionResponse::from);
    }

    @GetMapping("/bills")
    public PageResponse<BillResponse> myBills(
            @PageableDefault(size = 20, sort = "id", direction = Sort.Direction.DESC) Pageable pageable) {
        return PageResponse.of(billRepository.findByPatientId(myPatientId(), pageable),
                BillResponse::from);
    }

    private Long myPatientId() {
        Long id = currentUserService.get().getPatientId();
        if (id == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "This account is not linked to a patient record");
        }
        return id;
    }
}
