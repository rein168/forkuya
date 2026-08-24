# Typer free natural-voice proxy (Cloudflare Worker)

This tiny Worker gives Typer **genuinely natural Microsoft Azure Neural voices**
for free, with **no API key** and **no credit card**. The Typer app fetches an
MP3 from it and plays it; the Worker talks to Microsoft Edge's public "Read
Aloud" speech service on the server side (where browser CORS/hotlink blocks
don't apply) and returns the audio with permissive CORS.

## Voices Typer uses

| Profile | Azure voice          | Notes                                   |
|---------|----------------------|-----------------------------------------|
| GIRL    | `en-US-AnaNeural`    | A genuine **child** voice.              |
| WOMAN   | `en-US-JennyNeural`  | Warm adult female.                      |
| MAN     | `en-US-ChristopherNeural` | Adult male.                        |
| BOY     | `en-US-GuyNeural` + higher pitch | No child-male neural voice exists; a pitched-up adult male is the closest. |

You can browse every free voice name here:
<https://learn.microsoft.com/azure/ai-services/speech-service/language-support?tabs=tts>

## Deploy in ~10 minutes (no credit card)

1. Create a free Cloudflare account: <https://dash.cloudflare.com/sign-up>
   (the **Workers Free** plan needs no payment method; ~100,000 requests/day).
2. In the dashboard: **Workers & Pages → Create → Create Worker**. Give it a
   name like `typer-voice`. Click **Deploy** (the starter code is fine for now).
3. Click **Edit code**, delete everything, and paste the contents of
   [`worker.js`](./worker.js). Click **Deploy**.
4. Your Worker URL is shown at the top, e.g.
   `https://typer-voice.<your-subdomain>.workers.dev`.

### Test it (10 seconds)

Open this in a browser (replace the host with yours):

```
https://typer-voice.YOURNAME.workers.dev/?text=hello%20there&voice=en-US-AnaNeural
```

You should hear / download a short, natural-sounding MP3. Try
`voice=en-US-JennyNeural` too.

## Point Typer at it

- **Quick test (no rebuild):** open the app with the proxy in the URL, e.g.
  `https://rein168.github.io/forkuya/?ttsproxy=https://typer-voice.YOURNAME.workers.dev`
  then press **SPEAK**. The chip should read **Natural Voice** and it should
  sound genuinely natural.
- **For everyone, permanently:** send the Worker URL to the maintainer to bake
  in as the default (`kDefaultFreeVoiceProxyUrl` in
  `lib/services/tts_service.dart`), then redeploy. After that no configuration
  is needed on any device.

## Notes & limits

- **Privacy:** the text being spoken is sent to Microsoft's speech service to
  synthesize it (the same as any cloud voice). No profile data, names, or keys
  are sent — only the utterance.
- **Reliability:** this uses an *unofficial* Microsoft endpoint. It is extremely
  widely used and stable, but Microsoft could change it. If synthesis ever
  fails, Typer automatically falls back to the device/browser voice, so the app
  never goes silent.
- If Cloudflare's egress IPs are ever blocked by the endpoint (rare), the same
  `worker.js` logic can run on other free hosts (Deno Deploy, a small VPS).
