<?php
/**
 * OpenEMR Sandstorm - Confirm Appointment API
 *
 * Creates a calendar-only appointment booked by the Sandstorm appointment
 * wizard. Sandstorm API token auth is enforced by the grain HTTP API layer.
 */

// Sandstorm HTTP API token 已在 grain 外層處理權限；這支 endpoint 不走 OpenEMR UI session。
$ignoreAuth = true;

require_once(dirname(__FILE__) . '/../interface/globals.php');

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

const ONLINE_BOOKING_CATEGORY_ID = 'sandstorm_online_booking';
const ONLINE_BOOKING_CATEGORY_NAME = 'Online Booking';
const ONLINE_BOOKING_CATEGORY_COLOR = '#ff0000';
const ONLINE_BOOKING_CATEGORY_DESC = 'Appointment booked from Sandstorm appointment wizard';
const NO_REPEAT_RECURRSPEC = 'a:5:{s:17:"event_repeat_freq";s:1:"0";s:22:"event_repeat_freq_type";s:1:"0";s:19:"event_repeat_on_num";s:1:"1";s:19:"event_repeat_on_day";s:1:"0";s:20:"event_repeat_on_freq";s:1:"0";}';

function json_response(int $statusCode, array $payload): void
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

function json_error(int $statusCode, string $code, string $message): void
{
    json_response($statusCode, [
        'status' => 'error',
        'code' => $code,
        'message' => $message,
    ]);
}

function parse_json_body(): array
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        json_error(405, 'method_not_allowed', 'Only POST is supported.');
    }

    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    if ($contentType !== '' && stripos($contentType, 'application/json') === false) {
        json_error(415, 'unsupported_media_type', 'Content-Type must be application/json.');
    }

    $rawBody = file_get_contents('php://input');
    $body = json_decode($rawBody, true);
    if (!is_array($body) || json_last_error() !== JSON_ERROR_NONE) {
        json_error(400, 'invalid_json', 'Request body must be valid JSON.');
    }

    return $body;
}

function is_valid_date_string(string $value): bool
{
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $value)) {
        return false;
    }

    $date = DateTimeImmutable::createFromFormat('!Y-m-d', $value);
    return $date !== false && $date->format('Y-m-d') === $value;
}

function is_valid_time_string(string $value): bool
{
    if (!preg_match('/^\d{2}:\d{2}:\d{2}$/', $value)) {
        return false;
    }

    $time = DateTimeImmutable::createFromFormat('!H:i:s', $value);
    return $time !== false && $time->format('H:i:s') === $value;
}

function clean_text($value, string $field, int $maxLength): string
{
    if (!is_string($value)) {
        json_error(400, 'invalid_body', $field . ' must be a string.');
    }

    $cleaned = trim(strip_tags($value));
    $cleaned = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/', '', $cleaned);
    if ($cleaned === '') {
        json_error(400, 'invalid_body', $field . ' is required.');
    }

    if (function_exists('mb_strlen') && function_exists('mb_substr')) {
        if (mb_strlen($cleaned, 'UTF-8') > $maxLength) {
            $cleaned = mb_substr($cleaned, 0, $maxLength, 'UTF-8');
        }
    } elseif (strlen($cleaned) > $maxLength) {
        $cleaned = substr($cleaned, 0, $maxLength);
    }

    return $cleaned;
}

function validate_request(array $body): array
{
    // Gateway 只傳 calendar-only confirmation 需要的資料；v1 不建立 patient_data，
    // 因此這裡嚴格檢查 slot 與可人工閱讀的 appointmentInformation。
    if (!isset($body['slot']) || !is_array($body['slot'])) {
        json_error(400, 'invalid_body', 'slot is required.');
    }
    if (!isset($body['appointmentInformation']) || !is_array($body['appointmentInformation'])) {
        json_error(400, 'invalid_body', 'appointmentInformation is required.');
    }
    if (!isset($body['preferences']) || !is_array($body['preferences'])) {
        json_error(400, 'invalid_body', 'preferences is required.');
    }

    $slot = $body['slot'];
    $info = $body['appointmentInformation'];
    $preferences = $body['preferences'];

    $date = isset($slot['date']) && is_string($slot['date']) ? $slot['date'] : '';
    $startTime = isset($slot['startTime']) && is_string($slot['startTime']) ? $slot['startTime'] : '';
    $endTime = isset($slot['endTime']) && is_string($slot['endTime']) ? $slot['endTime'] : '';
    if (!is_valid_date_string($date)) {
        json_error(400, 'invalid_slot', 'slot.date must use YYYY-MM-DD.');
    }
    if (!is_valid_time_string($startTime) || !is_valid_time_string($endTime)) {
        json_error(400, 'invalid_slot', 'slot.startTime and slot.endTime must use HH:MM:SS.');
    }

    $duration = filter_var($slot['duration'] ?? null, FILTER_VALIDATE_INT);
    if ($duration === false || $duration <= 0) {
        json_error(400, 'invalid_slot', 'slot.duration must be a positive integer number of minutes.');
    }

    $providerId = filter_var($slot['providerId'] ?? null, FILTER_VALIDATE_INT);
    if ($providerId === false || $providerId <= 0) {
        json_error(400, 'invalid_slot', 'slot.providerId must be a positive integer.');
    }

    $start = strtotime('1970-01-01 ' . $startTime);
    $end = strtotime('1970-01-01 ' . $endTime);
    if ($start === false || $end === false || $end <= $start) {
        json_error(400, 'invalid_slot', 'slot.endTime must be after slot.startTime.');
    }
    if (($end - $start) !== $duration * 60) {
        json_error(400, 'invalid_slot', 'slot.duration must match slot start and end times.');
    }

    if (!isset($info['person']) || !is_array($info['person'])) {
        json_error(400, 'invalid_body', 'appointmentInformation.person is required.');
    }
    $person = $info['person'];
    $firstName = clean_text($person['firstName'] ?? null, 'person.firstName', 100);
    $lastName = clean_text($person['lastName'] ?? null, 'person.lastName', 100);
    $dateOfBirth = isset($person['dateOfBirth']) && is_string($person['dateOfBirth']) ? $person['dateOfBirth'] : '';
    if (!is_valid_date_string($dateOfBirth)) {
        json_error(400, 'invalid_body', 'person.dateOfBirth must use YYYY-MM-DD.');
    }
    $reason = clean_text($info['reasonForAppointment'] ?? null, 'appointmentInformation.reasonForAppointment', 2000);

    $languages = [];
    if (!isset($preferences['languages']) || !is_array($preferences['languages'])) {
        json_error(400, 'invalid_body', 'preferences.languages must be an array.');
    }
    foreach ($preferences['languages'] as $language) {
        if (!is_string($language)) {
            json_error(400, 'invalid_body', 'preferences.languages must contain only strings.');
        }
        $languages[] = clean_text($language, 'preferences.languages', 50);
    }

    $doctorGender = clean_text($preferences['doctorGender'] ?? 'any', 'preferences.doctorGender', 20);

    return [
        'slot' => [
            'date' => $date,
            'startTime' => $startTime,
            'endTime' => $endTime,
            'duration' => $duration,
            'providerId' => $providerId,
        ],
        'appointmentInformation' => [
            'person' => [
                'firstName' => $firstName,
                'lastName' => $lastName,
                'dateOfBirth' => $dateOfBirth,
            ],
            'reasonForAppointment' => $reason,
        ],
        'preferences' => [
            'languages' => $languages,
            'doctorGender' => $doctorGender,
        ],
    ];
}

function ensure_online_booking_category(): int
{
    // category migration 會在 grain 啟動時先跑一次；endpoint 仍做 lazy ensure，
    // 讓舊 grain 或手動部署漏跑 migration 時也能安全補上。
    $existing = sqlQuery(
        "SELECT pc_catid FROM openemr_postcalendar_categories WHERE pc_constant_id = ? LIMIT 1",
        [ONLINE_BOOKING_CATEGORY_ID]
    );
    if ($existing && isset($existing['pc_catid'])) {
        return (int)$existing['pc_catid'];
    }

    sqlStatement(
        "INSERT IGNORE INTO openemr_postcalendar_categories
            (pc_constant_id, pc_catname, pc_catcolor, pc_catdesc, pc_recurrtype,
             pc_enddate, pc_recurrspec, pc_recurrfreq, pc_duration,
             pc_end_date_flag, pc_end_date_type, pc_end_date_freq, pc_end_all_day,
             pc_dailylimit, pc_cattype, pc_active, pc_seq, aco_spec)
         VALUES (?, ?, ?, ?, 0, NULL, ?, 0, 1800, 0, 0, 0, 0, 0, 0, 1, 100, 'encounters|notes')",
        [
            ONLINE_BOOKING_CATEGORY_ID,
            ONLINE_BOOKING_CATEGORY_NAME,
            ONLINE_BOOKING_CATEGORY_COLOR,
            ONLINE_BOOKING_CATEGORY_DESC,
            NO_REPEAT_RECURRSPEC,
        ]
    );

    $created = sqlQuery(
        "SELECT pc_catid FROM openemr_postcalendar_categories WHERE pc_constant_id = ? LIMIT 1",
        [ONLINE_BOOKING_CATEGORY_ID]
    );
    if (!$created || !isset($created['pc_catid'])) {
        throw new RuntimeException('Unable to create online booking calendar category.');
    }

    return (int)$created['pc_catid'];
}

function build_home_text(array $appointmentInformation, array $preferences, string $appointmentReference): string
{
    // v1 calendar-only：不連到 patient_data，PHI 以可人工閱讀摘要放在 pc_hometext。
    $person = $appointmentInformation['person'];
    $languages = count($preferences['languages']) > 0 ? implode(', ', $preferences['languages']) : 'none';

    return implode("\n", [
        '[' . $appointmentReference . '] ',
        'Patient: ' . $person['firstName'] . ' ' . $person['lastName'] . '; ',
        'Date of birth: ' . $person['dateOfBirth'] . '; ',
        'Preferences: languages=' . $languages . '; doctorGender=' . $preferences['doctorGender'] . '; ',
        'Reason: ' . $appointmentInformation['reasonForAppointment'],
    ]);
}

$lockName = null;
$lockAcquired = false;

try {
    $request = validate_request(parse_json_body());
    $slot = $request['slot'];

    $provider = sqlQuery(
        "SELECT id, fname, lname, facility_id
           FROM users
          WHERE id = ? AND authorized = 1 AND active = 1 AND calendar = 1
          LIMIT 1",
        [$slot['providerId']]
    );
    if (!$provider) {
        json_error(404, 'provider_not_found', 'Provider was not found or is not bookable.');
    }

    $catId = ensure_online_booking_category();
    $facilityId = (int)($provider['facility_id'] ?? 0);
    if ($facilityId <= 0) {
        $facilityId = 1;
    }

    $lockName = 'sandstorm_booking:' . $slot['providerId'] . ':' . $slot['date'];
    // 同一位醫師同一天序列化確認流程，避免兩個 gateway request 同時通過 overlap check。
    $lock = sqlQuery("SELECT GET_LOCK(?, 5) AS acquired", [$lockName]);
    if (!$lock || (int)$lock['acquired'] !== 1) {
        json_error(503, 'lock_timeout', 'Unable to lock provider calendar for booking.');
    }
    $lockAcquired = true;

    $conflict = sqlQuery(
        // 與 availability API 使用同一個非零 duration overlap 規則：
        // slotStart < eventEnd && slotEnd > eventStart，即視為衝突。
        "SELECT pc_eid
           FROM openemr_postcalendar_events
          WHERE pc_aid = ?
            AND pc_eventDate = ?
            AND pc_startTime <> pc_endTime
            AND pc_startTime < ?
            AND pc_endTime > ?
          LIMIT 1",
        [
            $slot['providerId'],
            $slot['date'],
            $slot['endTime'],
            $slot['startTime'],
        ]
    );

    if ($conflict) {
        sqlStatement("DO RELEASE_LOCK(?)", [$lockName]);
        $lockAcquired = false;
        json_error(409, 'slot_unavailable', 'This appointment slot is no longer available.');
    }

    $initialHomeText = build_home_text(
        $request['appointmentInformation'],
        $request['preferences'],
        'pending'
    );
    $eventId = sqlInsert(
        // 直接寫入 OpenEMR calendar event。pc_pid=0 代表 v1 不建立或匹配 patient。
        "INSERT INTO openemr_postcalendar_events
            (pc_catid, pc_multiple, pc_aid, pc_pid, pc_gid, pc_title, pc_time,
             pc_hometext, pc_comments, pc_informant, pc_eventDate, pc_endDate,
             pc_duration, pc_recurrtype, pc_recurrspec, pc_recurrfreq,
             pc_startTime, pc_endTime, pc_alldayevent, pc_apptstatus,
             pc_prefcatid, pc_eventstatus, pc_sharing, pc_facility,
             pc_billing_location, pc_room)
         VALUES
            (?, 0, ?, 0, 0, ?, NOW(),
             ?, 0, 1, ?, ?,
             ?, 0, ?, 0,
             ?, ?, 0, '-',
             0, 1, 1, ?,
             ?, '')",
        [
            $catId,
            $slot['providerId'],
            ONLINE_BOOKING_CATEGORY_NAME,
            $initialHomeText,
            $slot['date'],
            $slot['date'],
            $slot['duration'] * 60,
            NO_REPEAT_RECURRSPEC,
            $slot['startTime'],
            $slot['endTime'],
            $facilityId,
            $facilityId,
        ]
    );

    if (!$eventId) {
        throw new RuntimeException('Unable to create appointment event.');
    }

    $appointmentReference = 'OE-' . (int)$eventId;
    $homeText = build_home_text(
        $request['appointmentInformation'],
        $request['preferences'],
        $appointmentReference
    );
    sqlStatement(
        "UPDATE openemr_postcalendar_events SET pc_hometext = ? WHERE pc_eid = ?",
        [$homeText, $eventId]
    );

    sqlStatement("DO RELEASE_LOCK(?)", [$lockName]);
    $lockAcquired = false;

    json_response(200, [
        'status' => 'success',
        'data' => [
            'eventId' => (int)$eventId,
            'appointmentReference' => $appointmentReference,
        ],
    ]);
} catch (Throwable $e) {
    if ($lockAcquired && $lockName !== null) {
        sqlStatement("DO RELEASE_LOCK(?)", [$lockName]);
    }

    json_error(500, 'internal_error', 'Unable to confirm appointment.');
}
