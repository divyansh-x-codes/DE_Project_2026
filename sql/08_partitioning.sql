-- ============================================================================
-- BookMyShow DBMS Project - Phase 5: Declarative Table Partitioning
-- File: sql/08_partitioning.sql
-- Database: PostgreSQL 16+
-- ============================================================================
-- Purpose:
-- Demonstrates table partitioning strategies for high-volume relations in
-- BookMyShow ticketing database (designed for 20x to 100x scale).
-- Focus table: booking_seats (largest relation, 300K seed -> 6M large -> 30M+ 100x)
-- ============================================================================

SET search_path TO bms;

-- ----------------------------------------------------------------------------
-- 1. ARCHITECTURAL DECISION & PARTITION KEY SELECTION
-- ----------------------------------------------------------------------------
-- Analysis of partitioning strategies for booking_seats:
--
-- A. RANGE Partitioning:
--    - Natural choice when data has a date/time dimension (e.g., bookings.booked_at).
--    - However, booking_seats does not natively carry a timestamp column (it references
--      shows.show_id and bookings.booking_id).
--    - If range-partitioned by show_id or synthetic date, partition boundaries require
--      continuous administrative maintenance.
--
-- B. HASH Partitioning (Recommended for booking_seats):
--    - Partitioning by HASH (show_id) distributes seat allocations across N partitions.
--    - High concurrency benefit: Every seat lookup, seat selection, and concurrent lock check
--      for a specific show (Query R03, W02, W03) is localized to a SINGLE partition.
--    - Eliminates table-wide index bloat, reduces B-tree height, and maximizes CPU cache hits.
--    - No hot-spots during high-demand flash sales because different screens/shows hash to
--      different partitions.
--
-- C. PostgreSQL Primary Key Constraint Rule:
--    - In PostgreSQL declarative partitioning, any UNIQUE or PRIMARY KEY constraint on
--      a partitioned table MUST include the partition key as part of its composite key.
--    - Original table: PRIMARY KEY (booking_id, seat_id)
--    - Partitioned table: PRIMARY KEY (show_id, booking_id, seat_id)
--    - In addition, the business constraint UNIQUE (show_id, seat_id) naturally satisfies
--      the rule because it already contains the partition key (show_id).
-- ----------------------------------------------------------------------------

-- Drop existing partitioned table if re-running
DROP TABLE IF EXISTS bms.booking_seats_partitioned CASCADE;

-- ----------------------------------------------------------------------------
-- 2. CREATE PARTITIONED PARENT TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE bms.booking_seats_partitioned (
    booking_id INT NOT NULL,
    show_id    INT NOT NULL,
    seat_id    INT NOT NULL,
    price      NUMERIC(8, 2) NOT NULL CHECK (price > 0),

    -- Primary Key must include the partition key (show_id)
    PRIMARY KEY (show_id, booking_id, seat_id),

    -- Unique constraint guarantees no seat can be booked twice for the same show
    CONSTRAINT uq_bsp_show_seat UNIQUE (show_id, seat_id),

    -- Foreign keys
    CONSTRAINT fk_bsp_booking FOREIGN KEY (booking_id) REFERENCES bms.bookings(booking_id) ON DELETE CASCADE,
    CONSTRAINT fk_bsp_show    FOREIGN KEY (show_id)    REFERENCES bms.shows(show_id) ON DELETE RESTRICT,
    CONSTRAINT fk_bsp_seat    FOREIGN KEY (seat_id)    REFERENCES bms.seats(seat_id) ON DELETE RESTRICT
) PARTITION BY HASH (show_id);

-- ----------------------------------------------------------------------------
-- 3. CREATE CHILD PARTITIONS (4 HASH SLICES FOR CONCURRENT WORKLOADS)
-- ----------------------------------------------------------------------------
CREATE TABLE bms.booking_seats_p0 PARTITION OF bms.booking_seats_partitioned
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);

CREATE TABLE bms.booking_seats_p1 PARTITION OF bms.booking_seats_partitioned
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);

CREATE TABLE bms.booking_seats_p2 PARTITION OF bms.booking_seats_partitioned
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);

CREATE TABLE bms.booking_seats_p3 PARTITION OF bms.booking_seats_partitioned
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- ----------------------------------------------------------------------------
-- 4. CREATE SECONDARY INDEXES ON PARTITIONS
-- ----------------------------------------------------------------------------
-- Secondary index on seat_id for reverse seat analytics (e.g. Query R11, R24)
CREATE INDEX idx_bsp_seat_id ON bms.booking_seats_partitioned (seat_id);

-- ----------------------------------------------------------------------------
-- 5. POPULATE PARTITIONED TABLE FROM SEED DATA
-- ----------------------------------------------------------------------------
INSERT INTO bms.booking_seats_partitioned (booking_id, show_id, seat_id, price)
SELECT booking_id, show_id, seat_id, price
FROM bms.booking_seats;

-- Collect planner statistics on all partitions
ANALYZE bms.booking_seats_partitioned;

-- ----------------------------------------------------------------------------
-- 6. PARTITION PRUNING DEMONSTRATION & VERIFICATION
-- ----------------------------------------------------------------------------
-- Enable partition pruning explicitly (default in PG 11+)
SET enable_partition_pruning = ON;

-- Test Query 1: Single show seat check (Query R03 pattern)
-- The planner calculates HASH(101) % 4 and prunes 3 out of 4 partitions at compile time.
EXPLAIN (ANALYZE, BUFFERS)
SELECT seat_id, price
FROM bms.booking_seats_partitioned
WHERE show_id = 101;

-- Test Query 2: Row distribution across child partitions
SELECT 
    tableoid::regclass AS partition_name,
    count(*) AS row_count,
    round(100.0 * count(*) / sum(count(*)) over (), 2) AS percentage
FROM bms.booking_seats_partitioned
GROUP BY tableoid::regclass
ORDER BY partition_name;

-- ----------------------------------------------------------------------------
-- 7. ALTERNATIVE: RANGE PARTITIONING FOR BOOKINGS (BY MONTH)
-- ----------------------------------------------------------------------------
-- For temporal tables like 'bookings', RANGE partitioning by booked_at is optimal:
/*
CREATE TABLE bms.bookings_range_partitioned (
    booking_id    INT NOT NULL,
    booking_code  VARCHAR(20) NOT NULL,
    customer_id   INT NOT NULL,
    show_id       INT NOT NULL,
    status        VARCHAR(20) NOT NULL,
    total_amount  NUMERIC(10, 2) NOT NULL,
    booked_at     TIMESTAMPTZ NOT NULL,
    offer_code    VARCHAR(20),
    PRIMARY KEY (booked_at, booking_id)
) PARTITION BY RANGE (booked_at);

CREATE TABLE bms.bookings_2026_05 PARTITION OF bms.bookings_range_partitioned
    FOR VALUES FROM ('2026-05-01 00:00:00+05:30') TO ('2026-06-01 00:00:00+05:30');

CREATE TABLE bms.bookings_2026_06 PARTITION OF bms.bookings_range_partitioned
    FOR VALUES FROM ('2026-06-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');

CREATE TABLE bms.bookings_2026_07 PARTITION OF bms.bookings_range_partitioned
    FOR VALUES FROM ('2026-07-01 00:00:00+05:30') TO ('2026-08-01 00:00:00+05:30');
*/
