"""Spracherkennung mit mlx-whisper, ohne ffmpeg."""

from __future__ import annotations

import io
import wave

import numpy as np


def wav_to_audio(wav: bytes) -> np.ndarray:
    with wave.open(io.BytesIO(wav), "rb") as handle:
        channels = handle.getnchannels()
        sample_width = handle.getsampwidth()
        rate = handle.getframerate()
        frames = handle.readframes(handle.getnframes())
    if sample_width != 2:
        raise ValueError("Audio muss 16-bit PCM sein")
    audio = np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0
    if channels > 1:
        audio = audio.reshape(-1, channels).mean(axis=1)
    if rate != 16000 and len(audio) > 1:
        target = max(1, int(len(audio) * 16000 / rate))
        source_x = np.linspace(0.0, 1.0, num=len(audio), endpoint=False)
        target_x = np.linspace(0.0, 1.0, num=target, endpoint=False)
        audio = np.interp(target_x, source_x, audio).astype(np.float32)
    return np.ascontiguousarray(audio)


def write_silence(seconds: float = 0.4, sample_rate: int = 16000) -> bytes:
    frames = int(seconds * sample_rate)
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(b"\x00\x00" * frames)
    return buffer.getvalue()


def transcribe_wav(
    wav: bytes,
    model_id: str,
    language: str,
    initial_prompt: str,
) -> tuple[str, str]:
    import mlx_whisper

    options: dict = {
        "path_or_hf_repo": model_id,
        "verbose": False,
        "condition_on_previous_text": False,
        # One greedy pass. A temperature ladder decodes the clip again when the
        # first pass looks uncertain, which is the pause after the words are known.
        # mlx-whisper has no beam search: any beam_size, including 1, raises
        # NotImplementedError. Leaving it unset keeps the greedy decoder.
        "temperature": 0.0,
        "without_timestamps": True,
        "word_timestamps": False,
    }
    if language and language != "auto":
        options["language"] = language
    prompt = initial_prompt.strip()
    if prompt:
        options["initial_prompt"] = prompt[:800]
    result = mlx_whisper.transcribe(wav_to_audio(wav), **options)

    segments = result.get("segments") or []
    if segments and all(float(segment.get("no_speech_prob", 0)) >= 0.7 for segment in segments):
        return "", result.get("language") or ""
    text = (result.get("text") or "").strip()
    return text, result.get("language") or ""


# Nach ein paar Minuten Ruhe schiebt macOS die Gewichte aus dem schnellen Speicher.
# Ein erneuter Durchlauf ist dann teuer; kurz danach ist er wieder schnell.
WARM_INTERVAL = 45.0


def needs_warmup(last_touch: float, now: float, interval: float = WARM_INTERVAL) -> bool:
    return (now - last_touch) >= interval


def warmup(model_id: str) -> None:
    transcribe_wav(write_silence(), model_id, "de", "")
