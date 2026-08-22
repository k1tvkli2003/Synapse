from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from tool.actions.verify_actions_workflows import verify_repository


ROOT = Path(__file__).resolve().parents[2]


class ActionsWorkflowVerificationTest(unittest.TestCase):
    def test_repository_workflows_satisfy_quality_policy(self) -> None:
        receipt = verify_repository(ROOT)
        self.assertEqual("pass", receipt["status"], receipt["issues"])

    def test_rejects_moving_action_tag(self) -> None:
        with self._copy_policy_files() as root:
            path = root / ".github/workflows/quality.yml"
            text = path.read_text(encoding="utf-8").replace(
                "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1",
                "actions/checkout@v7",
            )
            path.write_text(text, encoding="utf-8")
            codes = self._codes(root)
            self.assertIn("unpinned_action", codes)

    def test_rejects_write_permission(self) -> None:
        with self._copy_policy_files() as root:
            path = root / ".github/workflows/quality.yml"
            text = path.read_text(encoding="utf-8").replace(
                "contents: read", "contents: write"
            )
            path.write_text(text, encoding="utf-8")
            codes = self._codes(root)
            self.assertIn("write_permission", codes)

    def test_rejects_privileged_pull_request_trigger(self) -> None:
        with self._copy_policy_files() as root:
            path = root / ".github/workflows/quality.yml"
            text = path.read_text(encoding="utf-8").replace(
                "  pull_request:\n", "  pull_request_target:\n"
            )
            path.write_text(text, encoding="utf-8")
            codes = self._codes(root)
            self.assertIn("privileged_pull_request_target", codes)

    def _codes(self, root: Path) -> set[str]:
        receipt = verify_repository(root)
        return {issue["code"] for issue in receipt["issues"]}

    def _copy_policy_files(self):
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        (root / ".github/workflows").mkdir(parents=True)
        shutil.copy2(
            ROOT / ".github/workflows/quality.yml",
            root / ".github/workflows/quality.yml",
        )
        shutil.copy2(
            ROOT / ".github/dependabot.yml",
            root / ".github/dependabot.yml",
        )
        return _TemporaryRoot(temporary, root)


class _TemporaryRoot:
    def __init__(self, temporary: tempfile.TemporaryDirectory, root: Path) -> None:
        self._temporary = temporary
        self._root = root

    def __enter__(self) -> Path:
        return self._root

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        self._temporary.cleanup()


if __name__ == "__main__":
    unittest.main()

