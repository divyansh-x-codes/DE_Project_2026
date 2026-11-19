SET search_path TO bms;
BEGIN;

-- @R01
-- Home page: movies showing in Bengaluru on 2 July 2026 and how many shows each has
-- Optimization: Sargable timestamp range condition instead of DATE(s.starts_at) function call,
-- enabling Index Scan on idx_shows_starts_at.

SELECT m.movie_id, m.title, m.language, m.certificate, count(*) AS shows
FROM shows s
JOIN movies m   ON m.movie_id = s.movie_id
JOIN screens sc ON sc.screen_id = s.screen_id
JOIN venues v   ON v.venue_id = sc.venue_id
WHERE v.city_id = 1
  AND s.starts_at >= '2026-07-02 00:00:00+05:30' AND s.starts_at < '2026-07-03 00:00:00+05:30'
GROUP BY m.movie_id, m.title, m.language, m.certificate
ORDER BY shows DESC;

-- @R02
-- Showtimes page: shows of movie 2 in Bengaluru on 2 July 2026, grouped by cinema
-- Optimization: Already sargable; accelerated by composite index idx_shows_movie_starts.
SELECT v.venue_name, sc.screen_type, s.show_id, s.starts_at, s.format, s.base_price
FROM shows s
JOIN screens sc ON sc.screen_id = s.screen_id
JOIN venues v   ON v.venue_id = sc.venue_id
WHERE s.movie_id = 2
  AND v.city_id = 1
  AND s.starts_at >= '2026-07-02' AND s.starts_at < '2026-07-03'
ORDER BY v.venue_name, s.starts_at;

-- @R03
-- Seat layout: every seat of show 144446 and whether it is already sold
-- Optimization: Primary key & unique constraints utilized directly; sub-millisecond execution.
SELECT se.row_label, se.seat_number, se.seat_class, (bs.seat_id IS NOT NULL) AS sold
FROM shows s
JOIN seats se ON se.screen_id = s.screen_id
LEFT JOIN booking_seats bs ON bs.show_id = s.show_id AND bs.seat_id = se.seat_id
WHERE s.show_id = 144446
ORDER BY se.row_label DESC, se.seat_number;

-- @R04
-- Support: open a booking by its code
-- Optimization: Single row lookup via unique index bookings_booking_code_key.
SELECT booking_id, customer_id, show_id, num_tickets, total_amount, status, booked_at
FROM bookings
WHERE booking_code = 'BMSA45E9F9';

-- @R05
-- "My bookings": customer 1331's upcoming confirmed shows
-- Optimization: Uses B-tree index idx_bookings_customer_id, replacing 150k-row table scan.
SELECT b.booking_code, m.title, s.starts_at, v.venue_name, b.num_tickets
FROM bookings b
JOIN shows s    ON s.show_id = b.show_id
JOIN movies m   ON m.movie_id = s.movie_id
JOIN screens sc ON sc.screen_id = s.screen_id
JOIN venues v   ON v.venue_id = sc.venue_id
WHERE b.customer_id = 1331 AND b.status = 'CONFIRMED'
  AND s.starts_at >= '2026-07-01'
ORDER BY s.starts_at;

-- @R06
-- Search: movies whose title contains "kalki"
-- Optimization: Supported by GIN trigram index idx_movies_title_trgm for scalable pattern search.
SELECT movie_id, title, language, release_date
FROM movies
WHERE title ILIKE '%kalki%'
ORDER BY release_date DESC;

-- @R07
-- Cinema dashboard: occupancy of every show at venue 11 on 28 June 2026
-- Optimization: Sargable range condition on s.starts_at replacing s.starts_at::date cast,
-- using idx_shows_screen_starts / idx_shows_starts_at.
SELECT s.show_id, sc.screen_name, s.starts_at, count(bs.seat_id) AS sold, sc.total_seats,
       round(100.0 * count(bs.seat_id) / sc.total_seats, 1) AS occupancy_pct
FROM shows s
JOIN screens sc ON sc.screen_id = s.screen_id
LEFT JOIN booking_seats bs ON bs.show_id = s.show_id
WHERE sc.venue_id = 11
  AND s.starts_at >= '2026-06-28 00:00:00+05:30' AND s.starts_at < '2026-06-29 00:00:00+05:30'
GROUP BY s.show_id, sc.screen_name, s.starts_at, sc.total_seats
ORDER BY s.starts_at;
