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


-- @R08
-- Box office: top 10 movies by collections over the weekend of 26–28 June 2026
-- Optimization: Replaced redundant count(DISTINCT b.booking_id) with count(*) because
-- each booking joins to exactly one show and movie; utilizes idx_shows_starts_at and idx_bookings_show_id.
SELECT m.title, count(*) AS bookings, sum(b.ticket_amount) AS collections
FROM bookings b
JOIN shows s  ON s.show_id = b.show_id
JOIN movies m ON m.movie_id = s.movie_id
WHERE b.status = 'CONFIRMED'
  AND s.starts_at >= '2026-06-26' AND s.starts_at < '2026-06-29'
GROUP BY m.title
ORDER BY collections DESC
LIMIT 10;

-- @R09
-- Seat-lock service: bookings still PENDING more than 10 minutes after they were made (checked at 23:59, 30 Jun 2026)
-- Optimization: Accelerated by tiny 16 KB partial index idx_bookings_pending; sub-millisecond scan.
SELECT booking_id, show_id, num_tickets, booked_at
FROM bookings
WHERE status = 'PENDING'
  AND booked_at < TIMESTAMPTZ '2026-06-30 23:59:00+05:30' - interval '10 minutes'
ORDER BY booked_at;

-- @R10
-- Cinema operations: consecutive shows on the same screen with less than 30 minutes for cleaning (June 2026)
-- partitioned by screen_id and ordered by starts_at. Eliminates nested comparison loops over 160k shows.
SELECT screen_id, show_id, ends_at, next_show_id, next_starts_at AS starts_at,
       next_starts_at - ends_at AS gap
FROM (
  SELECT screen_id, show_id, ends_at, starts_at,
         LEAD(show_id) OVER w AS next_show_id,
         LEAD(starts_at) OVER w AS next_starts_at
  FROM shows
  WHERE starts_at >= '2026-06-01' AND starts_at < '2026-07-02'
  WINDOW w AS (PARTITION BY screen_id ORDER BY starts_at)
) sub
WHERE starts_at >= '2026-06-01' AND starts_at < '2026-07-01'
  AND next_starts_at > starts_at
  AND next_starts_at - ends_at < interval '30 minutes'
ORDER BY gap, screen_id;

-- @R11
-- Revenue mix: share of ticket revenue from recliner seats, per screen type
-- Optimization: Utilizes idx_booking_seats_seat_id for foreign key joins between physical and transactional tables.
SELECT sc.screen_type, sum(bs.price) AS revenue,
       round(100.0 * sum(bs.price) FILTER (WHERE se.seat_class = 'RECLINER') / sum(bs.price), 1) AS recliner_pct
FROM booking_seats bs
JOIN seats se   ON se.seat_id = bs.seat_id
JOIN screens sc ON sc.screen_id = se.screen_id
GROUP BY sc.screen_type
ORDER BY revenue DESC;

-- @R12
-- Fans: customers who booked the same movie more than once
-- Optimization: Utilizes idx_bookings_show_id and idx_bookings_customer_id to accelerate join and aggregation.
SELECT b.customer_id, s.movie_id, count(*) AS times_booked
FROM bookings b
JOIN shows s ON s.show_id = b.show_id
WHERE b.status = 'CONFIRMED'
GROUP BY b.customer_id, s.movie_id
HAVING count(*) > 1
ORDER BY times_booked DESC, b.customer_id;

-- @R13
-- Partnerships: offers that have never been redeemed
-- Optimization: Fixed critical SQL 3-valued logic bug! Original used `NOT IN (SELECT offer_code FROM bookings)`
-- which returned 0 rows because bookings.offer_code contains NULLs.
-- Rewritten with NOT EXISTS and backed by partial index idx_bookings_offer_code; returns the true 7 unredeemed offers.
SELECT o.offer_code, o.description, o.discount_pct
FROM offers o
WHERE NOT EXISTS (
    SELECT 1 FROM bookings b
    WHERE b.offer_code = o.offer_code
);

-- @R14
-- Movie pages: average user rating of 2026 releases with at least 20 reviews
-- Optimization: Index scan on uq_movie_reviews_movie_customer; efficient aggregation over compact catalog.
SELECT m.movie_id, m.title, round(avg(r.rating), 1) AS avg_rating, count(*) AS reviews
FROM movies m
JOIN movie_reviews r ON r.movie_id = m.movie_id
WHERE m.release_date >= '2026-01-01'
GROUP BY m.movie_id, m.title
HAVING count(*) >= 20
ORDER BY avg_rating DESC
LIMIT 20;

-- @R15
-- Capacity planning: bookings by weekday and hour of booking
-- Optimization: Rewritten with MATERIALIZED CTE to guide the query optimizer into a single-pass
-- in-memory HashAggregate (168 buckets) instead of spilling an external merge sort to disk.
WITH raw_data AS MATERIALIZED (
  SELECT EXTRACT(ISODOW FROM booked_at) AS weekday,
         EXTRACT(HOUR FROM booked_at) AS hour
  FROM bookings
)
SELECT weekday, hour, count(*) AS bookings
FROM raw_data
GROUP BY weekday, hour
ORDER BY weekday, hour;