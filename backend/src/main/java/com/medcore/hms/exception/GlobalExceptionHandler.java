package com.medcore.hms.exception;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.core.PropertyReferenceException;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;

// Every error uses the standard problem format (RFC 9457, Content-Type application/problem+json):
// title, status and detail. Validation failures also list "errors"; every error has a "timestamp".
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ProblemDetail> handleValidationErrors(MethodArgumentNotValidException ex) {

        List<String> errors = ex.getBindingResult()
                .getFieldErrors()
                .stream()
                .map(FieldError::getDefaultMessage)
                .distinct()
                .toList();

        ProblemDetail problem = problem(HttpStatus.BAD_REQUEST, "Validation failed",
                "One or more fields are invalid");
        problem.setProperty("errors", errors);
        return respond(problem);
    }

    @ExceptionHandler({PatientNotFoundException.class, DoctorNotFoundException.class,
            AppointmentNotFoundException.class, PrescriptionNotFoundException.class,
            BillNotFoundException.class})
    public ResponseEntity<ProblemDetail> handleNotFound(RuntimeException ex) {
        return respond(problem(HttpStatus.NOT_FOUND, "Not found", ex.getMessage()));
    }

    // Business rule refusals (409, 403, 400...). The message is written by us, so it is safe to show.
    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<ProblemDetail> handleStatus(ResponseStatusException ex) {
        String detail = ex.getReason() != null ? ex.getReason() : "The request could not be completed";
        return respond(problem(ex.getStatusCode(), "Request refused", detail));
    }

    // A sort=... value that names a field the list does not have
    @ExceptionHandler(PropertyReferenceException.class)
    public ResponseEntity<ProblemDetail> handleUnknownSortField(PropertyReferenceException ex) {
        return respond(problem(HttpStatus.BAD_REQUEST, "Bad request",
                "The sort parameter names a field that cannot be sorted on. "
                        + "Use a field from the response, for example sort=id,desc"));
    }

    // The same message for every endpoint. The parser's own text is not sent back,
    // because it can name internal class names.
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ProblemDetail> handleUnreadableBody(HttpMessageNotReadableException ex) {
        return respond(problem(HttpStatus.BAD_REQUEST, "Bad request",
                "Malformed JSON or a value in the wrong format. Check the field names, dates "
                        + "(yyyy-MM-dd), times (HH:mm:ss) and enum values (upper case)."));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ProblemDetail> handleDataIntegrity(DataIntegrityViolationException ex) {
        return respond(problem(HttpStatus.CONFLICT, "Conflict",
                "Operation conflicts with existing data: the record is still referenced by other "
                        + "records (appointments, prescriptions, bills, user accounts) or duplicates "
                        + "an existing value"));
    }

    private static ProblemDetail problem(HttpStatusCode status, String title, String detail) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, detail);
        problem.setTitle(title);
        problem.setProperty("timestamp", Instant.now());
        return problem;
    }

    private static ResponseEntity<ProblemDetail> respond(ProblemDetail problem) {
        return ResponseEntity.status(problem.getStatus()).body(problem);
    }
}
