(function () {
  "use strict";

  var STORAGE = "flow-lang";
  var query = new URLSearchParams(location.search).get("lang");
  var lang = query === "de" || query === "en" ? query : (localStorage.getItem(STORAGE) === "en" ? "en" : "de");
  if (query === "de" || query === "en") {
    localStorage.setItem(STORAGE, query);
  }

  var en = {
    "skip": "Skip to content",
    "brand.by": "by",
    "brand.aria": "Flow, to the home page",
    "nav.label": "Main",
    "nav.feel": "How it feels",
    "nav.features": "Features",
    "nav.pictures": "Pictures",
    "nav.privacy": "Privacy",
    "nav.faq": "FAQ",
    "nav.license": "License",
    "nav.install": "Download",
    "lang.label": "Choose language",
    "hero.eyebrow": "Menu-bar app for macOS · by Sinthex",
    "hero.titleA": "Dictation in the ",
    "hero.titleB": "menu bar.",
    "hero.lead": "Recording stays on the Mac. Correction through OpenAI is optional and uses your own key, which lives only in the Keychain. To rewrite selected text, select it, hold Fn, and say what should happen.",
    "hero.download": "Download the installer",
    "hero.source": "Source on GitHub",
    "hero.facts": "Facts",
    "hero.fact1": "macOS 14 or newer",
    "hero.fact2": "Apple Silicon",
    "hero.fact3": "Whisper, on device",
    "hero.fact4": "Open source, MIT",
    "hero.altWindow": "Flow home window: a large card reading “Hold fn and speak”, then counters for dictated words and the latest dictations.",
    "hero.altPopover": "Flow menu-bar popover with a “Speak freely” button, the automatic correction switch, the Email style, and the latest dictations.",
    "feel.eyebrow": "How it feels",
    "feel.title": "Hold a key, talk, let go.",
    "feel.lead": "Flow works in every app you can type in. No window to switch, nothing to copy. The cursor stays, you speak, the sentence is there.",
    "feel.hold": "Hold Fn",
    "feel.holdBody": "A small pill appears at the bottom of the screen, with a level and a timer. Flow is listening.",
    "feel.speak": "Speak",
    "feel.speakBody": "The way you talk. With pauses, with “um”, with detours.",
    "feel.release": "Let go",
    "feel.releaseBody": "The text is inserted into the field where the cursor is.",
    "feel.double": "A double tap starts hands-free speaking.",
    "feel.esc": "Cancels the recording.",
    "feel.commandEyebrow": "Command on selected text",
    "feel.commandTitle": "Select, hold Fn, say the instruction",
    "feel.commandBody": "“Can you summarize this?”, “shorter”, “in English”, “more polite”. Flow replaces the selection. Correction has to be on, and command mode stays on.",
    "feel.altPill": "Flow’s recording pill: red dot, waveform, time 0:07, and a stop button.",
    "feel.pillCap": "The pill while you are recording",
    "feel.altWidget": "Flow’s floating widget with a microphone button, an fn hint, dictionary, and settings.",
    "feel.widgetCap": "The floating widget, if you would rather click",
    "feel.transform": "Example of a correction",
    "feel.said": "Said",
    "feel.pasted": "Inserted",
    "feel.note": "Example with correction on, style “Automatic”.",
    "feat.eyebrow": "Features",
    "feat.title": "What Flow does.",
    "feat.lead": "Recognition happens on your Mac. Wording happens only if you want it. Everything else is there so the text lands in the right tone, in the right place.",
    "feat.whisper": "Whisper, on device",
    "feat.whisperBody": "Speech recognition runs Whisper on the Mac, through MLX on Apple Silicon. The recording does not go online for that. The model stays in the Flow folder.",
    "feat.correct": "Correction, if you want it",
    "feat.correctBody": "Filler words out, punctuation in, the right tone. For that, the recognized text goes to OpenAI with your own key. Flow recommends the newest fast model your key is allowed to use. You can also pin a model. Without a key, you keep Whisper’s text.",
    "feat.correctChip": "Recommended: newest fast model",
    "feat.dict": "Dictionary",
    "feat.dictBody": "Names, brands, and terms that should always be spelled correctly. If Whisper regularly mishears a word, you add that too, and Flow replaces it exactly.",
    "feat.paste": "Insert and rewrite",
    "feat.pasteBody": "The text lands in the active field, whichever app that is. If text is already selected, what you say is the instruction. “Can you summarize this?” replaces the selection with the summary, instead of writing that sentence over it.",
    "feat.pasteChip": "“can you summarize this?”",
    "feat.history": "History",
    "feat.historyBody": "The latest dictations sit in the menu-bar popover. One click copies them. In History you can also see the raw text of each entry. History stays on the Mac.",
    "feat.historyChip": "Click to copy",
    "style.title": "Style follows the frontmost app",
    "style.body": "A mail sounds different from a chat, and a function name should not be turned into a sentence. Flow sees which app is in front and picks the style. You can change the mapping for every app.",
    "style.map": "Examples of the mapping",
    "style.email": "Email",
    "style.messages": "Messages",
    "style.chat": "Chat",
    "style.notes": "Notes",
    "style.notesOut": "Notes",
    "style.term": "Terminal, editor",
    "style.unknown": "not recognized",
    "style.fallback": "your default style",
    "style.literal": "There is also “Literal”: only filler words and punctuation. Your wording stays.",
    "style.caption": "Style: six default styles, and the per-app list underneath.",
    "style.alt": "Flow’s style page with six cards (Automatic, Literal, Email, Chat, Notes, Coding) and the per-app list, for example Mail set to Email and Terminal set to Coding.",
    "gal.eyebrow": "Pictures",
    "gal.title": "A walk through the app.",
    "gal.note": "Every picture shows sample text, not a real dictation.",
    "gal.styleCap": "Style: each card shows what the spoken words become.",
    "gal.styleAlt": "Style cards with before-and-after examples, such as “be there in five minutes” as a chat and “getUserById(id)” as coding.",
    "gal.styleFig": "<strong>Style</strong> Each card shows what the spoken words become.",
    "gal.menuCap": "Menu bar: speak freely, correction, style, and the latest dictations.",
    "gal.menuAlt": "Menu-bar popover with a “Speak freely” button, the Email style, and the last three dictations.",
    "gal.menuFig": "<strong>Menu bar</strong> Everything important, one click away.",
    "gal.welcomeCap": "Welcome: the first launch explains what stays on the Mac.",
    "gal.welcomeAlt": "Welcome screen “Welcome to Flow” with three points: faster than typing, worded automatically, recording stays here.",
    "gal.welcomeFig": "<strong>First launch</strong> Explains what stays on the Mac.",
    "gal.dictCap": "Dictionary: spelling, and optionally how Whisper hears the word.",
    "gal.dictAlt": "Dictionary with two entries: “flow app” becomes Flow, “sinthex” becomes Sinthex.",
    "gal.dictFig": "<strong>Dictionary</strong> The spelling, and the misheard form when you need it.",
    "gal.histCap": "History: with app, time, and word count. One click shows the raw text.",
    "gal.histAlt": "History with three sample sentences from Mail, Cursor, and Messages, each with a time and a word count.",
    "gal.histFig": "<strong>History</strong> With app, time, and raw text.",
    "gal.setAlt": "Settings, model section: Whisper model mlx-community/whisper-large-v3-turbo, API key shown as the placeholder sk-…, correction model “Recommended: gpt-6-luna”.",
    "gal.setFig": "<strong>Settings, model</strong> A crop of the settings.",
    "gal.modelTitle": "The model section",
    "gal.model1": "The local Whisper model is at the top. Under it, the API key, shown here only as a placeholder: you paste it, and after that it lives in the Keychain.",
    "gal.model2": "Flow looks up the correction model with your key and recommends the newest fast tier, in this example <code>gpt-6-luna</code>. If you want a specific model, you pin it here.",
    "priv.eyebrow": "Privacy",
    "priv.title": "Your voice stays on your Mac.",
    "priv.lead": "The path of a dictation, without the fine print.",
    "priv.mac": "Your Mac",
    "priv.mic": "Microphone",
    "priv.micBody": "Recording, for as long as you speak",
    "priv.whisper": "Whisper, on device",
    "priv.whisperBody": "turns audio into text",
    "priv.field": "Active field",
    "priv.fieldBody": "the text is inserted",
    "priv.optional": "Optional, between 2 and 3",
    "priv.cloud": "Correction via OpenAI",
    "priv.cloudBody": "only the recognized text, only with your key",
    "priv.p1": "The recording never leaves the Mac.",
    "priv.p1b": "Whisper runs locally. No audio is uploaded for recognition.",
    "priv.p2": "Correction only with your key.",
    "priv.p2b": "If it is on and a key is stored, the recognized text goes to OpenAI. Your OpenAI account’s terms apply. Without a key, it stays with Whisper.",
    "priv.p3": "The key lives in the Keychain.",
    "priv.p3b": "Not in a config file, not in the source, not in the repository.",
    "priv.p4": "History and settings stay local.",
    "priv.p4b": "They live in the Flow folder on your Mac. This page loads no trackers, no third-party fonts, and no third-party scripts.",
    "start.eyebrow": "Get started",
    "start.title": "What you need.",
    "start.hwTitle": "Hardware",
    "start.swTitle": "Software",
    "start.os": "<strong>macOS 14</strong> or newer",
    "start.chip": "A Mac with <strong>Apple Silicon</strong>, M1 or newer",
    "start.mic": "A <strong>microphone</strong>",
    "start.disk": "About <strong>3 GB free</strong>. The Whisper weights are about 1.5 GB, the local runtime about 1.3 GB.",
    "start.net": "<strong>Network</strong> on first launch, so Flow can set up recognition",
    "start.perm": "Permission for the <strong>microphone</strong> and <strong>Accessibility</strong>",
    "start.key": "Optionally an <strong>OpenAI API key</strong> for correction",
    "start.pkgTitle": "Installer for the Mac",
    "start.pkgBody": "Flow 1.6.4 puts the app in the Applications folder. On first launch, Flow sets up recognition on the Mac and downloads the Whisper weights. That needs a network for a moment.",
    "start.pkgGate": "macOS may refuse the package because it is not notarized by Apple. Then choose “Open Anyway” in System Settings, under Privacy & Security.",
    "start.pkgBtn": "Download Flow-1.6.4.pkg",
    "log.title": "Changes",
    "log.lead": "The latest versions that added a new capability.",
    "log.more": "Full changelog",
    "log.fullTitle": "Changelog",
    "log.fullLead": "Every released version. Each entry is marked as new, an improvement, a bugfix, or other.",
    "log.kind.new": "New",
    "log.kind.improve": "Improvement",
    "log.kind.fix": "Bugfix",
    "log.kind.other": "Other",
    "log.legend": "Labels",
    "log.legend.new": "New capability",
    "log.legend.improve": "Existing behavior",
    "log.legend.fix": "Something fixed",
    "log.legend.other": "Site, package, notes",
    "log.v164date": "September 28, 2026",
    "log.v164.page": "The product page shows only the latest versions with new capabilities. The full changelog is on its own page. Each entry is marked as new, an improvement, a bugfix, or other.",
    "log.v163date": "September 28, 2026",
    "log.v163.command": "An instruction on selected text writes the text you asked for. If only a keyword from the sentence comes back, Flow inserts the spoken sentence.",
    "log.v162date": "September 28, 2026",
    "log.v162.start": "Whisper starts again.",
    "log.v162.restart": "Restart keeps watching until recognition is ready or the error is shown.",
    "log.v162.model": "For correction you choose ChatGPT or your own model.",
    "log.v161date": "September 28, 2026",
    "log.v161.command": "Selected text becomes the instruction. Flow reads the selection and replaces it, for example with a summary. The widget shows that while it happens.",
    "log.v160date": "September 28, 2026",
    "log.v160.insert": "Recognized text is inserted sooner.",
    "log.v160.next": "Fn starts the next recording while “Inserted” is still showing.",
    "log.v160.audio": "Other audio can be muted or just lowered.",
    "log.v160.icon": "While recording, the menu bar keeps the Flow icon in orange.",
    "log.v151date": "September 28, 2026",
    "log.v151.widget": "The widget shrinks again after dictation, even if the pointer was over it.",
    "log.v150date": "September 28, 2026",
    "log.v150.read": "The dictionary reads left to right: what was recognized, then the correct form.",
    "log.v150.weight": "Single words are weighted.",
    "log.v150.learn": "Short edits of inserted text are added on their own.",
    "log.v141date": "September 28, 2026",
    "log.v141.widget": "The widget can be moved down to the screen edge and against the Dock.",
    "log.v140date": "September 28, 2026",
    "log.v140.mute": "While you dictate, Flow mutes other audio. That is on by default and can be turned off in Settings and in the menu bar.",
    "log.v133date": "September 28, 2026",
    "log.v133.seo": "The product page ships with llms.txt, Markdown versions, a sitemap, and structured data. An FAQ answers common questions for search and AI assistants.",
    "log.v132date": "September 28, 2026",
    "log.v132.split": "Settings separate speech recognition and correction. OpenAI stays the default. Your own API address and key apply to a local or other model.",
    "log.v131date": "September 27, 2026",
    "log.v131.lang": "The interface ships in the official languages of Europe, including regional ones such as Catalan, Basque, Gaelic, and Romansh.",
    "log.v13date": "September 27, 2026",
    "log.v13.api": "Correction takes your own API address and key. A local or other model works that way.",
    "log.v12date": "September 27, 2026",
    "log.v12.lang": "The interface follows the system language. German stays German. Any other language uses a matching language file, otherwise English.",
    "log.v12.files": "Further languages are JSON files. Flow reads them at launch from the app and from the Flow folder.",
    "log.v11date": "September 27, 2026",
    "log.v11.id": "The app identity and the Keychain entry are de.sinthex.flow. An existing OpenAI key is copied across once.",
    "log.v11.pkg": "Installer for the Mac. The app then lives in the Applications folder.",
    "log.v11.model": "Flow recommends the newest fast correction model available to your key. You can pin a different model.",
    "log.v11.style": "The style follows the frontmost app, and you can change it for each app.",
    "log.v11.paste": "The OpenAI key can be pasted from the clipboard.",
    "log.v11.warmup": "Recognition is prepared as soon as you press the Fn key.",
    "log.v10date": "September 27, 2026",
    "log.v10.body": "First public release under the MIT license: dictation in the menu bar, Whisper on the Mac, correction optional.",
    "start.buildTitle": "Or build it yourself",
    "start.buildBody": "For that you need the Xcode command-line tools, uv, and Python 3.12.",
    "start.repo": "Open the repository",
    "faq.eyebrow": "FAQ",
    "faq.title": "Short answers.",
    "faq.lead": "The points search and assistants need most often — without detours.",
    "faq.q1": "What is Flow?",
    "faq.a1": "Flow is a menu-bar app for macOS on Apple Silicon. Hold Fn, speak, release — the text lands in the active field. Speech recognition runs locally with Whisper. Correction through an API is optional and uses your own key.",
    "faq.q2": "Does my voice leave the Mac?",
    "faq.a2": "Not for recognition. Whisper runs locally; audio is not uploaded for that. Only if optional correction is on and a key is stored does the recognized text — not the audio — go to OpenAI or a compatible API you choose.",
    "faq.q3": "What does Flow require?",
    "faq.a3": "An Apple Silicon Mac from M1 up, macOS 14 or newer, a microphone, Microphone and Accessibility permissions, and about 3 GB free disk. On first launch Flow needs the network briefly. An API key is only needed for optional correction.",
    "faq.q4": "Is Flow free and open source?",
    "faq.a4": "Yes. Flow is under the MIT license, Copyright (c) 2026 Sinthex. The app and source are free to use. Optional correction may incur costs on your own API account.",
    "faq.q5": "How does Flow differ from built-in macOS dictation?",
    "faq.a5": "Flow is open source, recognizes speech locally with Whisper on Apple Silicon, inserts text into any app via Accessibility, has styles and a dictionary, and runs optional LLM correction with your own key. It is not a product of Apple or OpenAI.",
    "faq.q6": "Where can I download Flow?",
    "faq.a6": "The installer is on this page as <a href=\"Flow-1.6.4.pkg\" download=\"Flow-1.6.4.pkg\">Flow-1.6.4.pkg</a>. The source is on <a href=\"https://github.com/beeXperts-Niko/flow\">GitHub</a>.",
    "faq.q7": "Who builds Flow?",
    "faq.a7": "Flow is a project by <a href=\"https://sinthex.de/\">Sinthex</a> (Sinthex Holding UG (haftungsbeschränkt)) in Kircheib, Germany. Contact: <a href=\"mailto:hi@sinthex.de\">hi@sinthex.de</a>.",
    "lic.eyebrow": "License",
    "lic.title": "Flow is under the MIT license.",
    "lic.may": "You may",
    "lic.mayBody": "Use, change, and share Flow. In your own products too, including commercially.",
    "lic.keep": "Condition",
    "lic.keepBody": "The copyright notice “Copyright (c) 2026 Sinthex” and the license text stay with every copy.",
    "lic.no": "No warranty",
    "lic.noBody": "Flow comes as it is. Sinthex is not liable for damage or errors.",
    "lic.original": "The English original is binding: <a href=\"https://github.com/beeXperts-Niko/flow/blob/main/LICENSE\">Read LICENSE in the repository</a>",
    "lic.base": "What Flow is built on",
    "lic.baseLead": "Flow uses these open-source projects. Their licenses apply in addition and are printed in THIRD_PARTY_NOTICES.md in the repository.",
    "lic.colProject": "Project",
    "lic.colUse": "Used for",
    "lic.colLicense": "License",
    "lic.colCopy": "Copyright",
    "lic.use1": "Speech recognition on Apple Silicon",
    "lic.use2": "Compute library for Apple Silicon",
    "lic.use3": "Optional local correction",
    "lic.use4": "Model weights for recognition",
    "lic.code": "Code",
    "lic.model": "Model",
    "author.eyebrow": "Author",
    "author.title": "Flow is a project by Sinthex.",
    "author.body": "Built, maintained, and published as open source by Sinthex. Bugs, questions, and suggestions belong in the repository on GitHub.",
    "footer.nav": "Footer",
    "footer.source": "Source",
    "footer.mit": "License (MIT)",
    "footer.credits": "Projects used",
    "footer.impressum": "Legal notice",
    "footer.privacy": "Privacy policy",
    "footer.changelog": "Changelog",
    "footer.llms": "llms.txt",
    "footer.copy": "© 2026 Sinthex. Flow is under the MIT license, Copyright (c) 2026 Sinthex.",
    "footer.samples": "Every picture shows sample text, not a real dictation.",
    "footer.marks": "Flow is not a product of Apple or OpenAI. macOS, Apple Silicon, OpenAI, and Whisper are trademarks of their respective owners.",
    "lightbox": "Image view",
    "lightboxClose": "Close",
    "imp.metaTitle": "Legal notice | Sinthex",
    "imp.metaDesc": "Legal notice of Sinthex Holding UG (haftungsbeschränkt), Kircheib: provider identification, contact and mandatory information.",
    "imp.eyebrow": "Sinthex",
    "imp.title": "Legal Notice",
    "imp.subtitle": "Information according to § 5 TMG",
    "imp.responsible": "Service provider pursuant to § 5 TMG",
    "imp.country": "Germany",
    "imp.director": "Managing Director:",
    "imp.contact": "Contact",
    "imp.email": "Email:",
    "imp.vat": "VAT ID:",
    "imp.profession": "Professional designation and regulations",
    "imp.professionBody": "Professional designation: Software development",
    "imp.eu": "EU Dispute Resolution",
    "imp.euBody": "The European Commission provides a platform for online dispute resolution (ODR):",
    "imp.euMail": "You can find our email address above in the legal notice.",
    "imp.consumer": "Consumer Dispute Resolution/Universal Arbitration Board",
    "imp.consumerBody": "We are not willing or obligated to participate in dispute resolution procedures before a consumer arbitration board.",
    "imp.contents": "Liability for content",
    "imp.contents1": "As a service provider, we are responsible for our own content on these pages under the general laws pursuant to § 7 (1) TMG. According to §§ 8 to 10 TMG, however, we are not obliged to monitor transmitted or stored third-party information or to investigate circumstances that indicate illegal activity.",
    "imp.contents2": "Obligations to remove or block the use of information under the general laws remain unaffected. Liability in this respect is only possible from the moment we become aware of a specific infringement. When we become aware of such infringements, we will remove the content immediately.",
    "imp.links": "Liability for links",
    "imp.links1": "Our offer contains links to external websites of third parties, over whose content we have no influence. We therefore cannot assume any liability for this third-party content. The respective provider or operator of the pages is always responsible for the content of the linked pages. The linked pages were checked for possible legal violations at the time of linking. Illegal content was not recognizable at the time of linking.",
    "imp.links2": "Permanent monitoring of the content of the linked pages is not reasonable without concrete evidence of a legal violation. When we become aware of legal violations, we will remove such links immediately.",
    "imp.copy": "Copyright",
    "imp.copy1": "The content and works created by the site operator on these pages are subject to German copyright law. Reproduction, editing, distribution, and any kind of use beyond the limits of copyright law require the written consent of the respective author or creator. Downloads and copies of this page are permitted only for private, non-commercial use.",
    "imp.copy2": "Where content on this page was not created by the operator, the copyrights of third parties are respected. Third-party content in particular is marked as such. Should you nevertheless notice a copyright infringement, please tell us. When we become aware of legal violations, we will remove such content immediately.",
    "imp.back": "← Back to Flow"
  };

  var pages = {
    home: {
      de: {
        title: "Flow – Diktat in der Menüleiste · von Sinthex",
        description: "Flow ist eine Diktier-App für die Menüleiste auf dem Mac. Die Aufnahme bleibt auf dem Mac, Whisper läuft lokal. Eine Korrektur über OpenAI ist optional und nutzt den eigenen Schlüssel. Von Sinthex, MIT-Lizenz.",
        ogTitle: "Flow – Diktat in der Menüleiste",
        ogDescription: "Fn halten, sprechen, loslassen. Whisper lokal auf Apple Silicon, Korrektur optional mit eigenem Schlüssel. Von Sinthex.",
        ogLocale: "de_DE"
      },
      en: {
        title: "Flow – Dictation in the menu bar · by Sinthex",
        description: "Flow is a menu-bar dictation app for the Mac. Recording stays on the Mac, Whisper runs locally. Correction through OpenAI is optional and uses your own key. By Sinthex, MIT license.",
        ogTitle: "Flow – Dictation in the menu bar",
        ogDescription: "Hold Fn, speak, let go. Whisper locally on Apple Silicon, optional correction with your own key. By Sinthex.",
        ogLocale: "en_US"
      }
    },
    impressum: {
      de: {
        title: "Impressum | Sinthex",
        description: "Impressum der Sinthex Holding UG (haftungsbeschränkt), Kircheib: Anbieterkennzeichnung, Kontakt und Pflichtangaben.",
        ogTitle: "Impressum | Sinthex",
        ogDescription: "Impressum der Sinthex Holding UG (haftungsbeschränkt), Kircheib.",
        ogLocale: "de_DE"
      },
      en: {
        title: "Legal notice | Sinthex",
        description: "Legal notice of Sinthex Holding UG (haftungsbeschränkt), Kircheib: provider identification, contact and mandatory information.",
        ogTitle: "Legal notice | Sinthex",
        ogDescription: "Legal notice of Sinthex Holding UG (haftungsbeschränkt), Kircheib.",
        ogLocale: "en_US"
      }
    },
    changelog: {
      de: {
        title: "ChangeLog · Flow",
        description: "Alle veröffentlichten Versionen von Flow. Jeder Eintrag ist als Neu, Verbesserung, Bugfix oder Sonstiges gekennzeichnet.",
        ogTitle: "ChangeLog · Flow",
        ogDescription: "Alle Versionen von Flow, mit Kennzeichnung.",
        ogLocale: "de_DE"
      },
      en: {
        title: "Changelog · Flow",
        description: "Every released version of Flow. Each entry is marked as new, an improvement, a bugfix, or other.",
        ogTitle: "Changelog · Flow",
        ogDescription: "Every version of Flow, with labels.",
        ogLocale: "en_US"
      }
    }
  };

  document.documentElement.lang = lang;

  document.querySelectorAll("[data-set-lang]").forEach(function (link) {
    var on = link.getAttribute("data-set-lang") === lang;
    link.classList.toggle("is-active", on);
    if (on) link.setAttribute("aria-current", "true");
    else link.removeAttribute("aria-current");
  });

  document.querySelectorAll("[data-external-lang]").forEach(function (link) {
    var url = new URL(link.getAttribute("href"), location.origin);
    url.searchParams.set("lang", lang);
    link.href = url.toString();
  });

  var page = document.documentElement.getAttribute("data-page") || "home";
  var meta = (pages[page] || pages.home)[lang];
  if (meta) {
    document.title = meta.title;
    var description = document.querySelector('meta[name="description"]');
    if (description) description.setAttribute("content", meta.description);
    function setMeta(sel, attr, value) {
      var el = document.querySelector(sel);
      if (el && value) el.setAttribute(attr, value);
    }
    setMeta('meta[property="og:title"]', "content", meta.ogTitle || meta.title);
    setMeta('meta[property="og:description"]', "content", meta.ogDescription || meta.description);
    setMeta('meta[property="og:locale"]', "content", meta.ogLocale);
    setMeta('meta[name="twitter:title"]', "content", meta.ogTitle || meta.title);
    setMeta('meta[name="twitter:description"]', "content", meta.ogDescription || meta.description);
  }

  if (lang !== "en") return;

  document.querySelectorAll("[data-i18n]").forEach(function (el) {
    var value = en[el.getAttribute("data-i18n")];
    if (value != null) el.textContent = value;
  });

  document.querySelectorAll("[data-i18n-html]").forEach(function (el) {
    var value = en[el.getAttribute("data-i18n-html")];
    if (value != null) el.innerHTML = value;
  });

  document.querySelectorAll("[data-i18n-attr]").forEach(function (el) {
    el.getAttribute("data-i18n-attr").split("|").forEach(function (pair) {
      var parts = pair.split(":");
      var attr = parts[0];
      var key = parts.slice(1).join(":");
      if (en[key] != null) el.setAttribute(attr, en[key]);
    });
  });

  document.querySelectorAll("[data-label='Lizenz']").forEach(function (el) {
    el.setAttribute("data-label", "License");
  });
})();
