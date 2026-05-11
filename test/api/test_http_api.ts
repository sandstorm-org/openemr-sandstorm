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
const FROM_DATE = getArg("--from", new Date().toISOString().split("T")[0]);
const TO_DATE = getArg(
  "--to",
  new Date(Date.now() + 7 * 86_400_000).toISOString().split("T")[0]
);

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
    events: unknown[];
    isMockData: boolean;
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

// ── Display Helpers ──
function printSlotTable(slots: TimeSlot[]) {
  if (slots.length === 0) {
    console.log("  (no slots)");
    return;
  }

  // Group by date
  const grouped = new Map<string, TimeSlot[]>();
  for (const slot of slots) {
    const existing = grouped.get(slot.date) || [];
    existing.push(slot);
    grouped.set(slot.date, existing);
  }

  for (const [date, daySlots] of grouped) {
    console.log(`\n  📅 ${date} (${daySlots.length} slots)`);
    // Show first 5 and last slot per day
    const preview = daySlots.length > 6
      ? [...daySlots.slice(0, 5), daySlots[daySlots.length - 1]]
      : daySlots;

    for (const s of preview) {
      console.log(
        `     ${s.startTime} - ${s.endTime} | ${s.providerName} | ${s.status}`
      );
    }
    if (daySlots.length > 6) {
      console.log(`     ... and ${daySlots.length - 6} more`);
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
    // Test 1: Fetch all available slots
    console.log("\n─── Test 1: Fetch all available slots ───");
    const result = await getAvailableSlots(FROM_DATE, TO_DATE);

    if (result.status !== "success") {
      console.error("❌ API returned error:", result.message);
      process.exit(1);
    }

    const data = result.data!;
    console.log(`\n✅ Response status: ${result.status}`);
    console.log(`   Mock data: ${data.isMockData ? "YES (no real schedules yet)" : "NO (real data)"}`);
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

main();
