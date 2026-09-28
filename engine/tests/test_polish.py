import unittest

from flow_engine.polish import (
    apply_rules,
    build_messages,
    clean_output,
    parse_dictionary,
    token_budget,
    weighted_terms,
)


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

    def test_weighted_terms_include_the_correct_spelling(self):
        self.assertEqual(weighted_terms("VEMA\nflow app -> Flow"), ["VEMA", "Flow"])

    def test_token_budget_grows_with_text(self):
        self.assertGreaterEqual(token_budget("eins zwei drei vier", "markiert"), 80)

    def test_selection_is_an_instruction(self):
        messages = build_messages(
            "kannst du das zusammenfassen",
            "Ein langer Absatz über das Projekt.",
            "code",
            "",
            "",
        )
        system = messages[0]["content"]
        user = messages[1]["content"]
        self.assertIn("Anweisung", system)
        self.assertIn("Wiederhole die Anweisung nicht", system)
        self.assertIn("vollständig", system)
        self.assertNotIn("knapp und klar", system)
        self.assertNotIn("Entferne nur Füllwörter", system)
        self.assertIn("Ein langer Absatz über das Projekt.", user)
        self.assertIn("kannst du das zusammenfassen", user)
        self.assertNotIn("Rohtranskript", user)


if __name__ == "__main__":
    unittest.main()
