# Flow – Dictation in the menu bar

> Menu-bar dictation for macOS. Recording stays on the Mac. Whisper runs locally. Optional correction uses your own API key. By Sinthex. MIT license. Version 1.6.4.

- Product page: https://sinthex.de/flow/
- Source: https://github.com/beeXperts-Niko/flow
- Download: https://sinthex.de/flow/Flow-1.6.4.pkg
- Publisher: Sinthex (Sinthex Holding UG (haftungsbeschränkt), Kircheib, Germany)
- Contact: hi@sinthex.de

## What it is

Flow is a menu-bar app for macOS 14+ on Apple Silicon. Hold **Fn**, speak, release — text is inserted into the active field in whatever app you are using. If text is already selected, what you say is the instruction: Flow replaces the selection, for example with a summary. Correction and command mode need to be on. Double-tap **Fn** for hands-free speaking. **Esc** cancels.

## How recognition and correction work

1. **Microphone** — records while you speak.
2. **Whisper, local** — converts audio to text on the Mac via MLX (`mlx-community/whisper-large-v3-turbo`). Audio is not uploaded for recognition.
3. **Active field** — text is inserted at the cursor.
4. **Optional correction** — between steps 2 and 3, recognized text (not audio) can go to OpenAI or another OpenAI-compatible API with your own key. Without a key, you keep Whisper’s text.

The API key lives in the macOS Keychain (`de.sinthex.flow`), not in a config file or the repository. Settings can point correction at a custom API base URL (including a local model).

## Features

- **Local Whisper** — speech recognition on Apple Silicon; model files stay in the Flow folder.
- **Optional correction** — filler words out, punctuation in, tone adjusted; recommended newest fast model for your key, or a pinned model.
- **Dictionary** — exact spellings for names, brands, and terms; can map misheard forms to the correct spelling.
- **Insert and rewrite** — insert at the cursor. If text is selected, hold Fn and say the instruction, for example “can you summarize this?”. Flow replaces the selection. Correction and command mode need to be on.
- **History** — recent dictations in the menu-bar popover; raw text available; stored locally.
- **Style by frontmost app** — Automatic, Literal, Email, Chat, Notes, Coding; per-app mapping editable.
- **Floating widget** — click to dictate if you prefer not to use Fn.
- **UI languages** — official languages of Europe (including regional ones); German stays German; other missing languages fall back to English.
- **Mute other audio** — on by default while you dictate; speakers and headphones return to their previous state afterwards. Switch it in Settings or the menu bar.

## Privacy

- Recording does not leave the Mac for recognition.
- Correction only with your key; OpenAI (or your endpoint) terms apply when enabled.
- Keychain storage for the key.
- History and settings under `~/Library/Application Support/Flow/`.
- This product page loads no trackers, no third-party fonts, and no third-party scripts.

## Requirements

**Hardware:** Apple Silicon Mac (M1+), microphone, about 3 GB free disk (Whisper weights ~1.5 GB, local runtime ~1.3 GB).

**Software:** macOS 14+, network on first launch to set up recognition and download weights, Microphone and Accessibility permissions, optional OpenAI (or compatible) API key for correction.

**Note:** The package may not be Apple-notarized. If macOS blocks it, use System Settings → Privacy & Security → Open Anyway.

## Build from source

```bash
git clone https://github.com/beeXperts-Niko/flow.git
cd flow
./scripts/install.sh
```

Needs Xcode command-line tools, uv, and Python 3.12.

## Changelog (latest features)

The product page lists the last three versions that added a new capability. The full list, with New / Improvement / Bugfix / Other labels, is at https://sinthex.de/flow/changelog.md

- **1.6.1** — **New** — Selected text becomes the instruction. Flow reads the selection and replaces it, for example with a summary.
- **1.6.0** — **Improvement** — Recognized text is inserted sooner. Fn can start the next recording while “Inserted” is still showing. Other audio can be muted or lowered. The menu-bar icon stays orange while recording.
- **1.5.0** — **New** — Dictionary reads left to right. Single words are weighted. Short edits of inserted text are learned.

## License

MIT License. Copyright (c) 2026 Sinthex.

You may use, modify, and redistribute Flow, including commercially, if the copyright notice and license text are preserved. No warranty.

Built on mlx-whisper, MLX, mlx-vlm, and OpenAI Whisper large-v3-turbo weights — see THIRD_PARTY_NOTICES.md in the repository.

## FAQ

**What is Flow?**  
A privacy-first menu-bar dictation app for Mac: local Whisper recognition, optional cloud correction with your own key.

**Does my voice leave the Mac?**  
Not for recognition. Audio stays on device. Only optional correction may send recognized *text* to an API you configure.

**Is Flow free?**  
Yes. Open source under MIT. Optional correction may incur costs on your own API account.

**How is this different from built-in macOS dictation?**  
Flow is open source, uses local Whisper on Apple Silicon, inserts into any app via Accessibility, supports styles and dictionary, and keeps optional LLM correction under your own key.

**Who makes Flow?**  
Sinthex (Sinthex Holding UG (haftungsbeschränkt), Germany). Not a product of Apple or OpenAI.
