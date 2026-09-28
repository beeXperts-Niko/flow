# Flow changelog

> Every released version. Each entry is marked as **New**, **Improvement**, **Bugfix**, or **Other**.

- Product page: https://sinthex.de/flow/
- This changelog (HTML): https://sinthex.de/flow/changelog.html
- Download: https://sinthex.de/flow/Flow-1.6.4.pkg

## 1.6.4 — 28 September 2026

- **Other** — The product page shows only the latest versions with new capabilities. The full changelog is on its own page. Each entry is marked as new, an improvement, a bugfix, or other.

## 1.6.3 — 28 September 2026

- **Bugfix** — An instruction on selected text writes the text you asked for. If only a keyword from the sentence comes back, Flow inserts the spoken sentence.

## 1.6.2 — 28 September 2026

- **Bugfix** — Whisper starts again.
- **Improvement** — Restart keeps watching until recognition is ready or the error is shown.
- **Improvement** — For correction you choose ChatGPT or your own model.

## 1.6.1 — 28 September 2026

- **New** — Selected text becomes the instruction. Flow reads the selection and replaces it, for example with a summary. The widget shows that while it happens.

## 1.6.0 — 28 September 2026

- **Improvement** — Recognized text is inserted sooner.
- **Improvement** — Fn starts the next recording while “Inserted” is still showing.
- **Improvement** — Other audio can be muted or just lowered.
- **Improvement** — While recording, the menu bar keeps the Flow icon in orange.

## 1.5.1 — 28 September 2026

- **Bugfix** — The widget shrinks again after dictation, even if the pointer was over it.

## 1.5.0 — 28 September 2026

- **New** — The dictionary reads left to right: what was recognized, then the correct form.
- **New** — Single words are weighted.
- **New** — Short edits of inserted text are added on their own.

## 1.4.1 — 28 September 2026

- **Improvement** — The widget can be moved down to the screen edge and against the Dock.

## 1.4.0 — 28 September 2026

- **New** — While you dictate, Flow mutes other audio. That is on by default and can be turned off in Settings and in the menu bar.

## 1.3.3 — 28 September 2026

- **Other** — The product page ships with llms.txt, Markdown versions, a sitemap, and structured data. An FAQ answers common questions for search and AI assistants.

## 1.3.2 — 28 September 2026

- **New** — Settings separate speech recognition and correction. OpenAI stays the default. Your own API address and key apply to a local or other model.

## 1.3.1 — 27 September 2026

- **New** — The interface ships in the official languages of Europe, including regional ones such as Catalan, Basque, Gaelic, and Romansh.

## 1.3.0 — 27 September 2026

- **New** — Correction takes your own API address and key. A local or other model works that way.

## 1.2.0 — 27 September 2026

- **New** — The interface follows the system language. German stays German. Any other language uses a matching language file, otherwise English.
- **New** — Further languages are JSON files. Flow reads them at launch from the app and from the Flow folder.

## 1.1.0 — 27 September 2026

- **Other** — The app identity and the Keychain entry are de.sinthex.flow. An existing OpenAI key is copied across once.
- **New** — Installer for the Mac. The app then lives in the Applications folder.
- **New** — Flow recommends the newest fast correction model available to your key. You can pin a different model.
- **New** — The style follows the frontmost app, and you can change it for each app.
- **Improvement** — The OpenAI key can be pasted from the clipboard.
- **Improvement** — Recognition is prepared as soon as you press the Fn key.

## 1.0.0 — 27 September 2026

- **New** — First public release under the MIT license: dictation in the menu bar, Whisper on the Mac, correction optional.
