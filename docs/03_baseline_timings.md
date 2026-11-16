# Phase 3: Baseline Query Performance Report

**Project:** BookMyShow Movie & Event Ticketing Database (DBMS Project 2026)  
**Team:** T0052 · **Section:** A · **Database:** PostgreSQL 16+  
**File:** `docs/03_baseline_timings.md`  

---

## 1. Introduction

### What is a Baseline?
A **baseline** is the starting performance measurement of a system before any optimizations or custom tuning indexes are applied. In Phase 3, we measure how the 30 standard workload queries perform on our clean relational schema created in Phase 2. This baseline database has only primary keys, unique constraints, and the show exclusion constraint—no custom secondary indexes have been added.

### Why Measure Query Execution Time?
Measuring query execution time tells us exactly how long PostgreSQL takes to process each request in milliseconds (ms). It helps us identify query bottlenecks, detect expensive table scans, and establishes an objective standard to prove how much faster our queries become in Phase 4.

### Why Run Each Query Three Times?
Running a query only once can produce an unrepresentative time due to "cold cache" effects (reading pages from disk storage into memory). Subsequent runs benefit from a "warm cache" (pages already resident in PostgreSQL shared buffers). Running three times also helps account for operating system scheduling and background CPU variations.

### Why Calculate the Average?
Calculating the arithmetic mean (average) across the three runs smooths out temporary system fluctuations and provides a reliable, reproducible performance number.

---

## 2. Database Information

- **Database Name:** `bookmyshow_db`
- **Database Schema:** `bms`
- **DBMS Version:** PostgreSQL 16
- **Total Workload Queries:** 30
  - **Read Queries:** 25 (`R01` to `R25`)
  - **Write Queries:** 5 (`W01` to `W05`)
- **Benchmark Runs per Query:** 3 runs
- **Measurement Tool:** `benchmarks/run_benchmark.sh` using `EXPLAIN (ANALYZE, BUFFERS)`
- **Data Safety:** All write queries (`W01`–`W05`) are executed inside transactional `BEGIN ... ROLLBACK` blocks, ensuring database records remain 100% unchanged.

---

## 3. Baseline Timing Table (All 30 Queries)

All values represent actual PostgreSQL `Execution Time` in milliseconds (ms) recorded during benchmarking and saved in `benchmarks/results/baseline/`.

| Query ID | Query Description | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|:---:|---|:---:|---:|---:|---:|---:|
| **R01** | Home page: movies showing in Bengaluru on 2 July 2026 and how many shows each has | READ | 9.688 | 6.161 | 5.244 | **7.031** |
| **R02** | Showtimes page: shows of movie 2 in Bengaluru on 2 July 2026, grouped by cinema | READ | 3.953 | 4.426 | 4.296 | **4.225** |
| **R03** | Seat layout: every seat of show 144446 and whether it is already sold | READ | 0.356 | 0.286 | 0.382 | **0.341** |
| **R04** | Support: open a booking by its code | READ | 0.040 | 0.036 | 0.029 | **0.035** |
| **R05** | "My bookings": customer 1331's upcoming confirmed shows | READ | 9.396 | 8.413 | 8.377 | **8.729** |
| **R06** | Search: movies whose title contains "kalki" | READ | 0.090 | 0.077 | 0.085 | **0.084** |
| **R07** | Cinema dashboard: occupancy of every show at venue 11 on 28 June 2026 | READ | 1.374 | 0.969 | 1.016 | **1.120** |
| **R08** | Box office: top 10 movies by collections over the weekend of 26–28 June 2026 | READ | 18.128 | 18.553 | 18.585 | **18.422** |
| **R09** | Seat-lock service: bookings still PENDING more than 10 minutes after they were made | READ | 8.261 | 6.923 | 8.315 | **7.833** |
| **R10** | Cinema operations: consecutive shows on same screen with less than 30 min for cleaning | READ | 287.848 | 323.960 | 274.059 | **295.289** |
| **R11** | Revenue mix: share of ticket revenue from recliner seats, per screen type | READ | 60.913 | 67.841 | 64.733 | **64.496** |
| **R12** | Fans: customers who booked the same movie more than once | READ | 93.882 | 95.761 | 89.168 | **92.937** |
| **R13** | Partnerships: offers that have never been redeemed | READ | 14.550 | 14.037 | 13.986 | **14.191** |
| **R14** | Movie pages: average user rating of 2026 releases with at least 20 reviews | READ | 5.591 | 5.224 | 5.619 | **5.478** |
| **R15** | Capacity planning: bookings by weekday and hour of booking | READ | 37.439 | 38.672 | 38.558 | **38.223** |
| **R16** | Cinema partners: cancellation rate per venue for June 2026 shows | READ | 24.347 | 22.459 | 22.218 | **23.008** |
| **R17** | Cinema operations: seats of screen 101 never sold for any June 2026 show | READ | 32.305 | 32.573 | 34.924 | **33.267** |
| **R18** | Regional insights: collections per language per city in 2026 | READ | 68.789 | 71.450 | 68.062 | **69.434** |
| **R19** | Distributor report: tickets sold for every June 2026 show of movie 2 | READ | 1843.039 | 1650.529 | 2103.047 | **1865.538** |
| **R20** | Finance: daily collections and running total for June 2026 | READ | 30.496 | 28.257 | 33.197 | **30.650** |
| **R21** | Loyalty: 20 customers with the most confirmed bookings in 2026 | READ | 65.258 | 63.354 | 67.162 | **65.258** |
| **R22** | Support console: all bookings, newest first, page 4,001 (25 per page) | READ | 48.521 | 55.914 | 46.920 | **50.452** |
| **R23** | Sign-in with mobile number | READ | 0.076 | 0.048 | 0.029 | **0.051** |
| **R24** | Pricing: average price paid per seat class in each city (2026) | READ | 89.651 | 74.269 | 77.139 | **80.353** |
| **R25** | Programming: average occupancy of late-night shows (>= 22:30) in June 2026 | READ | 26.808 | 25.814 | 25.295 | **25.972** |
| **W01** | Checkout: create a PENDING booking for 2 tickets of show 144446 | WRITE | 0.916 | 0.642 | 0.615 | **0.724** |
| **W02** | Seat lock: oldest PENDING booking adds 2 unsold seats with lowest ids | WRITE | 10.613 | 10.720 | 10.721 | **10.685** |
| **W03** | Payment callback: confirm the oldest PENDING booking | WRITE | 0.831 | 0.611 | 0.645 | **0.696** |
| **W04** | Seat-lock expiry: release seats held by PENDING bookings older than 10 min | WRITE | 8.349 | 8.692 | 8.834 | **8.625** |
| **W05** | Pricing: 10% higher prices for all July weekend shows of movie 2 | WRITE | 6.743 | 6.984 | 6.064 | **6.597** |
| **TOTAL** | **Sum of all 30 individual query averages** | — | — | — | — | **2829.744** |

---

## 4. Query Execution Plans & Scan Analysis

The table below describes the scan types observed in each query's execution plan, an explanation of why the query performs as it does, and its relative speed on this dataset.

| Query ID | Scan Type(s) in Plan | Explanation in Simple English | Relative Speed |
|:---:|---|---|:---:|
| **R01** | • Index Scan on `movies`<br>• Seq Scan on `screens`, `venues`<br>• Index Scan on `shows` | Uses the show exclusion index on dates and primary key on movies, but performs sequential scans on venues/screens to filter city. | Fast (7.03 ms) |
| **R02** | • Seq Scan on `screens`, `venues`<br>• Index Scan on `shows` | Uses show exclusion index for date range filtering, then scans screens and venues. Fast because few shows match movie 2 on that date. | Fast (4.23 ms) |
| **R03** | • Index Scan on `shows`, `seats`<br>• Index Only Scan on `booking_seats` | Checks seat availability for one show. Sub-millisecond because it uses primary key and unique constraints directly. | Very Fast (0.34 ms) |
| **R04** | • Index Scan on `bookings` | Single row lookup by `booking_code` using the unique B-tree index. Almost instantaneous. | Very Fast (0.04 ms) |
| **R05** | • Seq Scan on `bookings`, `movies`, `screens`, `venues`<br>• Index Scan on `shows` | Scans all 150,094 rows in `bookings` because `customer_id` has no secondary index yet. | Fast / Moderate (8.73 ms) |
| **R06** | • Seq Scan on `movies` | Scans all 300 rows of the `movies` table to match substring `%kalki%`. Fast because the table is small. | Very Fast (0.08 ms) |
| **R07** | • Index Scan on `screens`<br>• Bitmap Scan on `shows`<br>• Index Only Scan on `booking_seats` | Uses unique index on screens and exclusion index on shows to compute venue occupancy for a single date. | Very Fast (1.12 ms) |
| **R08** | • Seq Scan on `bookings`, `shows`, `movies` | Scans 150,094 bookings and 160,034 shows to aggregate box-office collections over a 3-day weekend window. | Moderate (18.42 ms) |
| **R09** | • Seq Scan on `bookings` | Sequentially scans the entire `bookings` table to filter rows where `status = 'PENDING'` and `booked_at < ...`. | Fast (7.83 ms) |
| **R10** | • Seq Scan on `shows` | Joins the 160,034-row `shows` table against itself to find consecutive shows with cleaning gap < 30 min. Slow due to nested comparisons. | Slow (295.29 ms) |
| **R11** | • Seq Scan on `booking_seats`, `seats`, `screens` | Scans all 300,389 booking seats and 94,056 physical seats to calculate recliner revenue percentages. | Moderate (64.50 ms) |
| **R12** | • Seq Scan on `shows`, `bookings` | Scans shows and bookings to group by customer and movie for repeat bookings. | Moderate (92.94 ms) |
| **R13** | • Seq Scan on `offers`, `bookings` | Checks for unredeemed offers using `NOT IN`. Returns 0 rows because `bookings.offer_code` contains NULLs (SQL three-valued logic flaw). | Fast (14.19 ms) |
| **R14** | • Seq Scan on `movie_reviews`, `movies` | Scans 32,510 reviews and 300 movies to calculate average ratings. Fast due to relatively compact table sizes. | Fast (5.48 ms) |
| **R15** | • Seq Scan on `bookings` | Full table scan over 150,094 bookings to aggregate booking patterns by day of week and hour. | Moderate (38.22 ms) |
| **R16** | • Seq Scan on `bookings`, `shows`, `screens`, `venues` | Scans bookings and shows across June 2026 to calculate venue cancellation percentages. | Moderate (23.01 ms) |
| **R17** | • Seq Scan on `booking_seats`, `shows`<br>• Index Scan on `seats` | Checks unsold seats for screen 101 across June 2026 using a `NOT EXISTS` subquery. | Moderate (33.27 ms) |
| **R18** | • Seq Scan on `bookings`, `shows`, `movies`, `screens`, `venues` | Multi-table join across 5 tables to aggregate ticket revenue by city and language for the entire year 2026. | Moderate (69.43 ms) |
| **R19** | • Seq Scan on `shows`, `bookings` | Correlated scalar subquery: scans `shows` for movie 2 and executes a full scan on 150,094 `bookings` for every show. Extremely slow. | Very Slow (1865.54 ms) |
| **R20** | • Seq Scan on `bookings` | Full table scan of bookings followed by sorting and window function calculation for June daily running totals. | Moderate (30.65 ms) |
| **R21** | • Seq Scan on `bookings` | Scans all 150,094 bookings to sum spend and find top 20 loyal customers in 2026. | Moderate (65.26 ms) |
| **R22** | • Seq Scan on `bookings` | Scans all bookings, sorts by `booked_at DESC`, and skips 100,000 rows (`OFFSET 100000 LIMIT 25`). Takes ~50 ms due to offset scanning. | Moderate (50.45 ms) |
| **R23** | • Index Scan on `customers` | Point lookup by mobile number using the unique index `uq_customers_phone`. Finished in 0.051 ms. | Very Fast (0.05 ms) |
| **R24** | • Seq Scan on `booking_seats`, `seats`, `screens`, `venues` | Joins four physical and transactional tables to compute average price per seat class per city. | Moderate (80.35 ms) |
| **R25** | • Seq Scan on `booking_seats`, `shows`, `screens` | Scans shows starting after 22:30 in June and joins with booking seats to compute late-night occupancy. | Moderate (25.97 ms) |
| **W01** | • (no scan) | Direct single-row `INSERT` into `bookings`. Finished in 0.72 ms. | Very Fast (0.72 ms) |
| **W02** | • Index Scan on `bookings`, `seats`, `shows`<br>• Index Only Scan on `booking_seats` | Finds the oldest pending booking and inserts unsold seats using primary keys and unique indexes. | Fast (10.69 ms) |
| **W03** | • Index Scan on `bookings` | Single-row status `UPDATE` on the oldest pending booking using primary key lookup. | Very Fast (0.70 ms) |
| **W04** | • Seq Scan on `bookings`<br>• Index Scan on `booking_seats` | Deletes expired seats by joining pending bookings older than 10 minutes against `booking_seats`. | Fast (8.63 ms) |
| **W05** | • Seq Scan on `shows` | Scans `shows` to increase weekend base prices for movie 2 in July by 10%. | Fast (6.60 ms) |

---

## 5. Performance Summary & Key Observations

### 5.1 Overall Execution Time
- **Total Average Execution Time (Sum of all 30 queries):** **`2,829.744 ms`** (~2.83 seconds).
- **Slowest Query:** **`R19`** (**`1,865.538 ms`**). This single query accounts for **65.9%** of the entire workload execution time.
- **Fastest Query:** **`R04`** (**`0.035 ms`**), an exact index seek on `bookings(booking_code)`.

### 5.2 Key Observations
1. **Index Lookups are Extremely Fast:** Queries filtering on columns that already have unique constraints or primary keys (`R04`, `R23`, `R03`, `W03`) execute in less than a millisecond.
2. **Sequential Scans Dominate Analytical Workloads:** In Phase 2, no custom tuning indexes were created. As a result, PostgreSQL must perform sequential scans on large tables (`bookings`: 150,094 rows; `shows`: 160,034 rows; `booking_seats`: 300,389 rows) whenever filtering on non-key columns such as `customer_id`, `status`, `starts_at`, or `booked_at`.
3. **The Correlated Subquery Bottleneck in `R19`:** Query `R19` uses a correlated scalar subquery `(SELECT sum(num_tickets) FROM bookings b WHERE b.show_id = s.show_id ...)`. Because `bookings.show_id` is unindexed, PostgreSQL rescans thousands of booking rows for each individual show of movie 2, consuming 1.87 seconds.
4. **The Self-Join Bottleneck in `R10`:** Query `R10` compares consecutive shows on the same screen. Without an index on `(screen_id, starts_at)`, PostgreSQL performs heavy nested comparisons over 160,034 shows, taking 295.29 ms.
5. **The SQL Three-Valued Logic Flaw in `R13`:** Query `R13` attempts to find unredeemed offers using `WHERE offer_code NOT IN (SELECT offer_code FROM bookings)`. Because `bookings.offer_code` contains 127,659 NULL values, SQL evaluates `NOT IN (..., NULL)` to UNKNOWN/false for every row, returning 0 rows even though unredeemed offers exist.
6. **Write Queries are Efficient:** All write queries (`W01`–`W05`) executed safely within rollback transactions in less than 11 ms each.

### 5.3 Roadmap for Phase 4 Optimization
1. **Targeted B-Tree Indexes:**
   - Add indexes on foreign keys: `bookings(customer_id)`, `bookings(show_id)`, `shows(movie_id, starts_at)`, and `booking_seats(seat_id)`.
   - Add partial indexes on active statuses (e.g., `bookings(status, booked_at) WHERE status = 'PENDING'`).
2. **Query Rewriting:**
   - Rewrite `R19` to replace the correlated scalar subquery with an aggregated `LEFT JOIN`.
   - Rewrite `R13` using `NOT EXISTS` or filtering `WHERE offer_code IS NOT NULL` to correct the empty result set.
   - Refactor `R22` from high-offset pagination (`OFFSET 100000`) to cursor-based / keyset pagination.