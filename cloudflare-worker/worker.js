// Free Azure Neural TTS proxy for the Typer AAC app.
//
// Bridges Microsoft Edge's "Read Aloud" speech service (the same free endpoint
// the widely-used `edge-tts` project uses) to a simple HTTPS GET that returns
// an MP3 with permissive CORS, so the Typer PWA can fetch it and play it.
//
//   GET /?text=hello&voice=en-US-AnaNeural&rate=-8%25&pitch=%2B0%25
//        -> 200 audio/mpeg   (Access-Control-Allow-Origin: *)
//
// No API key. No account credentials. Free Cloudflare Workers plan allows
// ~100,000 requests/day, far more than a classroom needs. See README.md.

const TRUSTED_TOKEN = "6A5AA1D4EAFF4E9FB37E23D68491D6F4";
const WSS_BASE =
  "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1";
const GEC_VERSION = "1-130.0.2849.68";
const OUTPUT_FORMAT = "audio-24khz-48kbitrate-mono-mp3";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "*",
};

async function sha256UpperHex(str) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
  return [...new Uint8Array(buf)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();
}

// Edge's anti-abuse token: SHA-256 of (Windows-epoch ticks rounded to 5 min) +
// the trusted client token. BigInt keeps the 100-ns tick count exact.
async function generateSecMsGec() {
  let seconds = Math.floor(Date.now() / 1000) + 11644473600; // to Windows epoch
  seconds -= seconds % 300; // round down to a 5-minute boundary
  const ticks = BigInt(seconds) * 10000000n; // seconds -> 100-ns units
  return sha256UpperHex(ticks.toString() + TRUSTED_TOKEN);
}

function escapeXml(s) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function buildSsml(text, voice, rate, pitch) {
  return (
    `<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>` +
    `<voice name='${voice}'>` +
    `<prosody rate='${escapeXml(rate)}' pitch='${escapeXml(pitch)}'>${escapeXml(text)}</prosody>` +
    `</voice></speak>`
  );
}

async function synthesize(text, voice, rate, pitch) {
  const token = await generateSecMsGec();
  const url =
    `${WSS_BASE}?TrustedClientToken=${TRUSTED_TOKEN}` +
    `&Sec-MS-GEC=${token}&Sec-MS-GEC-Version=${GEC_VERSION}`;

  const resp = await fetch(url, { headers: { Upgrade: "websocket" } });
  const ws = resp.webSocket;
  if (!ws) throw new Error("websocket refused (status " + resp.status + ")");
  ws.accept();

  const requestId = crypto.randomUUID().replace(/-/g, "");
  const now = new Date().toString();

  const configMsg =
    `X-Timestamp:${now}\r\nContent-Type:application/json; charset=utf-8\r\n` +
    `Path:speech.config\r\n\r\n` +
    `{"context":{"synthesis":{"audio":{"metadataoptions":` +
    `{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},` +
    `"outputFormat":"${OUTPUT_FORMAT}"}}}}`;

  const ssmlMsg =
    `X-RequestId:${requestId}\r\nContent-Type:application/ssml+xml\r\n` +
    `X-Timestamp:${now}\r\nPath:ssml\r\n\r\n` +
    buildSsml(text, voice, rate, pitch);

  const chunks = [];
  const finished = new Promise((resolve, reject) => {
    ws.addEventListener("message", async (ev) => {
      const data = ev.data;
      if (typeof data === "string") {
        if (data.includes("Path:turn.end")) resolve();
        return;
      }
      // Binary frame: [2-byte big-endian header length][header][audio bytes].
      const bytes = new Uint8Array(
        data instanceof ArrayBuffer ? data : await data.arrayBuffer()
      );
      const headerLen = (bytes[0] << 8) | bytes[1];
      const header = new TextDecoder().decode(bytes.subarray(2, 2 + headerLen));
      if (header.includes("Path:audio")) {
        chunks.push(bytes.subarray(2 + headerLen));
      }
    });
    ws.addEventListener("close", () => resolve());
    ws.addEventListener("error", () => reject(new Error("websocket error")));
    setTimeout(() => reject(new Error("timeout")), 15000);
  });

  ws.send(configMsg);
  ws.send(ssmlMsg);
  await finished;
  try {
    ws.close();
  } catch (_) {}

  const total = chunks.reduce((n, c) => n + c.length, 0);
  if (total === 0) throw new Error("no audio returned");
  const out = new Uint8Array(total);
  let offset = 0;
  for (const c of chunks) {
    out.set(c, offset);
    offset += c.length;
  }
  return out;
}

export default {
  async fetch(request) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS });
    }
    const { searchParams } = new URL(request.url);
    const text = (searchParams.get("text") || "").slice(0, 500).trim();
    const voice = searchParams.get("voice") || "en-US-JennyNeural";
    const rate = searchParams.get("rate") || "+0%";
    const pitch = searchParams.get("pitch") || "+0%";

    if (!text) {
      return new Response("Missing ?text", { status: 400, headers: CORS });
    }
    // Only allow the well-formed Azure voice names, never arbitrary strings.
    if (!/^[a-zA-Z-]+Neural$/.test(voice)) {
      return new Response("Bad voice", { status: 400, headers: CORS });
    }

    try {
      const audio = await synthesize(text, voice, rate, pitch);
      return new Response(audio, {
        headers: {
          ...CORS,
          "Content-Type": "audio/mpeg",
          // Same text+voice always sounds identical, so let the browser and
          // Cloudflare edge cache it — the alphabet becomes essentially free.
          "Cache-Control": "public, max-age=604800",
        },
      });
    } catch (e) {
      return new Response("TTS error: " + e.message, { status: 502, headers: CORS });
    }
  },
};
