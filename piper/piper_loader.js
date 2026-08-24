// Offline Piper TTS loader.
//
// Wires the bundled @mintplex-labs/piper-tts-web engine to same-origin assets
// so it runs FULLY OFFLINE: the model, the ONNX runtime, and the espeak-ng
// phonemizer all live under web/piper/ and nothing is fetched from Hugging Face
// or any CDN at runtime. Exposes window.__piperSpeak(text) -> Promise<blobUrl>.
//
// onnxruntime-web is resolved by the import map in index.html.
import { TtsSession } from './piper-tts-web.js';

const BASE = new URL('.', import.meta.url).href; // absolute URL of web/piper/
const VOICE = 'en_US-hfc_female-medium';

// The library fetches the model from Hugging Face by URL. Redirect just that
// request to our bundled copy so the engine is genuinely offline. Scoped
// tightly so no other app request is affected. Large files report progress.
const _fetch = window.fetch.bind(window);
window.fetch = async (input, init) => {
  const url = typeof input === 'string' ? input : (input && input.url) || '';
  let actualUrl = url;
  if (url.includes('huggingface.co/diffusionstudio/piper-voices')) {
    const file = url.substring(url.lastIndexOf('/') + 1); // *.onnx or *.onnx.json
    actualUrl = BASE + 'model/' + file;
  }
  // Only track the big downloads for the progress bar
  const isLarge = actualUrl.includes('en_US-hfc_female-medium') ||
                  actualUrl.includes('piper_phonemize');
  if (!isLarge) return _fetch(actualUrl, init);
  const resp = await _fetch(actualUrl, init);
  const len = resp.headers.get('content-length');
  if (!len || !resp.body) return resp;
  const total = parseInt(len, 10);
  let loaded = 0;
  const stream = new ReadableStream({
    async start(controller) {
      const reader = resp.body.getReader();
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        loaded += value.length;
        window.__piperProgress = Math.min(0.98, loaded / total);
        controller.enqueue(value);
      }
      controller.close();
    }
  });
  return new Response(stream, { headers: resp.headers, status: resp.status });
};

// 'unsupported' until we confirm the browser can run it; then 'loading' ->
// 'ready' / 'error'. Read by the Dart side for the honest voice chip.
window.__piperState = 'idle';
window.__piperProgress = 0; // 0..1 download progress for the tiny progress bar
let sessionPromise = null;

function createSession() {
  window.__piperState = 'loading';
  window.__piperProgress = 0.02;
  return TtsSession.create({
    voiceId: VOICE,
    wasmPaths: {
      onnxWasm: BASE + 'ort/',
      piperData: BASE + 'piper_phonemize.data',
      piperWasm: BASE + 'piper_phonemize.wasm',
    },
    logger: (t) => console.log('[piper]', t),
  }).then((session) => {
    window.__piperProgress = 1;
    window.__piperState = 'ready';
    console.log('[piper] engine ready (offline)');
    return session;
  }).catch((e) => {
    window.__piperState = 'error';
    window.__piperProgress = 0;
    console.error('[piper] init failed:', e);
    sessionPromise = null; // allow a later retry
    throw e;
  });
}

function getSession() {
  if (!sessionPromise) sessionPromise = createSession();
  return sessionPromise;
}

// Warm the engine (download + compile model/wasm) ahead of the first press so
// SPEAK is not blocked by a multi-second first load.
window.__piperWarm = () => { getSession().catch(() => {}); };

// Cache synthesized audio by text: the alphabet and common words are tiny and
// identical every time, so after the first press they play instantly.
const _cache = new Map();

// Synthesize [text] and return a playable blob: URL, or '' on any failure so
// the Dart side can fall through to the next voice.
window.__piperSpeak = async (text) => {
  const key = String(text);
  const hit = _cache.get(key);
  if (hit) return hit;
  try {
    const session = await getSession();
    const wav = await session.predict(key);
    const url = URL.createObjectURL(wav);
    _cache.set(key, url);
    return url;
  } catch (e) {
    console.error('[piper] speak failed:', e);
    return '';
  }
};

console.log('[piper] loader installed');
