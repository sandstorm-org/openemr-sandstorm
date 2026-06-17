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
    // ── 1. Fetch active providers ──
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

    // ── 2. Generate default 09:00-17:00 working hours on weekdays ──
    $working_hours = [];
    $current = new DateTime($from_date);
    $end     = new DateTime($to_date);
    
    while ($current <= $end) {
        $dateStr = $current->format('Y-m-d');
        $dayOfWeek = (int)$current->format('N'); // 1=Mon, 7=Sun
        
        if ($dayOfWeek <= 5) { // Weekdays only
            foreach ($providerList as $prov) {
                $working_hours[$dateStr][$prov['id']][] = [
                    'start' => '09:00:00',
                    'end'   => '12:00:00',
                    'providerName' => trim($prov['firstName'] . ' ' . $prov['lastName'])
                ];
                $working_hours[$dateStr][$prov['id']][] = [
                    'start' => '13:00:00',
                    'end'   => '17:00:00',
                    'providerName' => trim($prov['firstName'] . ' ' . $prov['lastName'])
                ];
            }
        }
        $current->modify('+1 day');
    }

    // ── 3. Fetch all events and mark them as busy ──
    $allEvents = fetchAllEvents($from_date, $to_date);
    $slotSizeSeconds = 1800; // 30 minutes
    
    $busy_periods = [];
    foreach ($allEvents as $event) {
        $date = $event['pc_eventDate'];
        $provId = $event['uprovider_id'] ?? 0;
        
        // Filter by requested provider if any
        if ($provider !== null && $provId != $provider) {
            continue;
        }

        // Exclude all events with non-zero duration as busy
        if ($event['pc_startTime'] !== $event['pc_endTime']) {
            $busy_periods[$date][$provId][] = [
                'start' => $event['pc_startTime'],
                'end'   => $event['pc_endTime']
            ];
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

    // ── 4. Fetch existing appointments/events ──
    $events = $allEvents;

    $response = [
        "status"  => "success",
        "request" => [
            "from_date" => $from_date,
            "to_date"   => $to_date,
            "provider"  => $provider,
        ],
        "data" => [
            "slots"      => $slots,
            "providers"  => $providerList,
            "events"     => $events,
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
