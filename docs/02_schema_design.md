# Phase 2: Schema Design & Data Architecture Documentation

**Course:** Database Management Systems (DBMS)  
**Database:** PostgreSQL 15 or newer  
**Schema Name:** `bms`  
**File:** `docs/02_schema_design.md`  

---

## 1. Data Dictionary

The BookMyShow database consists of **11 tables** designed to support cinema ticket reservations, scheduling, user management, and transactional auditing.

---

### 1.1 `cities`
Master lookup table storing operational metropolitan and tier-2 cities.

| Column Name | Data Type | Constraints | Simple Explanation / Why it Exists |
|---|---|---|---|
| `city_id` | `INT` | `PRIMARY KEY` | Unique numeric identifier for each city. |
| `city_name` | `VARCHAR(50)` | `NOT NULL`, `UNIQUE` | Name of the city (e.g., Bengaluru, Mumbai). Unique prevents duplicate city records. |
| `state` | `VARCHAR(50)` | `NOT NULL` | State where the city is located (e.g., Karnataka, Maharashtra). |

---

### 1.2 `venues`
Represents physical cinema properties and multiplex theatres.

| Column Name | Data Type | Constraints | Simple Explanation / Why it Exists |
|---|---|---|---|
| `venue_id` | `INT` | `PRIMARY KEY` | Unique numeric identifier for each cinema venue. |
| `venue_name` | `VARCHAR(100)` | `NOT NULL`, `UNIQUE` | Distinct commercial name of the theatre (e.g., PVR Forum Mumbai). |
| `city_id` | `INT` | `NOT NULL`, `FK -> cities(city_id) ON DELETE RESTRICT` | Connects the theatre to its city. Cannot delete city if theatres operate in it. |
| `chain` | `VARCHAR(50)` | `NOT NULL`, `CHECK (chain IN ('Cinepolis', 'INOX', 'Independent', 'Miraj', 'PVR'))` | Cinema operating brand/chain. Whitelisted to prevent typos. |
| `address` | `TEXT` | `NOT NULL` | Physical street address and landmark for customers. |

---

### 1.3 `screens`
Represents individual auditoriums inside each cinema venue.

| Column Name | Data Type | Constraints | Simple Explanation / Why it Exists |
|---|---|---|---|
| `screen_id` | `INT` | `PRIMARY KEY` | Unique identifier for each auditorium. |
| `venue_id` | `INT` | `NOT NULL`, `FK -> venues(venue_id) ON DELETE CASCADE` | Venue housing this auditorium. Deleting a venue removes its screens. |
| `screen_name` | `VARCHAR(50)` | `NOT NULL` | Local screen name (e.g., Audi 1, Audi 2). |
| `screen_type` | `VARCHAR(20)` | `NOT NULL`, `CHECK (screen_type IN ('4DX', 'GOLD', 'IMAX', 'STANDARD'))` | Certified technical projection format of the auditorium. |
| `total_seats` | `INT` | `NOT NULL`, `CHECK (total_seats > 0)` | Total physical capacity of the auditorium. Must be positive. |
| *(Composite)* | — | `UNIQUE (venue_id, screen_name)` | Prevents duplicate screen names within the same cinema hall. |

---

### 1.4 `seats`
Represents the fixed physical seat layout for every screen.

| Column Name | Data Type | Constraints | Simple Explanation / Why it Exists |
|---|---|---|---|
| `seat_id` | `INT` | `PRIMARY KEY` | Unique surrogate identifier for every physical seat. |
| `screen_id` | `INT` | `NOT NULL`, `FK -> screens(screen_id) ON DELETE CASCADE` | Auditorium where this seat is physically located. |
| `row_label` | `VARCHAR(5)` | `NOT NULL` | Row designation code (e.g., A, B, C, ...). |
| `seat_number` | `INT` | `NOT NULL`, `CHECK (seat_number > 0)` | Seat number along the row (1, 2, 3, ...). Must be positive. |
| `seat_class` | `VARCHAR(20)` | `NOT NULL`, `CHECK (seat_class IN ('CLASSIC', 'PRIME', 'RECLINER'))` | Luxury and pricing tier of the seat. |
| *(Composite)* | — | `UNIQUE (screen_id, row_label, seat_number)` | Prevents duplicate physical coordinates inside the same screen. |

---

### 1.5 `movies`
Catalog of theatrical films exhibited across cinemas.

| Column Name | Data Type | Constraints | Simple Explanation / Why it Exists |
|---|---|---|---|
| `movie_id` | `INT` | `PRIMARY KEY` | Unique identifier for each movie. |
| `title` | `VARCHAR(200)` | `NOT NULL` | Official film title (e.g., Jawan Returns). |
| `language` | `VARCHAR(50)` | `NOT NULL`, `CHECK (language IN ('Bengali', 'English', 'Hindi', 'Kannada', 'Malayalam', 'Marathi', 'Tamil', 'Telugu'))` | Spoken audio language of the screening. |
| `certificate` | `VARCHAR(10)` | `NOT NULL`, `CHECK (certificate IN ('A', 'U', 'UA'))` | Official CBFC rating certificate. |
| `duration_min` | `INT` | `NOT NULL`, `CHECK (duration_min > 0)` | Movie runtime in minutes. Must be greater than zero. |
| `release_date` | `DATE` | `NOT NULL` | Theatrical release date. |

---

### 1.6 `shows`
Represents a scheduled screening of a film on a specific screen at a given time.

| Column Name | Data Type | Constraints | Simple Explanation / Why it Exists |
|---|---|---|---|
| `show_id` | `INT` | `PRIMARY KEY` | Unique identifier for each screening event. |
| `movie_id` | `INT` | `NOT NULL`, `FK -> movies(movie_id) ON DELETE RESTRICT` | Film being screened. Cannot delete movie if shows exist. |
| `screen_id` | `INT` | `NOT NULL`, `FK -> screens(screen_id) ON DELETE RESTRICT` | Auditorium where the show takes place. |
| `starts_at` | `TIMESTAMPTZ` | `NOT NULL` | Show start timestamp with time-zone offset (+05:30 IST). |
| `ends_at` | `TIMESTAMPTZ` | `NOT NULL`, `CHECK (ends_at > starts_at)` | Show end timestamp. Must chronologically follow starts_at. |
| `format` | `VARCHAR(10)` | `NOT NULL`, `CHECK (format IN ('2D', '3D', '4DX', 'IMAX'))` | Projection format for this specific show. |
| `base_price` | `NUMERIC(8,2)`| `NOT NULL`, `CHECK (base_price > 0)` | Base ticket cost before seat tier multipliers. Must be positive. |
| *(Exclusion)* | — | `EXCLUDE USING gist (screen_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)` | Enforces that two shows on the same screen cannot overlap in time. |

---

### 1.7 `customers`
Registered BookMyShow user accounts.

| Column Name | Data Type | Constraints | Simple Explanation / Why it Exists |
|---|---|---|---|
| `customer_id` | `INT` | `PRIMARY KEY` | Unique customer account number. |
| `full_name` | `VARCHAR(100)` | `NOT NULL` | User's full name. |
| `email` | `VARCHAR(100)` | `NOT NULL`, `UNIQUE` | User's email address. Unique ensures one account per email. |
| `phone` | `VARCHAR(15)` | `NOT NULL`, `UNIQUE` | User's 10-digit mobile phone number for OTP/sign-in. |
| `city_id` | `INT` | `NOT NULL`, `FK -> cities(city_id) ON DELETE RESTRICT` | Customer's primary home city. |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL` | Registration timestamp. |

---

### 1.8 `offers`
Promotional discount vouchers applied at checkout.

| Column Name | Data Type | Constraints | Simple Explanation / Why it Exists |
|---|---|---|---|
| `offer_code` | `VARCHAR(20)` | `PRIMARY KEY` | Alphanumeric promotional voucher code (e.g., AMAZONPAY17). |
| `description` | `VARCHAR(100)` | `NOT NULL` | Human-readable offer description (e.g., Buy one get one). |
| `discount_pct` | `INT` | `NOT NULL`, `CHECK (discount_pct > 0 AND discount_pct <= 100)` | Percentage discount applied on ticket subtotal (1% to 100%). |
| `max_discount` | `NUMERIC(8,2)`| `NOT NULL`, `CHECK (max_discount > 0)` | Maximum discount cap in rupees. |
| `valid_from` | `DATE` | `NOT NULL` | Campaign start date. |
| `valid_to` | `DATE` | `NOT NULL`, `CHECK (valid_to >= valid_from)` | Campaign expiration date. Must be on or after start date. |

---

### 1.9 `bookings`
Checkout transactions recording ticket purchases and F&B.

| Column Name | Data Type | Constraints | Simple Explanation / Why it Exists |
|---|---|---|---|
| `booking_id` | `INT` | `PRIMARY KEY` | Unique internal transaction identifier. |
| `booking_code` | `VARCHAR(12)` | `NOT NULL`, `UNIQUE` | Alphanumeric confirmation code shown on the ticket. |
| `customer_id` | `INT` | `NOT NULL`, `FK -> customers(customer_id) ON DELETE RESTRICT` | User who placed the booking. |
| `show_id` | `INT` | `NOT NULL`, `FK -> shows(show_id) ON DELETE RESTRICT` | Screening event being booked. |
| `booked_at` | `TIMESTAMPTZ` | `NOT NULL` | Transaction timestamp. |
| `num_tickets` | `INT` | `NOT NULL`, `CHECK (num_tickets > 0)` | Number of seats reserved in this transaction. |
| `ticket_amount` | `NUMERIC(8,2)`| `NOT NULL`, `CHECK (ticket_amount >= 0)` | Subtotal price of tickets. |
| `convenience_fee`| `NUMERIC(8,2)`| `NOT NULL`, `CHECK (convenience_fee >= 0)` | Internet handling/convenience charge. |
| `fnb_amount` | `NUMERIC(8,2)`| `NOT NULL`, `DEFAULT 0.00`, `CHECK (fnb_amount >= 0)` | Optional snacks and beverages subtotal. |
| `offer_code` | `VARCHAR(20)` | `NULL`, `FK -> offers(offer_code) ON DELETE SET NULL` | Promotional voucher applied (NULL if no offer used). |
| `discount` | `NUMERIC(8,2)`| `NOT NULL`, `DEFAULT 0.00`, `CHECK (discount >= 0)` | Value deducted by the offer. |
| `total_amount` | `NUMERIC(8,2)`| `NOT NULL`, `CHECK (total_amount >= 0)` | Final net payable amount charged to customer. |
| `payment_method`| `VARCHAR(20)` | `NOT NULL`, `CHECK (payment_method IN ('CARD', 'GIFT_CARD', 'NETBANKING', 'UPI', 'WALLET'))` | Payment instrument used. |
| `status` | `VARCHAR(20)` | `NOT NULL`, `CHECK (status IN ('CANCELLED', 'CONFIRMED', 'PAYMENT_FAILED', 'PENDING'))` | Current transaction state in the checkout lifecycle. |
| *(Equation)* | — | `CHECK (total_amount = (ticket_amount + convenience_fee + fnb_amount - discount))` | Ensures mathematical integrity of financial billing. |

---

### 1.10 `booking_seats`
Associative table linking each booking transaction to the physical seats reserved.

| Column Name | Data Type | Constraints | Simple Explanation / Why it Exists |
|---|---|---|---|
| `booking_id` | `INT` | `NOT NULL`, `FK -> bookings(booking_id) ON DELETE CASCADE` | Booking transaction that reserved this seat. |
| `show_id` | `INT` | `NOT NULL`, `FK -> shows(show_id) ON DELETE RESTRICT` | Show for which seat is booked (enables double-booking check). |
| `seat_id` | `INT` | `NOT NULL`, `FK -> seats(seat_id) ON DELETE RESTRICT` | Specific physical seat reserved. |
| `price` | `NUMERIC(8,2)`| `NOT NULL`, `CHECK (price > 0)` | Price charged for this seat. |
| *(Primary Key)*| — | `PRIMARY KEY (booking_id, seat_id)` | Composite key identifying each seat inside a booking. |
| *(Double Booking Invariant)* | — | `UNIQUE (show_id, seat_id)` | **CRITICAL:** Guarantees a seat can be sold only once per show. |

---

### 1.11 `movie_reviews`
Customer ratings and qualitative commentary on films.

| Column Name | Data Type | Constraints | Simple Explanation / Why it Exists |
|---|---|---|---|
| `review_id` | `INT` | `PRIMARY KEY` | Unique review identifier. |
| `movie_id` | `INT` | `NOT NULL`, `FK -> movies(movie_id) ON DELETE CASCADE` | Movie being rated. Deleting movie removes its reviews. |
| `customer_id` | `INT` | `NOT NULL`, `FK -> customers(customer_id) ON DELETE RESTRICT` | Customer who authored the review. |
| `rating` | `INT` | `NOT NULL`, `CHECK (rating >= 1 AND rating <= 10)` | Numerical rating score on a 1-to-10 scale. |
| `review_text` | `TEXT` | `NULL` | Optional written commentary (NULL for rating-only entries). |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL` | Timestamp when the review was posted. |
| *(Composite)* | — | `UNIQUE (movie_id, customer_id)` | Restricts each user to at most one review per movie. |

---

## 2. Functional Dependencies

A **functional dependency** (`X → Y`) means that knowing the value of attribute `X` uniquely determines the value of attribute `Y`.

**1. cities**
- `city_id` → `city_name, state`
- `city_name` → `city_id, state` (Candidate Key)

**2. venues**
- `venue_id` → `venue_name, city_id, chain, address`
- `venue_name` → `venue_id, city_id, chain, address` (Candidate Key)

**3. screens**
- `screen_id` → `venue_id, screen_name, screen_type, total_seats`
- `{venue_id, screen_name}` → `screen_id, screen_type, total_seats` (Candidate Key)

**4. seats**
- `seat_id` → `screen_id, row_label, seat_number, seat_class`
- `{screen_id, row_label, seat_number}` → `seat_id, seat_class` (Candidate Key)

**5. movies**
- `movie_id` → `title, language, certificate, duration_min, release_date`

**6. shows**
- `show_id` → `movie_id, screen_id, starts_at, ends_at, format, base_price`
- `{screen_id, starts_at}` → `show_id, movie_id, ends_at, format, base_price` (Enforced by exclusion constraint)

**7. customers**
- `customer_id` → `full_name, email, phone, city_id, created_at`
- `email` → `customer_id, full_name, phone, city_id, created_at` (Candidate Key)
- `phone` → `customer_id, full_name, email, city_id, created_at` (Candidate Key)

**8. offers**
- `offer_code` → `description, discount_pct, max_discount, valid_from, valid_to`

**9. bookings**
- `booking_id` → `booking_code, customer_id, show_id, booked_at, num_tickets, ticket_amount, convenience_fee, fnb_amount, offer_code, discount, total_amount, payment_method, status`
- `booking_code` → `booking_id, customer_id, show_id, booked_at, num_tickets, ticket_amount, convenience_fee, fnb_amount, offer_code, discount, total_amount, payment_method, status` (Candidate Key)

**10. booking_seats**
- `{booking_id, seat_id}` → `show_id, price`
- `{show_id, seat_id}` → `booking_id, price` (Candidate Key, prevents double-booking)

**11. movie_reviews**
- `review_id` → `movie_id, customer_id, rating, review_text, created_at`
- `{movie_id, customer_id}` → `review_id, rating, review_text, created_at` (Candidate Key)

---

## 3. Normalization Analysis (1NF, 2NF, 3NF)

### 3.1 First Normal Form (1NF)
**Rule:** Each table must have atomic (indivisible) values, no repeating groups or arrays, and a defined primary key.
- All columns store single, atomic scalar values (numbers, single strings, dates, timestamps).
- Multiple seats booked in one transaction are stored in separate rows inside `booking_seats`, rather than as comma-separated values or arrays.
- Every table has an explicit primary key.  
→ **All 11 tables satisfy 1NF.**

---

### 3.2 Second Normal Form (2NF)
**Rule:** The table must be in 1NF, and **no non-prime attribute may be partially dependent on a composite candidate key**. (Applies to tables with composite primary keys).
- Tables with single-attribute primary keys (`cities`, `venues`, `screens`, `seats`, `movies`, `shows`, `customers`, `offers`, `bookings`, `movie_reviews`) automatically satisfy 2NF because partial dependency cannot exist on a single-column key.
- In `booking_seats`, the composite primary key is `(booking_id, seat_id)`. The non-prime attribute `price` represents the specific price paid for that seat in that booking. Neither `booking_id` alone nor `seat_id` alone determines the transaction price. Therefore, full functional dependency holds.  
→ **All 11 tables satisfy 2NF.**

---

### 3.3 Third Normal Form (3NF)
**Rule:** The table must be in 2NF, and **no transitive dependency must exist** (non-key attribute determining another non-key attribute). For every dependency `X → Y`, `X` must be a superkey or `Y` must be a prime attribute.
- In `venues`, `city_id` is a foreign key. Details of the city (`city_name`, `state`) are not stored in `venues`; they are properly normalized in `cities`.
- In `customers`, `city_id` is stored, but city attributes are normalized in `cities`.
- In `shows`, details of the movie and screen are normalized into `movies` and `screens`.
- In `bookings`, customer details (name, phone) and show details (timing, movie) are not stored; only their foreign keys are kept.  
→ **All 11 tables satisfy 3NF (and BCNF).**

---

### 3.4 Controlled Redundancy (Intentional Engineering Trade-offs)
In practical database engineering, a few columns store derived or denormalized data for performance and transaction consistency:

1. **`screens.total_seats`:**  
   - *Status:* Derived from `COUNT(seats)` for that screen.  
   - *Reason:* Querying total auditorium capacity during live seat layout rendering would require an expensive `COUNT(*)` over 94k seat rows. Storing `total_seats` gives O(1) capacity lookups.
2. **`bookings.ticket_amount`:**  
   - *Status:* Derived from `SUM(booking_seats.price)`.  
   - *Reason:* Guarantees financial immutability for billing. Even if base ticket prices change later, the invoice total remains legally audit-proof.
3. **`booking_seats.show_id`:**  
   - *Status:* Transitively redundant via `booking_id -> show_id`.  
   - *Reason:* Necessary to enforce the **No-Double-Booking Invariant** using `UNIQUE (show_id, seat_id)`. Without `show_id` in `booking_seats`, checking if a seat is already sold across all bookings for that show would require an expensive subquery on every seat click.
4. **`shows.ends_at`:**  
   - *Status:* Derived from `starts_at + movies.duration_min`.  
   - *Reason:* Theatrical end times include interval buffers and trailers. Having an explicit `ends_at` enables PostgreSQL's `btree_gist` exclusion constraint to enforce non-overlapping shows instantly.

---

## 4. Actual Database Integrity Checks & Results

The following SQL integrity verification queries were executed directly against the live PostgreSQL database `bookmyshow_db` (schema `bms`):

```sql
SET search_path TO bms;
```

### Check 1: Seat Screen Alignment
**Question:** Does every booked seat belong to the exact physical screen where the show is playing?
```sql
SELECT count(*) AS mismatched_screen_seats
FROM booking_seats bs
JOIN shows s ON s.show_id = bs.show_id
JOIN seats se ON se.seat_id = bs.seat_id
WHERE s.screen_id <> se.screen_id;
```
**Actual Output:**
```
 mismatched_screen_seats 
-------------------------
                       0
(1 row)
```
*Result:* **PASSED (0 errors).** Every allocated seat belongs strictly to the auditorium hosting that show.

---

### Check 2: Ticket Quantity Consistency
**Question:** Does `bookings.num_tickets` match the exact count of seat rows allocated in `booking_seats` for active bookings?
```sql
SELECT count(*) AS mismatched_ticket_counts
FROM bookings b
LEFT JOIN (
    SELECT booking_id, count(*) AS actual_seats
    FROM booking_seats
    GROUP BY booking_id
) bs ON bs.booking_id = b.booking_id
WHERE b.status IN ('CONFIRMED', 'PENDING')
  AND b.num_tickets <> COALESCE(bs.actual_seats, 0);
```
**Actual Output:**
```
 mismatched_ticket_counts 
--------------------------
                        0
(1 row)
```
*Result:* **PASSED (0 errors).** Exact 1-to-1 correspondence between tickets purchased and physical seats reserved.

---

### Check 3: Released Seats on Cancelled Bookings
**Question:** Do cancelled or payment-failed bookings hold any physical seats?
```sql
SELECT count(*) AS orphaned_cancelled_seats
FROM bookings b
JOIN booking_seats bs ON bs.booking_id = b.booking_id
WHERE b.status IN ('CANCELLED', 'PAYMENT_FAILED');
```
**Actual Output:**
```
 orphaned_cancelled_seats 
--------------------------
                        0
(1 row)
```
*Result:* **PASSED (0 errors).** All 300,389 allocated seat rows belong strictly to `CONFIRMED` or `PENDING` bookings.

---

### Check 4: Screen Capacity Verification
**Question:** Does `screens.total_seats` match the actual count of rows in the `seats` table for each screen?
```sql
SELECT count(*) AS screen_seat_discrepancies
FROM screens sc
JOIN (
    SELECT screen_id, count(*) AS seat_count
    FROM seats
    GROUP BY screen_id
) s ON s.screen_id = sc.screen_id
WHERE sc.total_seats <> s.seat_count;
```
**Actual Output:**
```
 screen_seat_discrepancies 
---------------------------
                         0
(1 row)
```
*Result:* **PASSED (0 errors).** Stored capacity matches physical layout across all 490 auditoriums.

---

### Check 5: Billing Math Verification
**Question:** Does `total_amount = ticket_amount + convenience_fee + fnb_amount - discount` hold across all bookings?
```sql
SELECT count(*) AS bad_total_amounts
FROM bookings
WHERE total_amount <> (ticket_amount + convenience_fee + fnb_amount - discount);
```
**Actual Output:**
```
 bad_total_amounts 
-------------------
                 0
(1 row)
```
*Result:* **PASSED (0 errors).** 100% accounting accuracy across all 150,094 transactions.

---

## 5. Data Problems & Real-World Nuances

During the inspection of the seed CSV exports, the following genuine data nuances were identified:

1. **Nullable `offer_code` in `bookings.csv` (127,659 NULLs):**
   - Out of 150,094 bookings, **127,659 records (85.1%)** have an empty `offer_code` because the customer did not apply a promotional discount voucher.
   - *Real-world impact:* In workload query `R13` (`offers that have never been redeemed`), the query uses `WHERE offer_code NOT IN (SELECT offer_code FROM bookings)`. Because SQL uses three-valued logic (`TRUE`, `FALSE`, `UNKNOWN`), any subquery containing `NULL` causes `NOT IN` to evaluate to `UNKNOWN`, returning **0 rows** (empty report). In Phase 4, this is corrected using `NOT EXISTS` or filtering `WHERE offer_code IS NOT NULL`.

2. **Nullable `review_text` in `movie_reviews.csv` (16,162 NULLs):**
   - Out of 32,510 review rows, **16,162 records (49.7%)** have an empty `review_text`.
   - *Reason:* Customers frequently submit quick 1–10 star ratings without writing textual commentary. Therefore, `review_text` must be nullable in the schema, while `rating` must remain strictly `NOT NULL`.

3. **Atomic Double-Booking Invariant:**
   - In `booking_seats`, multiple seats belong to the same booking. If two concurrent users try to book the same physical seat for the same show, their `booking_id`s will differ.
   - *Solution:* Adding `CONSTRAINT uq_booking_seats_show_seat UNIQUE (show_id, seat_id)` guarantees at the database level that no seat can be booked twice for the same show, and directly powers the `ON CONFLICT (show_id, seat_id) DO NOTHING` clause in workload query `W02`.
