from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("verify_performance_budgets.py")
SPEC = importlib.util.spec_from_file_location("verify_performance_budgets", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def threshold(target: int = 10, warning: int = 20, blocking: int = 30) -> dict[str, int]:
    return {
        "targetMax": target,
        "warningMax": warning,
        "blockingMax": blocking,
    }


def minimal_config(static_budgets: list[dict[str, object]]) -> dict[str, object]:
    runtime_entry = {
        "targetMax": 1,
        "warningMax": 2,
        "blockingMax": 3,
    }
    return {
        "schemaVersion": 1,
        "policy": {
            "motionModes": ["full", "reduced", "off"],
            "requiredMotionScenarios": ["first-run", "fallback"],
        },
        "staticBudgets": static_budgets,
        "runtimeBudgets": {
            "enforcement": "informational-until-calibrated",
            "startupMilliseconds": [runtime_entry],
            "frameMilliseconds": [runtime_entry],
            "memoryBytes": [runtime_entry],
        },
        "motionExperienceBudgets": {
            name: {
                "durationMilliseconds": runtime_entry,
                "particles": runtime_entry,
            }
            for name in ("standard", "milestone", "showpiece")
        },
        "namedJourneys": [
            {"id": f"J{index}", "states": ["start", "end"]}
            for index in range(4)
        ],
    }


class PerformanceBudgetTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write_config(self, config: dict[str, object]) -> Path:
        path = self.root / "budgets.json"
        path.write_text(json.dumps(config), encoding="utf-8")
        return path

    def test_measures_tree_and_classifies_target(self) -> None:
        assets = self.root / "assets"
        assets.mkdir()
        (assets / "a.bin").write_bytes(b"1234")
        budget = {
            "id": "assets",
            "probe": {"type": "tree_bytes", "path": "assets"},
            "required": True,
            "enforcement": "blocking",
            "thresholdsBytes": threshold(5, 10, 15),
        }
        result = MODULE.verify(self.root, self.write_config(minimal_config([budget])))
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["staticMeasurements"][0]["valueBytes"], 4)
        self.assertEqual(result["staticMeasurements"][0]["tier"], "target")

    def test_fails_when_static_artifact_exceeds_blocking_ceiling(self) -> None:
        artifact = self.root / "artifact.bin"
        artifact.write_bytes(b"x" * 31)
        budget = {
            "id": "artifact",
            "probe": {"type": "file_bytes", "path": "artifact.bin"},
            "required": True,
            "enforcement": "blocking",
            "thresholdsBytes": threshold(),
        }
        result = MODULE.verify(self.root, self.write_config(minimal_config([budget])))
        self.assertEqual(result["status"], "fail")
        self.assertEqual(result["staticMeasurements"][0]["tier"], "fail")

    def test_fails_when_required_artifact_tree_is_empty(self) -> None:
        (self.root / "assets").mkdir()
        budget = {
            "id": "runtime-assets",
            "probe": {"type": "tree_bytes", "path": "assets"},
            "required": True,
            "enforcement": "blocking",
            "thresholdsBytes": threshold(),
        }

        result = MODULE.verify(self.root, self.write_config(minimal_config([budget])))

        self.assertEqual(result["status"], "fail")
        self.assertEqual(result["staticMeasurements"][0]["tier"], "fail")
        self.assertIn("no measurable files", result["failures"][0])

    def test_png_probe_estimates_rgba_decode_allocation(self) -> None:
        image = self.root / "asset.png"
        image.write_bytes(
            b"\x89PNG\r\n\x1a\n"
            b"\x00\x00\x00\rIHDR"
            b"\x00\x00\x00\x02\x00\x00\x00\x03"
        )
        measurement = MODULE.measure_probe(
            self.root,
            {"type": "largest_png_decoded_rgba_bytes", "path": "."},
        )
        self.assertEqual(measurement["valueBytes"], 24)

    def test_measures_only_flutter_declared_assets(self) -> None:
        app = self.root / "app"
        active = app / "assets" / "active"
        active.mkdir(parents=True)
        (active / "included.bin").write_bytes(b"abc")
        (app / "assets" / "explicit.bin").write_bytes(b"defg")
        (app / "assets" / "historical.bin").write_bytes(b"x" * 100)
        (app / "pubspec.yaml").write_text(
            """flutter:\n  assets:\n    - assets/active/\n    - \"assets/explicit.bin\" # active exact file\n""",
            encoding="utf-8",
        )

        measurement = MODULE.measure_probe(
            self.root,
            {"type": "flutter_declared_assets_bytes", "path": "app/pubspec.yaml"},
        )

        self.assertTrue(measurement["present"])
        self.assertEqual(measurement["valueBytes"], 7)
        self.assertEqual(measurement["filesMeasured"], 2)
        self.assertEqual(
            measurement["declaredAssetPaths"],
            ["assets/active/", "assets/explicit.bin"],
        )
        self.assertEqual(measurement["missingDeclaredAssetPaths"], [])

    def test_declared_flutter_asset_cannot_escape_package_root(self) -> None:
        app = self.root / "app"
        app.mkdir()
        (app / "pubspec.yaml").write_text(
            "flutter:\n  assets:\n    - ../outside.bin\n",
            encoding="utf-8",
        )

        with self.assertRaises(MODULE.BudgetError):
            MODULE.measure_probe(
                self.root,
                {"type": "flutter_declared_assets_bytes", "path": "app/pubspec.yaml"},
            )

    def test_rejects_probe_path_that_escapes_repository(self) -> None:
        with self.assertRaises(MODULE.BudgetError):
            MODULE.measure_probe(
                self.root,
                {"type": "tree_bytes", "path": "../outside"},
            )

    def test_rejects_unordered_thresholds(self) -> None:
        budget = {
            "id": "invalid",
            "probe": {"type": "tree_bytes", "path": "."},
            "required": True,
            "enforcement": "blocking",
            "thresholdsBytes": threshold(10, 10, 30),
        }
        with self.assertRaises(MODULE.BudgetError):
            MODULE.validate_config(minimal_config([budget]))


if __name__ == "__main__":
    unittest.main()
