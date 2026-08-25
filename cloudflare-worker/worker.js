// Free Azure/Translate TTS proxy for Typer — fallback fix for Cloudflare Workers
// The original edge-tts WebSocket path (wss://speech.platform.bing.com) is currently
// blocked when fetched from Cloudflare's egress (Fetch API cannot load: wss://...).
// This minimal proxy uses Google Translate's free TTS endpoint, which is reliably
// reachable from Workers and returns the same MP3 format Typer expects.
// No API key, no bindings, free plan.

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "*",
};

export default {
  async fetch(request) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS });
    }
    const { searchParams } = new URL(request.url);
    const text = (searchParams.get("text") || "").slice(0, 500).trim();
    // voice param kept for Typer compatibility — validated but not used by this upstream
    const voice = searchParams.get("voice") || "en-US-JennyNeural";
    if (!text) {
      return new Response("Missing ?text", { status: 400, headers: CORS });
    }
    if (!/^[a-zA-Z-]+Neural$/.test(voice)) {
      return new Response("Bad voice", { status: 400, headers: CORS });
    }
    try {
      const url = `https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=${encodeURIComponent(text)}`;
      const upstream = await fetch(url, {
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
          "Referer": "https://translate.google.com/",
        },
      });
      if (!upstream.ok) {
        throw new Error("upstream status " + upstream.status);
      }
      const audio = await upstream.arrayBuffer();
      if (!audio || audio.byteLength < 500) throw new Error("no audio returned");
      return new Response(audio, {
        headers: {
          ...CORS,
          "Content-Type": "audio/mpeg",
          "Cache-Control": "public, max-age=604800",
        },
      });
    } catch (e) {
      return new Response("TTS error: " + (e.message || String(e)), { status: 502, headers: CORS });
    }
  },
};
