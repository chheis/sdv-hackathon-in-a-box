#!/usr/bin/env python3
"""Create a vehicle-app mw::com manifest with the private command ingress."""

import argparse
import json
from pathlib import Path


SERVICE_TYPE = "/score_app_command_ingress"
INSTANCE_SPECIFIER = "/score_app_command/menu_tx"
EVENT_NAME = "high_beam_command"
SERVICE_ID = 32766
INSTANCE_ID = 32766


def extend_manifest(base_path: Path, output_path: Path) -> None:
    manifest = json.loads(base_path.read_text(encoding="utf-8"))
    service_types = manifest.setdefault("serviceTypes", [])
    service_instances = manifest.setdefault("serviceInstances", [])

    if any(item.get("serviceTypeName") == SERVICE_TYPE for item in service_types):
        raise ValueError(f"service type already exists: {SERVICE_TYPE}")
    if any(item.get("instanceSpecifier") == INSTANCE_SPECIFIER for item in service_instances):
        raise ValueError(f"service instance already exists: {INSTANCE_SPECIFIER}")
    if any(
        binding.get("serviceId") == SERVICE_ID
        for service_type in service_types
        for binding in service_type.get("bindings", [])
    ):
        raise ValueError(f"service ID already exists: {SERVICE_ID}")
    if any(
        instance.get("instanceId") == INSTANCE_ID
        for service in service_instances
        for instance in service.get("instances", [])
    ):
        raise ValueError(f"instance ID already exists: {INSTANCE_ID}")

    version = {"major": 1, "minor": 0}
    service_types.append(
        {
            "serviceTypeName": SERVICE_TYPE,
            "version": version,
            "bindings": [
                {
                    "binding": "SHM",
                    "serviceId": SERVICE_ID,
                    "events": [{"eventName": EVENT_NAME, "eventId": 1}],
                }
            ],
        }
    )
    service_instances.append(
        {
            "instanceSpecifier": INSTANCE_SPECIFIER,
            "serviceTypeName": SERVICE_TYPE,
            "version": version,
            "instances": [
                {
                    "instanceId": INSTANCE_ID,
                    "asil-level": "QM",
                    "binding": "SHM",
                    "events": [
                        {
                            "eventName": EVENT_NAME,
                            "numberOfSampleSlots": 10,
                            "maxSubscribers": 3,
                        }
                    ],
                }
            ],
        }
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    extend_manifest(arguments.base, arguments.output)


if __name__ == "__main__":
    main()
