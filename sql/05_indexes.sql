
SET search_path TO bms;

-- 1. ENABLE TEXT SEARCH EXTENSION

CREATE EXTENSION IF NOT EXISTS pg_trgm;


-- 2. SHOWS TABLE INDEXES

-- Index 1: Search shows by movie and date
-- For: R02, R19, W05

CREATE INDEX IF NOT EXISTS idx_shows_movie_starts
ON shows (movie_id, starts_at);


-- Index 2: Search shows by date
-- For: R01, R08, R10, R16, R17, R18, R25

CREATE INDEX IF NOT EXISTS idx_shows_starts_at
ON shows (starts_at);


-- Index 3: Search shows by screen and time
-- For: R07, R10, R17, R25

CREATE INDEX IF NOT EXISTS idx_shows_screen_starts
ON shows (screen_id, starts_at);


-- 3. BOOKINGS TABLE INDEXES

-- Index 4: Find bookings of a particular show
-- For: R08, R12, R16, R18, R19

CREATE INDEX IF NOT EXISTS idx_bookings_show_id
ON bookings (show_id);


-- Index 5: Find bookings of a particular customer
-- For: R05, R12

CREATE INDEX IF NOT EXISTS idx_bookings_customer_id
ON bookings (customer_id);


-- Index 6: Find newest bookings first
-- For: R15, R20, R22

CREATE INDEX IF NOT EXISTS idx_bookings_booked_at_desc
ON bookings (booked_at DESC, booking_id);


-- Index 7: Find only pending bookings
-- For: R09, W02, W03, W04

CREATE INDEX IF NOT EXISTS idx_bookings_pending
ON bookings (booking_id, booked_at)
WHERE status = 'PENDING';


-- Index 8: Find bookings having an offer code
-- For: R13

CREATE INDEX IF NOT EXISTS idx_bookings_offer_code
ON bookings (offer_code)
WHERE offer_code IS NOT NULL;


-- Index 9: Find confirmed bookings with customer amounts
-- For: R21

CREATE INDEX IF NOT EXISTS idx_bookings_cust_conf
ON bookings (customer_id)
INCLUDE (total_amount)
WHERE status = 'CONFIRMED'
AND booked_at >= '2026-01-01';


-- 4. BOOKING_SEATS TABLE INDEXES

-- Index 10: Find bookings using a particular seat
-- For: R11, R17, R24

CREATE INDEX IF NOT EXISTS idx_booking_seats_seat_id
ON booking_seats (seat_id);


-- 5. VENUES TABLE INDEXES


-- Index 11: Find venues by city
-- For: R01, R02, R18, R24

CREATE INDEX IF NOT EXISTS idx_venues_city_id
ON venues (city_id);


-- 6. MOVIES TABLE INDEXES
-- Index 12: Search movie titles containing specific text
-- For: R06

CREATE INDEX IF NOT EXISTS idx_movies_title_trgm
ON movies USING GIN (title gin_trgm_ops);