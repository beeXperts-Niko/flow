---
description: Flow-Version veröffentlichen — ChangeLog, Webseite, Sprachen, Screenshots, Download und Auto-Updater
---

# deployVersion

Veröffentliche die Flow-Version, die in `packaging/Info.plist` steht, auf https://sinthex.de/flow/. Download und Auto-Updater lesen dieselbe Fassung: die Seite verlinkt `Flow-<version>.pkg`, `../flow-site/latest.json` zeigt auf die absolute Paket-URL.

Nicht committen und nicht pushen, außer der Nutzer hat das in derselben Anfrage verlangt.

Arbeite die Schritte in dieser Reihenfolge ab. Einen Schritt, der schon stimmt, nicht doppelt anlegen.

## 1. Version festlegen

- Lokal: `CFBundleShortVersionString` und `CFBundleVersion` in `packaging/Info.plist`.
- Live: `curl -fsS https://sinthex.de/flow/latest.json`.
- Vergleiche wie `UpdateCheck.isNewer`: numerisch je Komponente.

Ist die lokale Version neuer als die live Version, diese lokale Version veröffentlichen. Nicht noch einmal anheben.

Ist sie gleich und die Arbeitskopie hat keine unveröffentlichten, für Nutzer sichtbaren Änderungen, stoppen und sagen, dass diese Version schon online ist.

Ist sie gleich und es gibt sichtbare Änderungen, die online noch nicht im ChangeLog stehen, zuerst anheben: Patch für Fix, Text, Layout. Minor für eine neue Fähigkeit, Patch auf 0. Major nur, wenn der Nutzer das ausdrücklich verlangt. `CFBundleVersion` um 1 erhöhen. `engine/pyproject.toml` nur anfassen, wenn sich eine Engine-Datei geändert hat.

Ist die lokale Version älter als die live Version, stoppen.

## 2. ChangeLog

Texte aus der sichtbaren Differenz seit der live Version. Kurz, in der Sprache der bestehenden Einträge. Jeder Punkt ist genau eine Art:

| Art | Klasse | Schlüssel | Deutsch | Englisch |
| --- | --- | --- | --- | --- |
| Neu | `change-kind-new` | `log.kind.new` | Neu | New |
| Verbesserung | `change-kind-improve` | `log.kind.improve` | Verbesserung | Improvement |
| Bugfix | `change-kind-fix` | `log.kind.fix` | Bugfix | Bugfix |
| Sonstiges | `change-kind-other` | `log.kind.other` | Sonstiges | Other |

Schlüssel einer Version: Punkte streichen, alle drei Komponenten behalten. `1.8.0` wird `v180`, `1.8.1` wird `v181`, `1.10.2` wird `v1102`. Datumsschlüssel `log.v180date`, Punkte `log.v180.<kurzesEnglischesWort>`.

Datum heute. Deutsch im HTML: `28. September 2026`, `datetime="2026-09-28"`. Englisch in `../flow-site/i18n.js`: `September 28, 2026`. In `../flow-site/changelog.md`: `28 September 2026`.

Neueste Version zuerst, an diesen Stellen:

- `../flow-site/changelog.html`: vollständiger Verlauf. Sichtbarer Text Deutsch, `data-i18n` auf die Schlüssel. Aufbau wie der bestehende `<article class="version">`.
- `../flow-site/i18n.js`: englische Zeichenketten derselben Schlüssel, im Objekt `en`, bei den anderen `log.v…`-Schlüsseln.
- `../flow-site/changelog.md`: vollständiger Verlauf auf Englisch, mit **New**, **Improvement**, **Bugfix**, **Other**.
- `../flow-site/index.html`, Block `#aenderungen`: die aktuelle Version, danach ältere Versionen, die mindestens einen Punkt der Art Neu haben, bis drei Artikel dastehen. Die aktuelle Version steht auch dann ganz oben, wenn sie keinen Neu-Punkt hat. Bugfix- und Sonstiges-Versionen bleiben im vollständigen ChangeLog.
- `../flow-site/index.md`, Abschnitt „Changelog (latest features)“: dieselben drei Versionen, je eine englische Zeile.

## 3. Webseite auf diese Version stellen

Überall, wo die herunterladbare Fassung genannt wird, auf `Flow-<version>.pkg` und die Versionsnummer zeigen. Historische Versionsnummern im ChangeLog bleiben.

Mindestens:

- `../flow-site/index.html`: JSON-LD `softwareVersion`, `downloadUrl`, `installUrl`, Offer-URL, FAQ-Antwort, Download-Links in Kopf, Hero und Installer-Abschnitt, Satz „Flow <version> legt die App…“, `dateModified`
- `../flow-site/changelog.html` und `../flow-site/impressum.html`: Download-Link im Kopf
- `../flow-site/i18n.js`: `start.pkgBody`, `start.pkgBtn`, `faq.a6`
- `../flow-site/index.md`, `../flow-site/changelog.md`, `../flow-site/llms.txt`: aktuelle Version und Paket-URL
- `../flow-site/latest.json`: `version` und `pkg` als `https://sinthex.de/flow/Flow-<version>.pkg`
- `../flow-site/sitemap.xml`: `lastmod` der geänderten URLs

Wenn `../flow-site/i18n.js` sich ändert, `i18n.js?v=` in `index.html`, `changelog.html` und `impressum.html` um 1 erhöhen. Dieselbe Zahl an allen drei Stellen.

In `../flow-site/.htaccess` muss `latest.json` ungecacht ausgeliefert werden. Fehlt der Block, ergänzen:

```apache
<Files "latest.json">
  Header set Cache-Control "no-cache, no-store, must-revalidate"
</Files>
```

## 4. Sprachdateien

`Languages/en.json` ist die Schlüsselliste. Jede `Languages/*.json` braucht dieselben Schlüssel, gleiche Reihenfolge, Einrückung wie `en.json`. Schlüssel mit `_` zählen nicht.

Neue oder geänderte Schlüssel: `de.json` auf Deutsch schreiben. Jede andere Datei in ihrer Sprache übersetzen. `%@`, `%ld` und `%.1f` bleiben an derselben Stelle stehen. Keine Schlüssel löschen, keine neuen erfinden.

Berechtigungsdialoge nur anfassen, wenn sich `NSMicrophoneUsageDescription` oder `NSAppleEventsUsageDescription` geändert hat. Die stehen in `packaging/<code>.lproj/InfoPlist.strings`, nicht in JSON.

Vor dem Paketbau prüfen, dass keine Datei Schlüssel vermisst oder zusätzlich hat.

## 5. Screenshots prüfen

Entscheiden, nicht pauschal neu aufnehmen. Ein Bild wird ersetzt, wenn diese Version darauf etwas ändert, das ein Besucher sieht: Layout, Beschriftung, Steuerung, Farbe, Symbol. Ein Fix hinter demselben Bild bleibt liegen. Die Entscheidung am Ende nennen: welches Bild neu ist und welches bleibt, jeweils mit dem Grund.

| Oberfläche | Webseite | Doku |
| --- | --- | --- |
| `HomeView` | `../flow-site/assets/start.png` | `docs/screenshots/main-home.png` |
| `MenuBarView`, Statussymbol, Update-Pfeil, Aufnahme-Orange | `../flow-site/assets/menueleiste.png` | `docs/screenshots/menubar.png` |
| Aufnahme-Pille in `Overlay` | `../flow-site/assets/aufnahme-pille.png` | `docs/screenshots/overlay-listening.png` |
| Widget in `Overlay` | `../flow-site/assets/widget.png` | `docs/screenshots/widget-expanded.png` |
| Stil-Karten in `StyleView` | `../flow-site/assets/stil.png` | `docs/screenshots/main-style.png` |
| Stil pro Programm | `../flow-site/assets/stil-pro-programm.png` | `docs/screenshots/main-style-full.png` |
| `OnboardingView` | `../flow-site/assets/willkommen.png` | `docs/screenshots/onboarding.png` |
| `DictionaryView` | `../flow-site/assets/woerterbuch.png` | `docs/screenshots/main-dictionary.png` |
| `HistoryView` | `../flow-site/assets/verlauf.png` | `docs/screenshots/main-history.png` |
| `SettingsView` | `../flow-site/assets/einstellungen.png` | `docs/screenshots/main-settings-full.png` |

Nur die betroffenen Paare neu aufnehmen. Pixelmaße der bestehenden Datei beibehalten (`sips -g pixelWidth -g pixelHeight`). Ändert sich die Größe, `width` und `height` in `../flow-site/index.html` mitziehen.

Aufnahme, wenn sie nötig ist: `./scripts/build_app.sh`, laufendes Flow beenden, `open dist/Flow.app`, Fenster mit `screencapture -l <fensterId> -o` ohne Schatten aufnehmen, App beenden. Dieselbe Aufnahme in beide Dateien des Paares legen. Die Fenster-ID der Flow-Fenster über Quartz `CGWindowListCopyWindowInfo` holen.

## 6. Paket bauen und online stellen

Sprachdateien und Screenshots sind vorher fertig. Dann:

```bash
./scripts/make_pkg.sh
./scripts/publish_site.sh
```

`publish_site.sh` lädt `../flow-site/` nach `sinthex:hosting/sinthex.de/flow/` und dazu `dist/Flow-<version>.pkg`. Ältere Pakete auf dem Server bleiben. Das Skript bricht ab, wenn `latest.json`, die Sprachschlüssel oder die Paketgröße nicht zur Version passen.

## 7. Prüfen

Das Skript prüft Feed, Paketgröße und den Download-Link auf der Startseite. Zusätzlich die live Seite im Browser öffnen und durchklicken:

- https://sinthex.de/flow/ — Hero- und Installer-Link laden `Flow-<version>.pkg`
- der ChangeLog-Block zeigt die neue Version
- https://sinthex.de/flow/changelog.html zeigt denselben Eintrag
- https://sinthex.de/flow/latest.json hat `version` und die absolute `pkg`-URL

Danach kurz sagen: Version, ob Screenshots neu sind, und dass Download und Auto-Updater auf dieses Paket zeigen.
