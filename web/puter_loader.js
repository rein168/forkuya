let currentPuterAudio = null;

// Expose a globally accessible function to synthesize and play text via Puter.js
window.__puterSpeak = async (text, voice) => {
    // If something is already playing, stop it immediately for instant responsiveness
    if (currentPuterAudio) {
        currentPuterAudio.pause();
        currentPuterAudio = null;
    }
    
    try {
        // Fetch audio element from Puter's free TTS API
        // "neural" engine corresponds to high quality voices like Amazon Polly
        currentPuterAudio = await puter.ai.txt2speech(text, { 
            voice: voice, 
            engine: "neural", 
            language: "en-US" 
        });
        
        // Play the audio
        currentPuterAudio.play();
        return true;
    } catch (e) {
        console.error("[puter] speak failed:", e);
        return false;
    }
};

window.__puterStop = () => {
    if (currentPuterAudio) {
        currentPuterAudio.pause();
        currentPuterAudio = null;
    }
};

console.log("[puter] loader installed");

