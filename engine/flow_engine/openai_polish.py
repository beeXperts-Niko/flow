"""Korrektur über eine OpenAI-kompatible Chat-API. Der Schlüssel kommt pro Anfrage und wird nicht gespeichert."""

from __future__ import annotations

import hashlib
import json
import re
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_OPENAI_MODEL = "gpt-5.6-luna"
DEFAULT_BASE_URL = "https://api.openai.com/v1"
_CACHE_TTL = 6 * 60 * 60

# Schnelle Stufen, von schnell nach langsamer. Neuere Generationen gewinnen,
# innerhalb einer Generation die schnellste Stufe.
_FAST = {"nano": 0, "luna": 1, "mini": 2}
_SLOW = {"terra": 6, "pro": 7, "sol": 8, "astra": 9}
_CHAT = re.compile(
    r"^gpt-"
    r"(?P<major>\d+)"
    r"(?:\.(?P<minor>\d+))?"
    r"(?P<omni>o)?"
    r"(?:-(?P<tier>nano|luna|mini|terra|sol|astra|pro))?"
    r"(?:-(?P<date>\d{4}-\d{2}-\d{2}))?"
    r"$"
)


class _Choice:
    def __init__(self) -> None:
        self.fingerprint = ""
        self.fetched = 0.0
        self.model = ""
        self.models: list[str] = []


_choice = _Choice()
_choice_lock = threading.Lock()


def normalize_base_url(raw: str | None) -> str:
    """Basisadresse ohne abschließenden Schrägstrich. Leer bleibt die OpenAI-Adresse."""
    text = (raw or "").strip()
    if not text:
        return DEFAULT_BASE_URL
    for suffix in ("/chat/completions", "/completions", "/models"):
        if text.rstrip("/").endswith(suffix):
            text = text.rstrip("/")[: -len(suffix)]
    parsed = urllib.parse.urlparse(text.strip())
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise RuntimeError("Die API-Adresse muss mit http:// oder https:// beginnen")
    path = parsed.path.rstrip("/")
    if path in ("", "/"):
        path = "/v1"
    return urllib.parse.urlunparse((parsed.scheme, parsed.netloc, path, "", "", ""))


def is_openai_base(base: str) -> bool:
    return (urllib.parse.urlparse(base).hostname or "").lower() == "api.openai.com"


def reset_model_cache() -> None:
    with _choice_lock:
        _choice.fingerprint = ""
        _choice.fetched = 0.0
        _choice.model = ""
        _choice.models = []


def choose_model(models: list[dict]) -> str:
    """Neuestes schnelles Chat-Modell. Nano vor Luna vor Mini, neuere Generation davor."""
    fast = []
    rest = []
    for item in models:
        parsed = _parse_model(item)
        if parsed is None:
            continue
        if parsed[2] in _FAST:
            fast.append(parsed)
        else:
            rest.append(parsed)
    pool = fast or rest
    if pool:
        pool.sort(key=_rank)
        return pool[0][0]
    generic = listed_ids(models)
    if not generic:
        raise RuntimeError("Kein passendes Korrekturmodell")
    return generic[0]


def rank_models(models: list[dict]) -> list[str]:
    """Chat-Modelle, neueste Generation zuerst, darin die schnellste Stufe. Datierte Snapshots entfallen, wenn es den Alias gibt."""
    parsed = [item for item in (_parse_model(model) for model in models) if item is not None]
    undated = {(version, tier) for _model_id, version, tier, dated, _created in parsed if not dated}
    kept = [
        item
        for item in parsed
        if not (item[3] and (item[1], item[2]) in undated)
    ]
    kept.sort(key=_rank)
    seen: set[str] = set()
    ranked: list[str] = []
    for model_id, *_rest in kept:
        if model_id in seen:
            continue
        seen.add(model_id)
        ranked.append(model_id)
    return ranked or listed_ids(models)


def model_catalog(
    api_key: str,
    opener=urllib.request.urlopen,
    now: float | None = None,
    base_url: str = "",
) -> tuple[str, list[str]]:
    base = normalize_base_url(base_url)
    key = api_key.strip()
    if is_openai_base(base) and not key:
        raise RuntimeError("OpenAI-Schlüssel fehlt")
    fingerprint = hashlib.sha256(f"{base}\n{key}".encode()).hexdigest()[:16]
    moment = time.monotonic() if now is None else now
    with _choice_lock:
        if (
            _choice.fingerprint == fingerprint
            and _choice.model
            and _choice.models
            and moment - _choice.fetched < _CACHE_TTL
        ):
            return _choice.model, list(_choice.models)
    data = fetch_models(key, opener, base)
    recommended = choose_model(data)
    ranked = rank_models(data)
    with _choice_lock:
        _choice.fingerprint = fingerprint
        _choice.fetched = moment
        _choice.model = recommended
        _choice.models = ranked
    return recommended, ranked


def resolve_model(
    api_key: str,
    opener=urllib.request.urlopen,
    now: float | None = None,
    base_url: str = "",
) -> str:
    recommended, _ranked = model_catalog(api_key, opener, now, base_url)
    return recommended


def fetch_models(api_key: str, opener=urllib.request.urlopen, base_url: str = "") -> list[dict]:
    base = normalize_base_url(base_url)
    request = urllib.request.Request(
        f"{base}/models",
        headers=_headers(api_key, json_body=False),
        method="GET",
    )
    try:
        with opener(request, timeout=20) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(_redact(error_message(raw, exc.code, base), api_key)) from None
    except urllib.error.URLError as exc:
        raise RuntimeError(f"{_label(base)} nicht erreichbar: {exc.reason}") from None
    data = payload.get("data")
    if not isinstance(data, list):
        raise RuntimeError(f"{_label(base)} hat keine Modellliste geliefert")
    return data


def complete(
    messages: list[dict[str, str]],
    model: str,
    api_key: str,
    max_tokens: int,
    opener=urllib.request.urlopen,
    base_url: str = "",
) -> str:
    base = normalize_base_url(base_url)
    key = api_key.strip()
    if is_openai_base(base) and not key:
        raise RuntimeError("OpenAI-Schlüssel fehlt")
    chosen = model.strip()
    if not chosen or chosen == "auto":
        chosen = resolve_model(key, opener, base_url=base)
    if is_openai_base(base):
        modern = _generation(chosen) >= 5
        try:
            return _post(
                chosen, messages, max_tokens, key, opener, base,
                effort=modern, temperature=not modern, token_field="max_completion_tokens",
            )
        except RuntimeError as exc:
            if not modern or "reasoning_effort" not in str(exc).lower():
                raise
            return _post(
                chosen, messages, max_tokens, key, opener, base,
                effort=False, temperature=True, token_field="max_completion_tokens",
            )
    try:
        return _post(
            chosen, messages, max_tokens, key, opener, base,
            effort=False, temperature=True, token_field="max_tokens",
        )
    except RuntimeError as exc:
        if "max_tokens" not in str(exc).lower():
            raise
        return _post(
            chosen, messages, max_tokens, key, opener, base,
            effort=False, temperature=False, token_field="max_completion_tokens",
        )


def _post(
    model: str,
    messages: list[dict[str, str]],
    max_tokens: int,
    api_key: str,
    opener,
    base: str,
    *,
    effort: bool,
    temperature: bool,
    token_field: str,
) -> str:
    payload: dict = {
        "model": model,
        token_field: max_tokens,
        "messages": messages,
    }
    if effort:
        payload["reasoning_effort"] = "none"
    if temperature:
        payload["temperature"] = 0.2
    request = urllib.request.Request(
        f"{base}/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers=_headers(api_key, json_body=True),
        method="POST",
    )
    timeout = 45 if is_openai_base(base) else 90
    try:
        with opener(request, timeout=timeout) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(_redact(error_message(raw, exc.code, base), api_key)) from None
    except urllib.error.URLError as exc:
        raise RuntimeError(f"{_label(base)} nicht erreichbar: {exc.reason}") from None
    return message_text(body)


def _headers(api_key: str, *, json_body: bool) -> dict[str, str]:
    headers: dict[str, str] = {}
    if json_body:
        headers["Content-Type"] = "application/json"
    key = api_key.strip()
    if key:
        headers["Authorization"] = f"Bearer {key}"
    return headers


def _label(base: str) -> str:
    return "OpenAI" if is_openai_base(base) else "Korrektur-API"


_SKIP_ID = ("embed", "whisper", "tts", "dall-e", "moderation", "audio", "image", "realtime", "transcribe")


def listed_ids(models: list[dict]) -> list[str]:
    """Modellnamen, die keine Embeddings oder Erkennung sind. Reihenfolge der API bleibt."""
    ids: list[str] = []
    seen: set[str] = set()
    for item in models:
        model_id = str(item.get("id") or "").strip()
        if not model_id or model_id in seen:
            continue
        folded = model_id.lower()
        if any(part in folded for part in _SKIP_ID):
            continue
        seen.add(model_id)
        ids.append(model_id)
    return ids


def _parse_model(item: dict) -> tuple[str, tuple[int, int], str | None, bool, int] | None:
    model_id = str(item.get("id") or "")
    match = _CHAT.fullmatch(model_id)
    if match is None:
        return None
    major = int(match.group("major"))
    minor = int(match.group("minor") or 0)
    tier = match.group("tier")
    created = int(item.get("created") or 0)
    return model_id, (major, minor), tier, bool(match.group("date")), created


def _rank(parsed: tuple[str, tuple[int, int], str | None, bool, int]) -> tuple:
    _model_id, version, tier, dated, created = parsed
    speed = _FAST.get(tier, _SLOW.get(tier, 5))
    return (-version[0], -version[1], speed, 1 if dated else 0, -created)


def _generation(model: str) -> int:
    match = re.match(r"gpt-(\d+)", model)
    return int(match.group(1)) if match else 0


def message_text(payload: dict) -> str:
    choices = payload.get("choices") or []
    if not choices:
        raise RuntimeError("Die Korrektur hat keine Antwort geliefert")
    content = (choices[0].get("message") or {}).get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict):
                parts.append(str(item.get("text") or ""))
        return "".join(parts)
    return ""


def error_message(raw: str, status: int, base: str = "") -> str:
    label = _label(normalize_base_url(base)) if base else "OpenAI"
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return f"{label} HTTP {status}"
    error = payload.get("error")
    if isinstance(error, dict) and error.get("message"):
        return f"{label}: {error['message']}"
    return f"{label} HTTP {status}"


def _redact(text: str, secret: str) -> str:
    if secret and secret in text:
        return text.replace(secret, "…")
    return text
