import io
import json
import unittest
import urllib.error

from flow_engine.openai_polish import (
    choose_model,
    complete,
    error_message,
    message_text,
    rank_models,
    reset_model_cache,
    resolve_model,
)


class _Body:
    def __init__(self, payload: bytes):
        self.payload = payload

    def read(self) -> bytes:
        return self.payload

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


def _model(model_id: str, created: int = 0) -> dict:
    return {"id": model_id, "created": created}


class OpenAIPolishTests(unittest.TestCase):
    def setUp(self):
        reset_model_cache()

    def test_message_text_reads_string_and_parts(self):
        self.assertEqual(
            message_text({"choices": [{"message": {"content": "Hallo."}}]}),
            "Hallo.",
        )
        self.assertEqual(
            message_text({"choices": [{"message": {"content": [{"text": "Hallo"}, {"text": " Welt"}]}}]}),
            "Hallo Welt",
        )

    def test_error_message_uses_api_text(self):
        raw = json.dumps({"error": {"message": "invalid api key"}})
        self.assertEqual(error_message(raw, 401), "OpenAI: invalid api key")

    def test_complete_posts_without_putting_the_key_in_the_body(self):
        def opener(request, timeout):
            self.assertEqual(timeout, 45)
            self.assertEqual(request.get_header("Authorization"), "Bearer secret-key")
            self.assertNotIn(b"secret-key", request.data)
            self.assertNotIn("secret-key", request.full_url)
            return _Body(b'{"choices":[{"message":{"content":"Morgen um zehn."}}]}')

        text = complete(
            [{"role": "user", "content": "roher text"}],
            "gpt-4.1-mini",
            "secret-key",
            40,
            opener=opener,
        )
        self.assertEqual(text, "Morgen um zehn.")

    def test_missing_key_does_not_call_the_network(self):
        def opener(request, timeout):
            raise AssertionError("Netz wurde aufgerufen")

        with self.assertRaisesRegex(RuntimeError, "fehlt"):
            complete([{"role": "user", "content": "x"}], "gpt-4.1-mini", "  ", 20, opener=opener)

    def test_http_error_is_redacted(self):
        def opener(request, timeout):
            raise urllib.error.HTTPError(
                request.full_url,
                401,
                "Unauthorized",
                hdrs=None,
                fp=io.BytesIO(b'{"error":{"message":"rejected secret-key"}}'),
            )

        with self.assertRaises(RuntimeError) as caught:
            complete(
                [{"role": "user", "content": "x"}],
                "gpt-4.1-mini",
                "secret-key",
                20,
                opener=opener,
            )
        self.assertNotIn("secret-key", str(caught.exception))
        self.assertIn("rejected", str(caught.exception))

    def test_choose_model_picks_newest_fast_tier(self):
        chosen = choose_model(
            [
                _model("whisper-large-v3"),
                _model("gpt-5.6-sol", 50),
                _model("gpt-6-astra", 90),
                _model("gpt-5-nano", 40),
                _model("gpt-5.6-luna-2026-07-30", 80),
                _model("gpt-5.6-mini", 70),
                _model("gpt-5.6-luna", 60),
                _model("gpt-4.1-mini", 10),
                _model("ft:gpt-4.1-mini", 99),
                _model("o3", 100),
            ]
        )
        self.assertEqual(chosen, "gpt-5.6-luna")

    def test_choose_model_prefers_nano_inside_the_same_generation(self):
        chosen = choose_model(
            [
                _model("gpt-5.6-luna", 2),
                _model("gpt-5.6-nano", 1),
                _model("gpt-5.6-mini", 3),
            ]
        )
        self.assertEqual(chosen, "gpt-5.6-nano")

    def test_choose_model_newer_generation_beats_an_older_nano(self):
        chosen = choose_model([_model("gpt-5-nano", 9), _model("gpt-5.6-luna", 1)])
        self.assertEqual(chosen, "gpt-5.6-luna")

    def test_choose_model_falls_back_when_no_fast_tier_exists(self):
        chosen = choose_model([_model("gpt-6-astra", 2), _model("gpt-6-sol", 1), _model("gpt-5.6-sol", 9)])
        self.assertEqual(chosen, "gpt-6-sol")

    def test_rank_models_lists_alternatives_and_skips_dated_snapshots(self):
        ranked = rank_models(
            [
                _model("whisper-1"),
                _model("gpt-5.6-luna-2026-07-30", 80),
                _model("gpt-5.6-luna", 60),
                _model("gpt-5.6-sol", 70),
                _model("gpt-4.1-mini", 10),
                _model("gpt-5-nano", 40),
            ]
        )
        self.assertEqual(ranked[0], "gpt-5.6-luna")
        self.assertIn("gpt-5.6-sol", ranked)
        self.assertIn("gpt-4.1-mini", ranked)
        self.assertNotIn("gpt-5.6-luna-2026-07-30", ranked)
        self.assertNotIn("whisper-1", ranked)

    def test_resolve_model_reads_the_list_and_caches_it(self):
        calls = {"n": 0}

        def opener(request, timeout):
            calls["n"] += 1
            self.assertEqual(timeout, 20)
            self.assertIn("/v1/models", request.full_url)
            self.assertEqual(request.get_header("Authorization"), "Bearer secret-key")
            body = json.dumps({"data": [_model("gpt-5.6-sol", 2), _model("gpt-5.6-luna", 1)]}).encode()
            return _Body(body)

        self.assertEqual(resolve_model("secret-key", opener=opener, now=100), "gpt-5.6-luna")
        self.assertEqual(resolve_model("secret-key", opener=opener, now=200), "gpt-5.6-luna")
        self.assertEqual(calls["n"], 1)

    def test_modern_model_asks_for_no_reasoning(self):
        def opener(request, timeout):
            payload = json.loads(request.data)
            self.assertEqual(payload["model"], "gpt-5.6-luna")
            self.assertEqual(payload["reasoning_effort"], "none")
            self.assertNotIn("temperature", payload)
            return _Body(b'{"choices":[{"message":{"content":"Klar."}}]}')

        text = complete([{"role": "user", "content": "x"}], "gpt-5.6-luna", "secret-key", 40, opener=opener)
        self.assertEqual(text, "Klar.")

    def test_rejected_reasoning_effort_is_retried_without_it(self):
        calls = {"n": 0}

        def opener(request, timeout):
            calls["n"] += 1
            payload = json.loads(request.data)
            if "reasoning_effort" in payload:
                raise urllib.error.HTTPError(
                    request.full_url,
                    400,
                    "Bad Request",
                    hdrs=None,
                    fp=io.BytesIO(b'{"error":{"message":"unknown parameter reasoning_effort"}}'),
                )
            self.assertEqual(payload["temperature"], 0.2)
            return _Body(b'{"choices":[{"message":{"content":"Klar."}}]}')

        text = complete([{"role": "user", "content": "x"}], "gpt-5.6-luna", "secret-key", 40, opener=opener)
        self.assertEqual(text, "Klar.")
        self.assertEqual(calls["n"], 2)


if __name__ == "__main__":
    unittest.main()
