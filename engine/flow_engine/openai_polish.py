"""Korrektur über die OpenAI-Chat-API. Der Schlüssel kommt pro Anfrage und wird nicht gespeichert."""

from __future__ import annotations

import hashlib
import json
import re
import threading
import time
import urllib.error
import urllib.request

DEFAULT_OPENAI_MODEL = "gpt-5.6-luna"
API_URL = "https://api.openai.com/v1/chat/completions"
MODELS_URL = "https://api.openai.com/v1/models"
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
    if not pool:
        raise RuntimeError("Kein passendes Korrekturmodell für diesen Schlüssel")
    pool.sort(key=_rank)
    return pool[0][0]


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
    return ranked


def model_catalog(
    api_key: str, opener=urllib.request.urlopen, now: float | None = None
) -> tuple[str, list[str]]:
    key = api_key.strip()
    if not key:
        raise RuntimeError("OpenAI-Schlüssel fehlt")
    fingerprint = hashlib.sha256(key.encode()).hexdigest()[:16]
    moment = time.monotonic() if now is None else now
    with _choice_lock:
        if (
            _choice.fingerprint == fingerprint
            and _choice.model
            and _choice.models
            and moment - _choice.fetched < _CACHE_TTL
        ):
            return _choice.model, list(_choice.models)
    data = fetch_models(key, opener)
    recommended = choose_model(data)
    ranked = rank_models(data)
    with _choice_lock:
        _choice.fingerprint = fingerprint
        _choice.fetched = moment
        _choice.model = recommended
        _choice.models = ranked
    return recommended, ranked


def resolve_model(api_key: str, opener=urllib.request.urlopen, now: float | None = None) -> str:
    recommended, _ranked = model_catalog(api_key, opener, now)
    return recommended


def fetch_models(api_key: str, opener=urllib.request.urlopen) -> list[dict]:
    request = urllib.request.Request(
        MODELS_URL,
        headers={"Authorization": f"Bearer {api_key}"},
        method="GET",
    )
    try:
        with opener(request, timeout=20) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(_redact(error_message(raw, exc.code), api_key)) from None
    except urllib.error.URLError as exc:
        raise RuntimeError(f"OpenAI nicht erreichbar: {exc.reason}") from None
    data = payload.get("data")
    if not isinstance(data, list):
        raise RuntimeError("OpenAI hat keine Modellliste geliefert")
    return data


def complete(
    messages: list[dict[str, str]],
    model: str,
    api_key: str,
    max_tokens: int,
    opener=urllib.request.urlopen,
) -> str:
    key = api_key.strip()
    if not key:
        raise RuntimeError("OpenAI-Schlüssel fehlt")
    chosen = model.strip()
    if not chosen or chosen == "auto":
        chosen = resolve_model(key, opener)
    modern = _generation(chosen) >= 5
    try:
        return _post(chosen, messages, max_tokens, key, opener, effort=modern, temperature=not modern)
    except RuntimeError as exc:
        if not modern or "reasoning_effort" not in str(exc).lower():
            raise
        return _post(chosen, messages, max_tokens, key, opener, effort=False, temperature=True)


def _post(
    model: str,
    messages: list[dict[str, str]],
    max_tokens: int,
    api_key: str,
    opener,
    *,
    effort: bool,
    temperature: bool,
) -> str:
    payload: dict = {
        "model": model,
        "max_completion_tokens": max_tokens,
        "messages": messages,
    }
    if effort:
        payload["reasoning_effort"] = "none"
    if temperature:
        payload["temperature"] = 0.2
    request = urllib.request.Request(
        API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with opener(request, timeout=45) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(_redact(error_message(raw, exc.code), api_key)) from None
    except urllib.error.URLError as exc:
        raise RuntimeError(f"OpenAI nicht erreichbar: {exc.reason}") from None
    return message_text(body)


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
        raise RuntimeError("OpenAI hat keine Antwort geliefert")
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


def error_message(raw: str, status: int) -> str:
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return f"OpenAI HTTP {status}"
    error = payload.get("error")
    if isinstance(error, dict) and error.get("message"):
        return f"OpenAI: {error['message']}"
    return f"OpenAI HTTP {status}"


def _redact(text: str, secret: str) -> str:
    if secret and secret in text:
        return text.replace(secret, "…")
    return text
