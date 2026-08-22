from __future__ import annotations

import unittest

from tool.security.scan_secrets import scan_text


class ScanSecretsTest(unittest.TestCase):
    def test_detects_secret_without_returning_raw_value(self) -> None:
        raw = "sk-" + "A" * 24
        findings = scan_text("fixture.txt", f'api_key = "{raw}"')

        self.assertTrue(findings)
        self.assertNotIn(raw, repr(findings))
        self.assertEqual(findings[0].path, "fixture.txt")
        self.assertEqual(findings[0].line, 1)

    def test_allows_deliberate_public_fixture_values(self) -> None:
        findings = scan_text(
            "fixture.txt",
            'api_key = "fixture_public_key_1234567890"',
        )

        self.assertEqual(findings, [])

    def test_detects_private_key_header(self) -> None:
        header = "-----BEGIN " + "PRIVATE KEY-----"
        findings = scan_text(
            "key.pem",
            f"line one\n{header}\n",
        )

        self.assertEqual(findings[0].rule, "private-key-header")
        self.assertEqual(findings[0].line, 2)


if __name__ == "__main__":
    unittest.main()
