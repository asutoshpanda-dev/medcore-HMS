package com.medcore.hms.api;

import org.springframework.data.domain.Page;

import java.util.List;
import java.util.function.Function;

// Every list response has this shape: {"data": [...], "page": {...}}
// Ask for a page with ?page=0&size=20&sort=id,desc (size is capped at 100).
public record PageResponse<T>(List<T> data, PageInfo page) {

    public static <E, T> PageResponse<T> of(Page<E> page, Function<E, T> mapper) {
        List<T> items = page.getContent().stream().map(mapper).toList();
        return new PageResponse<>(items, new PageInfo(
                page.getNumber(), page.getSize(), page.getTotalElements(), page.getTotalPages()));
    }

    public record PageInfo(int number, int size, long totalElements, int totalPages) {
    }
}
