package com.medcore.hms.api;

// Every successful single-item response has this shape: {"data": {...}}
public record ApiResponse<T>(T data) {

    public static <T> ApiResponse<T> of(T data) {
        return new ApiResponse<>(data);
    }
}
