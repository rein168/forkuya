let kokoroTTS = null;
let currentKokoroAudio = null;
window.__kokoroState = "idle";
window.__kokoroProgress = 0.0;

window.__kokoroWarm = async () => {
    if (kokoroTTS) return;
    if (window.__kokoroState === "loading") return;
    
    window.__kokoroState = "loading";
    window.__kokoroProgress = 0.0;
    
    try {
        const { KokoroTTS } = await import("https://cdn.jsdelivr.net/npm/kokoro-js@latest/dist/kokoro.web.js");

        // Quantized 4-bit model keeps memory footprint low in browser
        kokoroTTS = await KokoroTTS.from_pretrained("onnx-community/Kokoro-82M-ONNX", {
            dtype: "q8",
            progress_callback: (progress) => {
                if (progress.status === "progress") {
                    window.__kokoroProgress = (progress.loaded / progress.total);
                } else if (progress.status === "done") {
                    window.__kokoroProgress = 1.0;
                }
            }
        });
        window.__kokoroState = "ready";
    } catch (err) {
        console.error("Kokoro-js initialization failed.", err);
        window.__kokoroState = "error";
    }
};

window.__kokoroSpeak = async (text, voiceId) => {
    if (currentKokoroAudio) {
        currentKokoroAudio.pause();
        currentKokoroAudio = null;
    }
    
    if (!kokoroTTS) {
        await window.__kokoroWarm();
    }
    if (!kokoroTTS) return false;
    
    try {
        const rawAudio = await kokoroTTS.generate(text, {
            voice: voiceId
        }); const audioBlob = rawAudio.toBlob();

        const audioUrl = URL.createObjectURL(audioBlob);
        currentKokoroAudio = new Audio(audioUrl);
        
        currentKokoroAudio.onended = () => {
            URL.revokeObjectURL(audioUrl);
        };

        await currentKokoroAudio.play();
        return true;
    } catch (error) {
        console.error("Kokoro generation failed:", error);
        return false;
    }
};

window.__kokoroStop = () => {
    if (currentKokoroAudio) {
        currentKokoroAudio.pause();
        currentKokoroAudio = null;
    }
};


