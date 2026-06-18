/**
 * OpenEMR Sandstorm — HTTP API Test Client
 *
 * Tests the `get_available_slots` API endpoint exported via Sandstorm HTTP API.
 *
 * Prerequisites:
 *   1. A running Sandstorm instance with an OpenEMR grain
 *   2. An API token obtained from the Sandstorm UI (key icon in top bar)
 *   3. Node.js >= 18 (for native fetch) or tsx installed
 *
 * Usage:
 *   npx tsx test/api/test_http_api.ts \
 *     --host "https://api-XXXXX.your-sandstorm.example.com" \
 *     --token "YOUR_API_TOKEN"
 *
 * For local development (vagrant-spk dev), you can also use the grain URL directly:
 *   npx tsx test/api/test_http_api.ts \
 *     --host "http://local.sandstorm.io:6090/api/GRAIN_ID" \
 *     --token ""
 *
 * @see https://docs.sandstorm.io/en/latest/developing/http-apis/
 */

// ── CLI Argument Parser ──
function getArg(name: string, defaultValue = ""): string {
  const idx = process.argv.indexOf(name);
  return idx >= 0 && idx + 1 < process.argv.length
    ? process.argv[idx + 1]
    : defaultValue;
}

const API_HOST = getArg("--host", "http://localhost:6090");
const API_TOKEN = getArg("--token", "");
const FROM_DATE = getArg("--from", "2026-05-11");
const TO_DATE = getArg("--to", "2026-05-14");
const RUN_CONFIRM = process.argv.includes("--confirm");
const SKIP_CONFIRM_PROBE = process.argv.includes("--skip-confirm-probe");

// ── Types ──
interface TimeSlot {
  date: string;
  startTime: string;
  endTime: string;
  duration: number;
  providerId: number;
  providerName: string;
  status: string;
}

interface Provider {
  id: number;
  firstName: string;
  lastName: string;
  specialty: string;
}

interface CalendarEvent {
  pc_eventDate: string;
  pc_startTime: string;
  pc_endTime: string;
  pc_title: string;
  pc_catid: number;
  pc_aid: number;
  ufname?: string;
  ulname?: string;
}

interface ApiResponse {
  status: "success" | "error";
  message?: string;
  request?: {
    from_date: string;
    to_date: string;
    provider: number | null;
  };
  data?: {
    slots: TimeSlot[];
    providers: Provider[];
    events: CalendarEvent[];
  };
}

interface ConfirmAppointmentResponse {
  status: "success" | "error";
  code?: string;
  message?: string;
  data?: {
    eventId: number;
    appointmentReference: string;
  };
}

// ── API Client ──
async function getAvailableSlots(
  from: string,
  to: string,
  providerId?: number
): Promise<ApiResponse> {
  let url = `${API_HOST}/apis/get_available_slots.php?from=${from}&to=${to}`;
  if (providerId !== undefined) {
    url += `&provider=${providerId}`;
  }

  const headers: Record<string, string> = {
    Accept: "application/json",
  };
  if (API_TOKEN) {
    headers["Authorization"] = `Bearer ${API_TOKEN}`;
  }

  console.log(`\n📡 GET ${url}`);
  const response = await fetch(url, { headers });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `HTTP ${response.status} ${response.statusText}\n${body.slice(0, 500)}`
    );
  }

  return (await response.json()) as ApiResponse;
}

async function probeConfirmEndpoint(): Promise<void> {
  const url = `${API_HOST}/apis/confirm_appointment.php`;
  const headers: Record<string, string> = {
    Accept: "application/json",
    "Content-Type": "application/json",
  };
  if (API_TOKEN) {
    headers["Authorization"] = `Bearer ${API_TOKEN}`;
  }

  console.log(`\nPOST ${url} (non-mutating endpoint probe)`);
  const response = await fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify({}),
  });
  const body = await response.text();

  if (response.status === 404) {
    throw new Error(
      [
        "confirm_appointment.php is not installed in the OpenEMR grain.",
        "Rebuild or manually sync openemr-sandstorm/apis/confirm_appointment.php into /opt/openemr-7.0.3/openemr/apis/ before packing/uploading.",
        body.slice(0, 500),
      ].join("\n"),
    );
  }

  if (response.status !== 400) {
    throw new Error(
      `Expected confirm endpoint probe to return HTTP 400 for an empty body, got ${response.status} ${response.statusText}\n${body.slice(0, 500)}`,
    );
  }

  const payload = JSON.parse(body) as ConfirmAppointmentResponse;
  if (payload.status !== "error") {
    throw new Error(`Unexpected confirm endpoint probe response: ${body}`);
  }

  console.log("Confirm endpoint is installed and reachable.");
}

function confirmAppointmentBody(slot: TimeSlot) {
  return {
    slot: {
      date: slot.date,
      startTime: slot.startTime,
      endTime: slot.endTime,
      duration: slot.duration,
      providerId: slot.providerId,
    },
    appointmentInformation: {
      person: {
        firstName: "Sandstorm",
        lastName: "Test",
        dateOfBirth: "1990-01-02",
      },
      reasonForAppointment: "HTTP API confirmation test",
    },
    preferences: {
      languages: ["en"],
      doctorGender: "any",
    },
  };
}

async function postConfirmAppointment(slot: TimeSlot): Promise<Response> {
  const url = `${API_HOST}/apis/confirm_appointment.php`;
  const headers: Record<string, string> = {
    Accept: "application/json",
    "Content-Type": "application/json",
  };
  if (API_TOKEN) {
    headers["Authorization"] = `Bearer ${API_TOKEN}`;
  }

  console.log(`\nPOST ${url}`);
  return fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify(confirmAppointmentBody(slot)),
  });
}

async function confirmAppointment(
  slot: TimeSlot,
): Promise<ConfirmAppointmentResponse> {
  const response = await postConfirmAppointment(slot);
  const body = await response.text();
  if (!response.ok) {
    throw new Error(
      `HTTP ${response.status} ${response.statusText}\n${body.slice(0, 500)}`,
    );
  }

  return JSON.parse(body) as ConfirmAppointmentResponse;
}

async function expectConfirmConflict(slot: TimeSlot): Promise<void> {
  const response = await postConfirmAppointment(slot);
  const body = await response.text();
  if (response.status !== 409) {
    throw new Error(
      `Expected duplicate confirmation to return HTTP 409, got ${response.status}\n${body.slice(0, 500)}`,
    );
  }

  const payload = JSON.parse(body) as ConfirmAppointmentResponse;
  if (payload.code !== "slot_unavailable") {
    throw new Error(
      `Expected slot_unavailable conflict code, got ${payload.code}`,
    );
  }

  console.log("Duplicate slot confirmation returned 409 slot_unavailable.");
}

// ── Display Helpers ──
// Formats "HH:MM:SS" → "HH:MM", ignoring seconds.
function fmtTime(t: string): string {
  return t.slice(0, 5);
}

function printSlotTable(slots: TimeSlot[]) {
  if (slots.length === 0) {
    console.log("  (no slots)");
    return;
  }

  // Group by date → provider → sorted times
  const byDate = new Map<string, Map<string, string[]>>();
  for (const slot of slots) {
    if (!byDate.has(slot.date)) {
      byDate.set(slot.date, new Map());
    }
    const byProvider = byDate.get(slot.date)!;
    if (!byProvider.has(slot.providerName)) {
      byProvider.set(slot.providerName, []);
    }
    byProvider.get(slot.providerName)!.push(fmtTime(slot.startTime));
  }

  for (const [date, byProvider] of byDate) {
    console.log(`\n  📅 ${date}`);
    for (const [providerName, times] of byProvider) {
      const unique = [...new Set(times)];
      // Chunk into rows of 8 so no times are lost to terminal-width overflow
      const chunkSize = 8;
      const firstChunk = unique.slice(0, chunkSize);
      console.log(`     👨‍⚕️ ${providerName}: ${firstChunk.join(", ")}`);
      for (let i = chunkSize; i < unique.length; i += chunkSize) {
        const chunk = unique.slice(i, i + chunkSize);
        console.log(`        ${" ".repeat(providerName.length + 2)}${chunk.join(", ")}`);
      }
    }
  }
}

// ── Main ──
async function main() {
  console.log("╔══════════════════════════════════════════════════╗");
  console.log("║  🏥 OpenEMR Sandstorm — HTTP API Test Client    ║");
  console.log("╚══════════════════════════════════════════════════╝");
  console.log(`  Host:  ${API_HOST}`);
  console.log(`  Token: ${API_TOKEN ? "***" + API_TOKEN.slice(-6) : "(none)"}`);
  console.log(`  Range: ${FROM_DATE} → ${TO_DATE}`);

  try {
    if (!SKIP_CONFIRM_PROBE) {
      console.log("\n--- Test 0: Confirm endpoint preflight ---");
      await probeConfirmEndpoint();
    }

    // Test 1: Fetch all available slots
    console.log("\n─── Test 1: Fetch all available slots ───");
    const result = await getAvailableSlots(FROM_DATE, TO_DATE);

    if (result.status !== "success") {
      console.error("❌ API returned error:", result.message);
      process.exit(1);
    }

    const data = result.data!;
    console.log(`\n✅ Response status: ${result.status}`);
    console.log(`   Providers: ${data.providers.length}`);
    console.log(`   Total slots: ${data.slots.length}`);
    console.log(`   Events: ${data.events.length}`);

    // Show providers
    if (data.providers.length > 0) {
      console.log("\n👨‍⚕️ Providers:");
      for (const p of data.providers) {
        console.log(`   [${p.id}] ${p.firstName} ${p.lastName} — ${p.specialty || "N/A"}`);
      }
    }

    // Show slots preview
    console.log("\n🕐 Available Slots Preview:");
    printSlotTable(data.slots);

    // Show events
    if (data.events && data.events.length > 0) {
      console.log("\n📅 Calendar Events:");
      const sortedEvents = [...data.events].sort((a: any, b: any) => {
        // Sort by event date
        if (a.pc_eventDate !== b.pc_eventDate) {
          return a.pc_eventDate.localeCompare(b.pc_eventDate);
        }
        // Sort by doctor name
        const nameA = `${a.ufname ?? ""} ${a.ulname ?? ""}`.trim() || `Provider #${a.pc_aid}`;
        const nameB = `${b.ufname ?? ""} ${b.ulname ?? ""}`.trim() || `Provider #${b.pc_aid}`;
        if (nameA !== nameB) {
          return nameA.localeCompare(nameB);
        }
        // Fallback to start time
        return a.pc_startTime.localeCompare(b.pc_startTime);
      });

      let lastDate = "";
      for (const e of sortedEvents as any) {
        if (lastDate && e.pc_eventDate !== lastDate) {
          console.log("  ──────────────────────────────────────────────────────────────────────────────────");
        }
        lastDate = e.pc_eventDate;

        const docName = e.ufname || e.ulname
          ? `${e.ufname ?? ""} ${e.ulname ?? ""}`.trim()
          : `Provider #${e.pc_aid}`;
        console.log(
          `   📅 ${e.pc_eventDate} | 🕐 ${fmtTime(e.pc_startTime)} - ${fmtTime(e.pc_endTime)} | 👨‍⚕️ ${docName} | 🏷️ ${e.pc_title} (Cat: ${e.pc_catid})`
        );
      }
    } else {
      console.log("\n📅 Calendar Events: (none)");
    }

    // Test 2: Fetch with provider filter (if providers exist)
    if (data.providers.length > 0) {
      const firstProvider = data.providers[0];
      console.log(
        `\n─── Test 2: Filter by provider ID=${firstProvider.id} ───`
      );
      const filtered = await getAvailableSlots(
        FROM_DATE,
        TO_DATE,
        firstProvider.id
      );
      if (filtered.status === "success") {
        console.log(
          `✅ Filtered slots: ${filtered.data!.slots.length} (provider: ${firstProvider.firstName} ${firstProvider.lastName})`
        );
      }
    }

    console.log("\n════════════════════════════════════════════");
    console.log("✅ All tests passed!");
  } catch (err) {
    console.error("\n❌ Error:", err);
    process.exit(1);
  }
}

async function runConfirmScenario() {
  if (!RUN_CONFIRM) {
    console.log(
      "\nConfirm test skipped. Pass --confirm to create a calendar event.",
    );
    return;
  }

  console.log("\n--- Confirm Scenario: Create one OpenEMR calendar event ---");
  const result = await getAvailableSlots(FROM_DATE, TO_DATE);
  if (result.status !== "success" || !result.data) {
    throw new Error(
      `Unable to fetch slots for confirm scenario: ${result.message}`,
    );
  }

  const targetSlot = result.data.slots[0];
  if (!targetSlot) {
    throw new Error("No available slot found for confirmation test.");
  }

  const confirmation = await confirmAppointment(targetSlot);
  if (confirmation.status !== "success" || !confirmation.data) {
    throw new Error(
      `Unexpected confirmation response: ${JSON.stringify(confirmation)}`,
    );
  }
  if (!confirmation.data.appointmentReference.startsWith("OE-")) {
    throw new Error(
      `Expected appointmentReference to start with OE-, got ${confirmation.data.appointmentReference}`,
    );
  }

  console.log(
    `Confirmed ${targetSlot.date} ${targetSlot.startTime} with ${confirmation.data.appointmentReference}`,
  );

  const afterConfirm = await getAvailableSlots(
    targetSlot.date,
    targetSlot.date,
    targetSlot.providerId,
  );
  const stillAvailable = afterConfirm.data?.slots.some(
    (slot) =>
      slot.date === targetSlot.date &&
      slot.startTime === targetSlot.startTime &&
      slot.endTime === targetSlot.endTime &&
      slot.providerId === targetSlot.providerId,
  );
  if (stillAvailable) {
    throw new Error("Confirmed slot still appears in available slots.");
  }

  await expectConfirmConflict(targetSlot);
  console.log("Confirm scenario passed.");
}

main()
  .then(runConfirmScenario)
  .catch((err) => {
    console.error("\nConfirm scenario error:", err);
    process.exit(1);
  });
