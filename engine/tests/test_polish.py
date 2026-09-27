import unittest

from flow_engine.polish import apply_rules, clean_output, parse_dictionary, token_budget


class PolishTests(unittest.TestCase):
    def test_clean_strips_thinking_and_fences(self):
        raw = "<think>\nlang\n</think>\n```text\nHallo Welt\n```"
        self.assertEqual(clean_output(raw), "Hallo Welt")

    def test_clean_unwraps_quotes(self):
        self.assertEqual(clean_output('"Morgen um zehn."'), "Morgen um zehn.")

    def test_dictionary_rules_replace_longest_first(self):
        hints, rules = parse_dictionary("VEMA\nflow app -> Flow\n# Kommentar")
        self.assertEqual(hints, ["VEMA"])
        self.assertEqual(apply_rules("Die flow app ist da.", rules), "Die Flow ist da.")

    def test_token_budget_grows_with_text(self):
        self.assertGreaterEqual(token_budget("eins zwei drei vier", "markiert"), 80)


if __name__ == "__main__":
    unittest.main()
