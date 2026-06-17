-- ============================================================
-- seed_test_schedules.sql
-- Insert test doctors and their weekly schedules into OpenEMR.
--
-- Key insight: OpenEMR's getAvailableSlots() works by finding
-- GAPS between consecutive events. Without an "End of Day" marker,
-- it cannot calculate afternoon slots after Lunch.
--
-- Fix: add a zero-duration "End of Day" marker (catid=8) at the
-- end of each provider's working hours so the algorithm knows
-- where to stop generating slots.
--
-- Doctors:
--   Doctor A (id=101): InOffice Mon-Fri 09-17, OutOfOffice Mon 14-16
--   Doctor L (id=102): InOffice Mon/Tue/Thu 09-17, EstPt Thu 10-11
--   Doctor K (id=103): InOffice Wed/Thu/Fri 09-15
--   Lunch (catid=8): 12-13 for all doctors on working days
--
-- Usage (inside Sandstorm grain):
--   mysql -u openemr -popenemr openemr < /opt/app/sql/seed_test_schedules.sql
-- ============================================================

USE openemr;

-- ── Step 1: Insert Doctor users ──────────────────────────────
INSERT IGNORE INTO users (id, username, fname, lname, specialty, active, authorized, facility_id, calendar)
VALUES
  (101, 'doctor_a', 'Aliman', 'Ali', 'General Practice', 1, 1, 1, 1),
  (102, 'doctor_g', 'Gulniza', 'Gu', 'Internal Medicine', 1, 1, 1, 1),
  (103, 'doctor_s', 'Soyun', 'Lee', 'Pediatrics', 1, 1, 1, 1),
  (104, 'doctor_k', 'Konrad', 'Kon', 'General Practice', 1, 1, 1, 1),
  (105, 'doctor_a', 'Arnaud', 'Da', 'General Practice', 1, 1, 1, 1);

-- ── Step 2: Clean up previous seed data ──────────────────────
DELETE FROM openemr_postcalendar_events WHERE pc_aid IN (101, 102, 103, 104, 105);

-- ── Step 3: Generate schedules via stored procedure ──────────
DROP PROCEDURE IF EXISTS seed_schedules;

DELIMITER //

CREATE PROCEDURE seed_schedules()
BEGIN
    DECLARE v_date DATE;
    DECLARE v_end_date DATE;
    DECLARE v_dow INT;

    -- Generate for the month of May 2026
    SET v_date = '2026-05-17';
    SET v_end_date = '2026-06-13';

    WHILE v_date <= v_end_date DO
        -- Convert MySQL DAYOFWEEK (1=Sun) to ISO (1=Mon..7=Sun)
        SET v_dow = IF(DAYOFWEEK(v_date) = 1, 7, DAYOFWEEK(v_date) - 1);

        -- ── DOCTOR A (id=101): Mon-Fri, 09:00-17:00 ────────────
        IF v_dow BETWEEN 1 AND 5 THEN

            -- Lunch 12:00-13:00
            INSERT INTO openemr_postcalendar_events
                (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                 pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
            VALUES (8, 101, 0, 'Lunch', v_date, v_date,
                    '12:00:00', '13:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);

            -- Monday only: In Office 09:00-10:00
            IF v_dow = 1 THEN
                INSERT INTO openemr_postcalendar_events
                    (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                     pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                VALUES (2, 101, 0, 'In Office', v_date, v_date,
                        '09:00:00', '10:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);
            END IF;

            -- Tuesday only: Meeting 13:00-14:00
            IF v_dow = 2 THEN
                INSERT INTO openemr_postcalendar_events
                    (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                     pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                VALUES (4, 101, 0, 'Meeting', v_date, v_date,
                        '13:00:00', '14:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);
            END IF;

            -- Wednesday only: Out Of Office 09:00-10:30
            IF v_dow = 3 THEN
                INSERT INTO openemr_postcalendar_events
                    (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                     pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                VALUES (3, 101, 0, 'Out Of Office', v_date, v_date,
                        '09:00:00', '10:30:00', 5400, 0, '-', 1, 0, 0, NOW(), 1);
            END IF;

            -- Thursday only: Meeting 14:00-17:00
            IF v_dow = 4 THEN
                INSERT INTO openemr_postcalendar_events
                    (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                     pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                VALUES (4, 101, 0, 'Meeting', v_date, v_date,
                        '14:00:00', '17:00:00', 10800, 0, '-', 1, 0, 0, NOW(), 1);
            END IF;

            -- Random Fixed Patient appointments (Avoid lunch/meetings/OOO)
            IF MOD(DAY(v_date), 2) = 0 THEN
                IF v_dow = 3 THEN
                    INSERT INTO openemr_postcalendar_events
                        (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                         pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                    VALUES (9, 101, 1, 'Established Patient', v_date, v_date,
                            '14:00:00', '15:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);
                ELSE
                    INSERT INTO openemr_postcalendar_events
                        (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                         pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                    VALUES (9, 101, 1, 'Established Patient', v_date, v_date,
                            '10:00:00', '11:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);
                END IF;
            END IF;

            IF MOD(DAY(v_date), 3) = 1 THEN
                IF v_dow = 4 THEN
                    INSERT INTO openemr_postcalendar_events
                        (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                         pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                    VALUES (9, 101, 2, 'Established Patient', v_date, v_date,
                            '10:00:00', '11:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);
                ELSEIF v_dow != 2 THEN
                    INSERT INTO openemr_postcalendar_events
                        (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                         pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                    VALUES (9, 101, 2, 'Established Patient', v_date, v_date,
                            '15:00:00', '16:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);
                END IF;
            END IF;
        END IF;

        -- ── DOCTOR L (id=102): Mon, Tue, Thu, 09:00-17:00 ─────
        IF v_dow IN (1, 2, 4) THEN

            -- Lunch 12:00-13:00
            INSERT INTO openemr_postcalendar_events
                (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                 pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
            VALUES (8, 102, 0, 'Lunch', v_date, v_date,
                    '12:00:00', '13:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);

            -- Tuesday only: Meeting 13:00-14:00
            IF v_dow = 2 THEN
                INSERT INTO openemr_postcalendar_events
                    (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                     pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                VALUES (4, 102, 0, 'Meeting', v_date, v_date,
                        '13:00:00', '14:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);
            END IF;

            -- Random Fixed Patient appointments
            IF MOD(DAY(v_date), 2) = 0 THEN
                INSERT INTO openemr_postcalendar_events
                    (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                     pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                VALUES (9, 102, 3, 'Established Patient', v_date, v_date,
                        '14:00:00', '15:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);
            END IF;

            IF MOD(DAY(v_date), 3) = 1 THEN
                INSERT INTO openemr_postcalendar_events
                    (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                     pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                VALUES (9, 102, 4, 'Established Patient', v_date, v_date,
                        '10:00:00', '11:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);
            END IF;
        ELSEIF v_dow IN (3, 5) THEN
            -- Out Of Office 09:00-17:00 (Not working days)
            INSERT INTO openemr_postcalendar_events
                (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                 pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
            VALUES (3, 102, 0, 'Out Of Office', v_date, v_date,
                    '09:00:00', '17:00:00', 28800, 0, '-', 1, 0, 0, NOW(), 1);
        END IF;

        -- ── DOCTOR K (id=103): Wed, Thu, Fri, 09:00-12:00 ─────
        IF v_dow IN (3, 4, 5) THEN

            -- Out Of Office 12:00-17:00 (Not working in the afternoon)
            INSERT INTO openemr_postcalendar_events
                (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                 pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
            VALUES (3, 103, 0, 'Out Of Office', v_date, v_date,
                    '12:00:00', '17:00:00', 18000, 0, '-', 1, 0, 0, NOW(), 1);

            -- Random Fixed Patient appointments
            IF MOD(DAY(v_date), 2) = 0 THEN
                INSERT INTO openemr_postcalendar_events
                    (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                     pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                VALUES (9, 103, 5, 'Established Patient', v_date, v_date,
                        '10:00:00', '11:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);
            END IF;

            IF MOD(DAY(v_date), 3) = 1 THEN
                INSERT INTO openemr_postcalendar_events
                    (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                     pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
                VALUES (9, 103, 6, 'Established Patient', v_date, v_date,
                        '11:00:00', '12:00:00', 3600, 0, '-', 1, 0, 0, NOW(), 1);
            END IF;
        ELSEIF v_dow IN (1, 2) THEN
            -- Out Of Office 09:00-17:00 (Not working days)
            INSERT INTO openemr_postcalendar_events
                (pc_catid, pc_aid, pc_pid, pc_title, pc_eventDate, pc_endDate,
                 pc_startTime, pc_endTime, pc_duration, pc_recurrtype, pc_apptstatus, pc_facility, pc_multiple, pc_alldayevent, pc_time, pc_informant)
            VALUES (3, 103, 0, 'Out Of Office', v_date, v_date,
                    '09:00:00', '17:00:00', 28800, 0, '-', 1, 0, 0, NOW(), 1);
        END IF;

        SET v_date = DATE_ADD(v_date, INTERVAL 1 DAY);
    END WHILE;
END //

DELIMITER ;

CALL seed_schedules();
DROP PROCEDURE IF EXISTS seed_schedules;

-- ── Verification ─────────────────────────────────────────────
SELECT
    e.pc_eventDate AS date,
    u.fname AS doctor,
    c.pc_catname AS category,
    e.pc_startTime AS start,
    e.pc_endTime AS end
FROM openemr_postcalendar_events AS e
JOIN users AS u ON u.id = e.pc_aid
JOIN openemr_postcalendar_categories AS c ON c.pc_catid = e.pc_catid
WHERE e.pc_aid IN (101, 102, 103)
ORDER BY e.pc_eventDate, u.fname, e.pc_startTime
LIMIT 80;
