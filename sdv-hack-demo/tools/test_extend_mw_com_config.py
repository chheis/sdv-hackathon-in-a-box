import json
import tempfile
import unittest
from pathlib import Path

from extend_mw_com_config import (
    EVENT_NAME,
    INSTANCE_SPECIFIER,
    SERVICE_ID,
    SERVICE_TYPE,
    extend_manifest,
)


class ExtendManifestTest(unittest.TestCase):
    def test_preserves_upstream_entries_and_adds_private_ingress(self):
        base_manifest = {
            "serviceTypes": [{"serviceTypeName": "existing"}],
            "serviceInstances": [{"instanceSpecifier": "/existing"}],
        }
        with tempfile.TemporaryDirectory() as directory:
            base_path = Path(directory) / "base.json"
            output_path = Path(directory) / "extended.json"
            base_path.write_text(json.dumps(base_manifest), encoding="utf-8")

            extend_manifest(base_path, output_path)

            self.assertEqual(json.loads(base_path.read_text(encoding="utf-8")), base_manifest)
            extended = json.loads(output_path.read_text(encoding="utf-8"))
            self.assertEqual(extended["serviceTypes"][0], base_manifest["serviceTypes"][0])
            self.assertEqual(extended["serviceInstances"][0], base_manifest["serviceInstances"][0])
            self.assertEqual(extended["serviceTypes"][1]["serviceTypeName"], SERVICE_TYPE)
            self.assertEqual(
                extended["serviceInstances"][1]["instanceSpecifier"],
                INSTANCE_SPECIFIER,
            )
            instance = extended["serviceInstances"][1]["instances"][0]
            self.assertEqual(instance["events"][0]["eventName"], EVENT_NAME)

    def test_rejects_service_id_collision(self):
        with tempfile.TemporaryDirectory() as directory:
            base_path = Path(directory) / "base.json"
            base_path.write_text(
                json.dumps(
                    {
                        "serviceTypes": [
                            {"bindings": [{"serviceId": SERVICE_ID}]}
                        ],
                        "serviceInstances": [],
                    }
                ),
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "service ID already exists"):
                extend_manifest(base_path, Path(directory) / "extended.json")


if __name__ == "__main__":
    unittest.main()
