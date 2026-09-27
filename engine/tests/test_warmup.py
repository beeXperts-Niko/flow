import unittest

from flow_engine.transcribe import needs_warmup


class WarmupTests(unittest.TestCase):
    def test_skips_when_the_model_was_just_used(self):
        self.assertFalse(needs_warmup(last_touch=100, now=130))

    def test_runs_again_after_the_interval(self):
        self.assertTrue(needs_warmup(last_touch=100, now=160))

    def test_runs_when_never_touched(self):
        self.assertTrue(needs_warmup(last_touch=0, now=45))


if __name__ == "__main__":
    unittest.main()
