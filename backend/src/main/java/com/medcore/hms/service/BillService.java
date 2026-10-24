package com.medcore.hms.service;

import com.medcore.hms.entity.Appointment;
import com.medcore.hms.entity.AppointmentStatus;
import com.medcore.hms.entity.AuditAction;
import com.medcore.hms.entity.Bill;
import com.medcore.hms.entity.PaymentStatus;
import com.medcore.hms.exception.AppointmentNotFoundException;
import com.medcore.hms.exception.BillNotFoundException;
import com.medcore.hms.exception.PatientNotFoundException;
import com.medcore.hms.repository.AppointmentRepository;
import com.medcore.hms.repository.BillRepository;
import com.medcore.hms.repository.PatientRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class BillService {

    private final BillRepository billRepository;
    private final PatientRepository patientRepository;
    private final AppointmentRepository appointmentRepository;
    private final CurrentUserService currentUserService;
    private final AuditService auditService;

    public BillService(
            BillRepository billRepository,
            PatientRepository patientRepository,
            AppointmentRepository appointmentRepository,
            CurrentUserService currentUserService,
            AuditService auditService) {

        this.billRepository = billRepository;
        this.patientRepository = patientRepository;
        this.appointmentRepository = appointmentRepository;
        this.currentUserService = currentUserService;
        this.auditService = auditService;
    }

    @Transactional
    public Bill saveBill(Bill bill) {

        Long hospitalId = currentUserService.hospitalId();
        checkReferences(bill, hospitalId);

        if (billRepository.existsByAppointmentIdAndHospitalId(bill.getAppointmentId(), hospitalId)) {
            throw conflict("A bill already exists for this appointment");
        }

        bill.setId(null);                       // always create a new record
        bill.setHospitalId(hospitalId);         // never from the request
        checkPayment(bill);
        calculateTotal(bill);
        Bill saved = billRepository.save(bill);
        auditService.recordChange(AuditAction.CREATE, "Bill", saved.getId());
        return saved;
    }

    @Transactional
    public Bill updateBill(Long id, Bill updatedBill) {

        Bill bill = findOrThrow(id);
        Long hospitalId = currentUserService.hospitalId();

        checkReferences(updatedBill, hospitalId);

        // Moving a bill onto an appointment that already has another bill is refused
        if (billRepository.existsByAppointmentIdAndHospitalIdAndIdNot(
                updatedBill.getAppointmentId(), hospitalId, id)) {
            throw conflict("A bill already exists for this appointment");
        }

        bill.setPatientId(updatedBill.getPatientId());
        bill.setAppointmentId(updatedBill.getAppointmentId());
        bill.setConsultationFee(updatedBill.getConsultationFee());
        bill.setMedicineFee(updatedBill.getMedicineFee());
        bill.setPaymentStatus(updatedBill.getPaymentStatus());
        bill.setPaymentDate(updatedBill.getPaymentDate());
        checkPayment(bill);
        calculateTotal(bill);

        Bill saved = billRepository.save(bill);
        auditService.recordChange(AuditAction.UPDATE, "Bill", id);
        return saved;
    }

    // Soft delete: the bill stays in the database, hidden from every query
    @Transactional
    public void deleteBill(Long id) {
        billRepository.delete(findOrThrow(id));
        auditService.recordChange(AuditAction.DELETE, "Bill", id);
    }

    // ?status= filters by payment status
    @Transactional(readOnly = true)
    public Page<Bill> getAllBills(PaymentStatus status, Pageable pageable) {
        Specification<Bill> spec = ListFilters.and(
                ListFilters.<Bill>inHospital(currentUserService.hospitalId()),
                ListFilters.<Bill>equal("paymentStatus", status));
        return billRepository.findAll(spec, pageable);
    }

    // The patient and the appointment must exist in this hospital, must belong together,
    // and a cancelled visit cannot be billed
    private void checkReferences(Bill bill, Long hospitalId) {

        if (!patientRepository.existsByIdAndHospitalId(bill.getPatientId(), hospitalId)) {
            throw new PatientNotFoundException(
                    "Patient not found with id: " + bill.getPatientId());
        }

        Appointment appointment = appointmentRepository
                .findByIdAndHospitalId(bill.getAppointmentId(), hospitalId)
                .orElseThrow(() -> new AppointmentNotFoundException(
                        "Appointment not found with id: " + bill.getAppointmentId()));

        if (!bill.getPatientId().equals(appointment.getPatientId())) {
            throw badRequest("This bill's patient is not the patient of appointment "
                    + appointment.getId());
        }

        if (appointment.getStatus() == AppointmentStatus.CANCELLED) {
            throw conflict("A cancelled appointment cannot be billed");
        }
    }

    // A paid bill needs a payment date; an unpaid bill cannot have one
    private void checkPayment(Bill bill) {

        if (bill.getPaymentStatus() == PaymentStatus.PAID) {
            if (bill.getPaymentDate() == null) {
                throw badRequest("A paid bill needs a payment date");
            }
        } else if (bill.getPaymentDate() != null) {
            throw badRequest("Only a paid bill can have a payment date");
        }
    }

    private Bill findOrThrow(Long id) {
        return billRepository.findByIdAndHospitalId(id, currentUserService.hospitalId())
                .orElseThrow(() ->
                        new BillNotFoundException(
                                "Bill not found with id: " + id));
    }

    private void calculateTotal(Bill bill) {
        bill.setTotalAmount(
                bill.getConsultationFee().add(bill.getMedicineFee()));
    }

    private ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }

    private ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }
}
