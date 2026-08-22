from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tool.architecture.validate_architecture import validate_package


class ArchitectureValidatorTest(unittest.TestCase):
    def _package(self, root: Path, name: str, source: str, deps: str = "") -> None:
        package = root / "packages" / name
        (package / "lib").mkdir(parents=True)
        (package / "pubspec.yaml").write_text(
            f"name: synapse_{name}\ndependencies:\n{deps}dev_dependencies:\n",
            encoding="utf-8",
        )
        (package / "lib" / "sample.dart").write_text(source, encoding="utf-8")

    def test_rejects_flutter_inside_pure_domain_package(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._package(root, "core", "import 'package:flutter/material.dart';\n")
            violations = validate_package(root, "core")

            self.assertEqual(violations[0].rule, "pure-dart-boundary")

    def test_rejects_inverse_workspace_dependency(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._package(
                root,
                "foundation",
                "import 'package:synapse_app/app.dart';\n",
                "  synapse_app:\n    path: ../../apps/app\n",
            )
            violations = validate_package(root, "foundation")

            self.assertTrue(
                any(item.rule == "dependency-direction" for item in violations)
            )

    def test_allows_services_to_use_pure_dart_foundation_ports(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._package(
                root,
                "services",
                "import 'package:synapse_foundation/synapse_foundation.dart';\n",
                "  synapse_foundation:\n    path: ../foundation\n",
            )

            self.assertEqual([], validate_package(root, "services"))

    def test_rejects_enum_index_in_json_encoder(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._package(
                root,
                "core",
                "Map<String, Object> toJson() => {'kind': kind.index};\n",
            )
            violations = validate_package(root, "core")

            self.assertEqual(violations[0].rule, "unsafe-enum-index-encode")


if __name__ == "__main__":
    unittest.main()
