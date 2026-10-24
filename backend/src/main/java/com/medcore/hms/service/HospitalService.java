package com.medcore.hms.service;

import com.medcore.hms.dto.HospitalDtos.HospitalRequest;
import com.medcore.hms.entity.Hospital;
import com.medcore.hms.repository.HospitalRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class HospitalService {

    private final HospitalRepository hospitalRepository;

    public HospitalService(HospitalRepository hospitalRepository) {
        this.hospitalRepository = hospitalRepository;
    }

    @Transactional
    public Hospital createHospital(HospitalRequest request) {

        if (hospitalRepository.existsByNameIgnoreCase(request.name())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "A hospital with this name already exists");
        }

        // New hospitals start unverified: their staff cannot log in until a super admin verifies them
        return hospitalRepository.save(
                new Hospital(request.name(), request.city(), request.contactEmail(), false));
    }

    @Transactional(readOnly = true)
    public Page<Hospital> getAllHospitals(Pageable pageable) {
        return hospitalRepository.findAll(pageable);
    }

    @Transactional
    public Hospital verifyHospital(Long id) {

        Hospital hospital = hospitalRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND, "Hospital not found with id: " + id));

        hospital.setVerified(true);
        return hospitalRepository.save(hospital);
    }
}
