package com.medcore.hms.service;

import com.medcore.hms.entity.AppUser;
import com.medcore.hms.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class CurrentUserService {

    private final UserRepository userRepository;

    public CurrentUserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    // The logged-in user, read fresh from the database
    public AppUser get() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();

        if (auth == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Not logged in");
        }

        return userRepository.findByUsername(auth.getName())
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.UNAUTHORIZED, "Account no longer exists"));
    }

    // The hospital of the logged-in user. Every tenant query uses this value,
    // never an id sent by the client.
    public Long hospitalId() {
        Long hospitalId = get().getHospitalId();
        if (hospitalId == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,
                    "This account is not linked to a hospital");
        }
        return hospitalId;
    }
}
