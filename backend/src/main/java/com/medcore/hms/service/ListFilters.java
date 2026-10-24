package com.medcore.hms.service;

import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

// Building blocks for the list endpoints. Every list starts from one hospital (the tenant), then
// adds only the filters the caller sent. A filter whose value is missing is simply skipped.
final class ListFilters {

    // Escape character for LIKE patterns, so a user's % and _ are matched as plain characters
    private static final char ESCAPE = '!';

    private ListFilters() {
    }

    static <T> Specification<T> inHospital(Long hospitalId) {
        return (root, query, cb) -> cb.equal(root.get("hospitalId"), hospitalId);
    }

    // Exact match on one field. Returns null for a missing value, which and(...) treats as "no filter".
    static <T> Specification<T> equal(String field, Object value) {
        if (value == null) {
            return null;
        }
        return (root, query, cb) -> cb.equal(root.get(field), value);
    }

    // Case-insensitive "contains" on any of the given text fields. Returns null for blank text.
    static <T> Specification<T> containsAny(String text, String... fields) {
        if (text == null || text.isBlank()) {
            return null;
        }
        String pattern = likePattern(text);
        return (root, query, cb) -> {
            List<Predicate> options = new ArrayList<>();
            for (String field : fields) {
                options.add(cb.like(cb.lower(root.<String>get(field)), pattern, ESCAPE));
            }
            return cb.or(options.toArray(new Predicate[0]));
        };
    }

    // Both filters must match. A null extra filter leaves the base unchanged.
    static <T> Specification<T> and(Specification<T> base, Specification<T> extra) {
        if (extra == null) {
            return base;
        }
        return (root, query, cb) -> cb.and(
                base.toPredicate(root, query, cb),
                extra.toPredicate(root, query, cb));
    }

    private static String likePattern(String text) {
        String escaped = text.trim().toLowerCase(Locale.ROOT)
                .replace("!", "!!")
                .replace("%", "!%")
                .replace("_", "!_");
        return "%" + escaped + "%";
    }
}
