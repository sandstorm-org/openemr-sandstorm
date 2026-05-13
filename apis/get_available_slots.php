<?php
/**
 * OpenEMR Sandstorm - Available Slots API
 *
 * Returns available appointment time slots in JSON format.
 * Designed to be called via Sandstorm HTTP API with Bearer Token auth.
 *
 * Query parameters:
 *   from     - Start date (YYYY-MM-DD), default: today
 *   to       - End date (YYYY-MM-DD), default: today + 7 days
 *   provider - Provider ID filter (optional)
 *
 * @package OpenEMR
 * @subpackage API
 */

// Skip OpenEMR authentication — Sandstorm handles auth via API Token
$ignoreAuth = true;

// Load OpenEMR core
require_once(dirname(__FILE__) . '/../interface/globals.php');
require_once("$srcdir/appointments.inc.php");

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

// Parse query parameters
$from_date = isset($_GET['from']) ? $_GET['from'] : date('Y-m-d');
$to_date   = isset($_GET['to'])   ? $_GET['to']   : date('Y-m-d', strtotime('+7 days'));
$provider  = isset($_GET['provider']) ? (int)$_GET['provider'] : null;

try {
    // ── 1. Fetch available slots using custom interval math logic ──
    $allEvents = fetchAllEvents($from_date, $to_date);
    $slotSizeSeconds = function_exists('getSlotSize') ? getSlotSize() : 900;
    
    $working_hours = [];
    $busy_periods = [];
    
    // Group events by date -> provider -> category
    foreach ($allEvents as $event) {
        $date = $event['pc_eventDate'];
        $provId = $event['uprovider_id'] ?? 0;
        
        // Filter by requested provider if any
        if ($provider !== null && $provId != $provider) {
            continue;
        }

        if ($event['pc_catid'] == 2) {
            // In Office (catid=2) defines working hour bounds
            $working_hours[$date][$provId][] = [
                'start' => $event['pc_startTime'],
                'end'   => $event['pc_endTime'],
                'providerName' => trim(($event['ufname'] ?? '') . (!empty($event['umname']) ? ' ' . $event['umname'] : '') . ' ' . ($event['ulname'] ?? ''))
            ];
        } else {
            // Everything else is considered busy (Lunch, OOO, appointments)
            if ($event['pc_startTime'] !== $event['pc_endTime']) {
                $busy_periods[$date][$provId][] = [
                    'start' => $event['pc_startTime'],
                    'end'   => $event['pc_endTime']
                ];
            }
        }
    }
    
    $slots = [];
    foreach ($working_hours as $date => $providers) {
        foreach ($providers as $provId => $works) {
            $prov_busys = $busy_periods[$date][$provId] ?? [];
            foreach ($works as $work) {
                $curr_ts = strtotime($date . ' ' . $work['start']);
                $end_ts = strtotime($date . ' ' . $work['end']);
                
                while ($curr_ts + $slotSizeSeconds <= $end_ts) {
                    $slot_start_ts = $curr_ts;
                    $slot_end_ts = $curr_ts + $slotSizeSeconds;
                    $is_busy = false;
                    
                    // Check for overlap with any busy period
                    foreach ($prov_busys as $busy) {
                        $busy_start_ts = strtotime($date . ' ' . $busy['start']);
                        $busy_end_ts = strtotime($date . ' ' . $busy['end']);
                        
                        // Strict overlap: slot starts before busy ends AND slot ends after busy starts
                        if ($slot_start_ts < $busy_end_ts && $slot_end_ts > $busy_start_ts) {
                            $is_busy = true;
                            break;
                        }
                    }
                    
                    if (!$is_busy) {
                        $slots[] = [
                            'date'         => $date,
                            'startTime'    => date('H:i:s', $slot_start_ts),
                            'endTime'      => date('H:i:s', $slot_end_ts),
                            'duration'     => (int) round($slotSizeSeconds / 60),
                            'providerId'   => (int) $provId,
                            'providerName' => $work['providerName'],
                            'status'       => 'available',
                        ];
                    }
                    $curr_ts += $slotSizeSeconds;
                }
            }
        }
    }

    // Sort final slots by date, provider, and time
    usort($slots, function ($a, $b) {
        if ($a['date'] !== $b['date']) return strcmp($a['date'], $b['date']);
        if ($a['providerId'] !== $b['providerId']) return $a['providerId'] <=> $b['providerId'];
        return strcmp($a['startTime'], $b['startTime']);
    });

    // ── 2. Fetch active providers ──
    $providerSql = "SELECT id, fname, lname, specialty FROM users WHERE authorized = 1 AND active = 1";
    $providerParams = [];
    if ($provider !== null) {
        $providerSql .= " AND id = ?";
        $providerParams[] = $provider;
    }
    $providerResult = sqlStatement($providerSql, $providerParams);
    $providerList = [];
    while ($row = sqlFetchArray($providerResult)) {
        $providerList[] = [
            'id'        => (int)$row['id'],
            'firstName' => $row['fname'],
            'lastName'  => $row['lname'],
            'specialty' => $row['specialty'],
        ];
    }

    // ── 3. Fetch existing appointments/events ──
    $events = fetchAllEvents($from_date, $to_date);

    // ── 4. Generate mock available slots if real data is empty ──
    // (Temporary: until real provider schedules are configured in OpenEMR)
    $mockSlots = [];
    if (empty($slots) && empty($events)) {
        $mockSlots = generateMockSlots($from_date, $to_date, $providerList);
    }

    $response = [
        "status"  => "success",
        "request" => [
            "from_date" => $from_date,
            "to_date"   => $to_date,
            "provider"  => $provider,
        ],
        "data" => [
            "slots"      => !empty($slots) ? $slots : $mockSlots,
            "providers"  => $providerList,
            "events"     => $events,
            "isMockData" => empty($slots) && empty($events),
        ],
    ];
} catch (Exception $e) {
    http_response_code(500);
    $response = [
        "status"  => "error",
        "message" => $e->getMessage(),
    ];
}

echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

// ────────────────────────────────────────────────────────────────
// Helper: generate mock available slots for testing purposes
// ────────────────────────────────────────────────────────────────
function generateMockSlots($from_date, $to_date, $providers) {
    $slots = [];
    $slotDurationMinutes = 30;

    // Default mock provider if none exist in the database
    if (empty($providers)) {
        $providers = [
            ['id' => 1, 'firstName' => 'Demo', 'lastName' => 'Doctor', 'specialty' => 'General'],
        ];
    }

    $current = new DateTime($from_date);
    $end     = new DateTime($to_date);

    while ($current <= $end) {
        $dayOfWeek = (int)$current->format('N'); // 1=Mon, 7=Sun

        // Skip weekends
        if ($dayOfWeek >= 6) {
            $current->modify('+1 day');
            continue;
        }

        foreach ($providers as $prov) {
            // Morning slots: 09:00 - 12:00
            $morningStart = 9;
            $morningEnd   = 12;
            for ($hour = $morningStart; $hour < $morningEnd; $hour++) {
                for ($min = 0; $min < 60; $min += $slotDurationMinutes) {
                    $slots[] = [
                        'date'       => $current->format('Y-m-d'),
                        'startTime'  => sprintf('%02d:%02d:00', $hour, $min),
                        'endTime'    => date('H:i:s', mktime($hour, $min + $slotDurationMinutes, 0)),
                        'duration'   => $slotDurationMinutes,
                        'providerId' => $prov['id'],
                        'providerName' => $prov['firstName'] . ' ' . $prov['lastName'],
                        'status'     => 'available',
                    ];
                }
            }

            // Afternoon slots: 14:00 - 17:00
            $afternoonStart = 14;
            $afternoonEnd   = 17;
            for ($hour = $afternoonStart; $hour < $afternoonEnd; $hour++) {
                for ($min = 0; $min < 60; $min += $slotDurationMinutes) {
                    $slots[] = [
                        'date'       => $current->format('Y-m-d'),
                        'startTime'  => sprintf('%02d:%02d:00', $hour, $min),
                        'endTime'    => date('H:i:s', mktime($hour, $min + $slotDurationMinutes, 0)),
                        'duration'   => $slotDurationMinutes,
                        'providerId' => $prov['id'],
                        'providerName' => $prov['firstName'] . ' ' . $prov['lastName'],
                        'status'     => 'available',
                    ];
                }
            }
        }

        $current->modify('+1 day');
    }

    return $slots;
}
