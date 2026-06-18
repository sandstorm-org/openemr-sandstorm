-- Sandstorm 線上預約使用的 calendar category migration。
-- OpenEMR 的 pc_constant_id 有 unique key，搭配 INSERT IGNORE 可重複執行而不產生重複類別。
INSERT IGNORE INTO openemr_postcalendar_categories
  (pc_constant_id, pc_catname, pc_catcolor, pc_catdesc, pc_recurrtype,
   pc_enddate, pc_recurrspec, pc_recurrfreq, pc_duration,
   pc_end_date_flag, pc_end_date_type, pc_end_date_freq, pc_end_all_day,
   pc_dailylimit, pc_cattype, pc_active, pc_seq, aco_spec)
VALUES
  ('sandstorm_online_booking',
   'Online Booking',
   '#ff0000',
   'Appointment booked from Sandstorm appointment wizard',
   0,
   NULL,
   'a:5:{s:17:"event_repeat_freq";s:1:"0";s:22:"event_repeat_freq_type";s:1:"0";s:19:"event_repeat_on_num";s:1:"1";s:19:"event_repeat_on_day";s:1:"0";s:20:"event_repeat_on_freq";s:1:"0";}',
   0,
   1800,
   0,
   0,
   0,
   0,
   0,
   0,
   1,
   100,
   'encounters|notes');
