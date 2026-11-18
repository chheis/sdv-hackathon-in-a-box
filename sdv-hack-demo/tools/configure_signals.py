# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# SPDX-License-Identifier: Apache-2.0

"""Synchronize body signal configuration without replacing unrelated services."""

import argparse
import copy
import json
from pathlib import Path

from gateway_provider_codegen import gateway_provider_documents, gateway_provider_sources

ROOT = Path(__file__).resolve().parents[2]


def read_json(path):
    return json.loads(path.read_text())


def split_high_beam_services(config, signals):
    high_beam = next(signal for signal in signals if signal["name"] == "high_beam")
    event_name = high_beam.get("eventName", high_beam["name"] + "_state")
    for direction, instance_key, specifier in (
        ("tx", "local_service_instances", "/vehicle_high_beam/local_tx"),
        ("rx", "remote_service_instances", "/vehicle_high_beam/network_rx"),
    ):
        body_type_name = "body_control_module_" + direction
        high_beam_type_name = "vehicle_high_beam_" + direction
        body_type = next(
            item
            for item in config["service_types"]
            if item["service_type_name"].lstrip("/") == body_type_name
        )
        config["service_types"] = [
            item
            for item in config["service_types"]
            if item["service_type_name"].lstrip("/") != high_beam_type_name
        ]
        high_beam_type = copy.deepcopy(body_type)
        high_beam_type["service_type_name"] = high_beam_type_name
        high_beam_type["events"] = []
        for key in ("local_service_instances", "remote_service_instances"):
            high_beam_type.pop(key, None)
        instance = copy.deepcopy(body_type[instance_key][0])
        instance["instance_specifier"] = specifier
        high_beam_type[instance_key] = [instance]
        config["service_types"].append(high_beam_type)
        body_type["events"] = [
            event for event in body_type["events"] if event["event_name"] != event_name
        ]


def configure(root):
    demo = root / "sdv-hack-demo"
    gateway = root / "inc_someip_gateway"
    signals = read_json(demo / "config/body_signals.json")["signals"]
    routes_path = demo / "config/signal_routes.json"
    routes = read_json(routes_path)
    event_names = {signal.get("eventName", signal["name"] + "_state") for signal in signals}
    routes["routes"] = [route for route in routes["routes"] if route["service"] != 17152]
    gateway_paths = [gateway / "score/config/mw_someip_config.json", demo / "config/mw_someip_config.json"]
    configs = {path: read_json(path) for path in gateway_paths}
    lola_path = gateway / "score/gatewayd/etc/mw_com_config.json"
    lola = read_json(lola_path)
    vsomeip_path = gateway / "tests/integration/vsomeip-gateway-services.json"
    vsomeip = read_json(vsomeip_path)

    for config in configs.values():
        split_high_beam_services(config, signals)

    body_types = {"/body_control_module_tx", "/body_control_module_rx"}
    high_beam_types = {"/vehicle_high_beam_tx", "/vehicle_high_beam_rx"}
    high_beam_signal = next(signal for signal in signals if signal["name"] == "high_beam")
    high_beam_event_name = high_beam_signal.get("eventName", high_beam_signal["name"] + "_state")
    body_event_names = event_names - {high_beam_event_name}
    for config in configs.values():
        for service in config["service_types"]:
            if "/" + service["service_type_name"].lstrip("/") in body_types:
                service["events"] = [
                    event for event in service["events"] if event["event_name"] in body_event_names
                ]
            elif "/" + service["service_type_name"].lstrip("/") in high_beam_types:
                service["events"] = [
                    event for event in service["events"] if event["event_name"] == high_beam_event_name
                ]

    for direction, instance_key, specifier in (
        ("tx", "local_service_instances", "/vehicle_high_beam/local_tx"),
        ("rx", "remote_service_instances", "/vehicle_high_beam/network_rx"),
    ):
        body_name = "/body_control_module_" + direction
        high_beam_name = "/vehicle_high_beam_" + direction
        body_type = next(item for item in lola["serviceTypes"] if item["serviceTypeName"] == body_name)
        lola["serviceTypes"] = [
            item for item in lola["serviceTypes"] if item["serviceTypeName"] != high_beam_name
        ]
        high_beam_type = copy.deepcopy(body_type)
        high_beam_type["serviceTypeName"] = high_beam_name
        # LoLa segments are keyed by numeric service/instance IDs, not service names.
        high_beam_type["bindings"][0]["serviceId"] = 17153
        high_beam_type["bindings"][0]["events"] = []
        lola["serviceTypes"].append(high_beam_type)

        body_instance = next(
            item for item in lola["serviceInstances"] if item["serviceTypeName"] == body_name
        )
        lola["serviceInstances"] = [
            item for item in lola["serviceInstances"] if item["serviceTypeName"] != high_beam_name
        ]
        high_beam_instance = copy.deepcopy(body_instance)
        high_beam_instance["instanceSpecifier"] = specifier
        high_beam_instance["serviceTypeName"] = high_beam_name
        for instance in high_beam_instance["instances"]:
            instance["events"] = []
        lola["serviceInstances"].append(high_beam_instance)

    for service in lola["serviceTypes"]:
        if service["serviceTypeName"] in body_types:
            for binding in service["bindings"]:
                binding["events"] = [
                    event for event in binding["events"] if event["eventName"] in body_event_names
                ]
        elif service["serviceTypeName"] in high_beam_types:
            for binding in service["bindings"]:
                binding["events"] = [
                    event
                    for event in binding["events"]
                    if event["eventName"] == high_beam_event_name
                ]
    for service in lola["serviceInstances"]:
        if service["serviceTypeName"] in body_types:
            for instance in service["instances"]:
                instance["events"] = [
                    event for event in instance["events"] if event["eventName"] in body_event_names
                ]
        elif service["serviceTypeName"] in high_beam_types:
            for instance in service["instances"]:
                instance["events"] = [
                    event
                    for event in instance["events"]
                    if event["eventName"] == high_beam_event_name
                ]
    for service in vsomeip["services"]:
        if int(service["service"], 0) == 17152:
            offset = 0 if int(service["instance"], 0) == 4096 else 1
            event_ids = {signal["vehicleEvent"] + offset for signal in signals}
            service["events"] = [event for event in service["events"] if int(event["event"], 0) in event_ids]
            service["eventgroups"] = [
                group for group in service["eventgroups"] if int(group["eventgroup"], 0) in event_ids
            ]

    for signal in signals:
        event_name = signal.get("eventName", signal["name"] + "_state")
        event_id = signal["vehicleEvent"]
        payload_size = {
            "boolean": 1,
            "uint8": 1,
            "int16": 2,
            "float": 4,
            "float_array": 32,
            "string": 32,
        }[signal["datatype"]]
        route = {
            "name": signal["name"],
            "apiName": signal["apiName"],
            "ackApiName": signal["apiName"],
            "datatype": signal["datatype"],
            "eventName": event_name,
            "maxPayloadSize": payload_size,
            "service": 17152,
            "vehicleInstance": 4096,
            "remoteInstance": 4097,
            "vehicleEvent": event_id,
            "remoteEvent": event_id + 1,
        }
        if signal["datatype"] == "float_array":
            route["maxElements"] = signal["maxElements"]
        routes["routes"].append(route)
        for direction, offset, instance_id in (("tx", 0, 4096), ("rx", 1, 4097)):
            high_beam = signal["name"] == "high_beam"
            type_name = ("vehicle_high_beam_" if high_beam else "body_control_module_") + direction
            wire_id = event_id + offset
            boolean_rx = direction == "rx" and signal["datatype"] == "boolean"
            event = {
                "event_name": event_name,
                "event_id": wire_id,
                "serialization_config_type": "BooleanSerializerConfig" if boolean_rx else "NullSerializerConfig",
                "serialization_config": {} if boolean_rx else {"max_message_size": payload_size},
                "eventgroup_ids": [wire_id],
            }
            for config in configs.values():
                service = next(
                    item for item in config["service_types"] if item["service_type_name"].lstrip("/") == type_name
                )
                service["events"] = [item for item in service["events"] if item["event_name"] != event_name] + [
                    copy.deepcopy(event)
                ]
                instance_key = "local_service_instances" if direction == "tx" else "remote_service_instances"
                for instance in service.get(instance_key, []):
                    instance["instance_specifier"] = "/" + instance["instance_specifier"].lstrip("/")

            lola_type = next(item for item in lola["serviceTypes"] if item["serviceTypeName"] == "/" + type_name)
            shm_events = lola_type["bindings"][0]["events"]
            shm_events[:] = [item for item in shm_events if item["eventName"] != event_name]
            shm_events.append({"eventName": event_name, "eventId": 2115 + wire_id - 33840})
            lola_instance = next(
                item for item in lola["serviceInstances"] if item["serviceTypeName"] == "/" + type_name
            )
            slots = lola_instance["instances"][0]["events"]
            slots[:] = [item for item in slots if item["eventName"] != event_name]
            slots.append({"eventName": event_name, "numberOfSampleSlots": 10, "maxSubscribers": 3})

            network_service = next(
                item
                for item in vsomeip["services"]
                if int(item["service"], 0) == 17152 and int(item["instance"], 0) == instance_id
            )
            wire_hex = f"0x{wire_id:04x}"
            network_service["events"] = [item for item in network_service["events"] if int(item["event"], 0) != wire_id]
            network_service["events"].append({"event": wire_hex, "is_field": "false"})
            network_service["eventgroups"] = [
                item for item in network_service["eventgroups"] if int(item["eventgroup"], 0) != wire_id
            ]
            network_service["eventgroups"].append({"eventgroup": wire_hex, "events": [wire_hex]})

    example_path = root / "communication/score/mw/com/example/vehicle-dynamics-example/etc/mw_com_config.json"
    example = read_json(example_path)
    for key in ("serviceTypes", "serviceInstances"):
        all_signal_types = body_types | high_beam_types
        example[key] = [item for item in example[key] if item["serviceTypeName"] not in all_signal_types]
        example[key].extend(
            copy.deepcopy(item)
            for item in lola[key]
            if item["serviceTypeName"] in all_signal_types
        )
    return {
        **configs,
        routes_path: routes,
        lola_path: lola,
        vsomeip_path: vsomeip,
        example_path: example,
        **gateway_provider_documents(root),
    }


def body_signal_declarations(root):
    signals = read_json(root / "sdv-hack-demo/config/body_signals.json")["signals"]
    declarations = []
    for signal in signals:
        if signal["name"] == "high_beam":
            continue
        event_name = signal.get("eventName", signal["name"] + "_state")
        tx_type = {
            "string": "BodySignalText",
            "int16": "BodySignalPayload",
            "float": "BodySignalPayload",
            "float_array": "BodySignalPayload",
        }.get(signal["datatype"], "HighBeamCommand")
        rx_type = "HighBeamState" if signal["datatype"] == "boolean" else tx_type
        declarations.append(f"SCORE_BODY_SIGNAL_EVENT({rx_type}, {tx_type}, {event_name})")
    return "\n".join(declarations) + "\n"


def high_beam_event_declaration(root):
    signal = next(
        signal
        for signal in read_json(root / "sdv-hack-demo/config/body_signals.json")["signals"]
        if signal["name"] == "high_beam"
    )
    event_name = signal.get("eventName", signal["name"] + "_state")
    return f"SCORE_BODY_SIGNAL_EVENT(HighBeamState, HighBeamCommand, {event_name})\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="update configuration snapshots (default: check only)")
    args = parser.parse_args()
    stale = []
    for path, document in configure(ROOT).items():
        if path.exists() and read_json(path) == document:
            continue
        stale.append(str(path.relative_to(ROOT)))
        if args.write:
            indent = 2 if path.name in {"signal_routes.json", "mw_com_config.json"} else 4
            path.write_text(json.dumps(document, indent=indent) + "\n")
    declarations_path = (
        ROOT / "communication/score/mw/com/example/vehicle-dynamics-example/com-api-gen/body_signal_events.inc"
    )
    high_beam_declaration_path = (
        ROOT / "communication/score/mw/com/example/vehicle-dynamics-example/com-api-gen/high_beam_event.inc"
    )
    declarations = body_signal_declarations(ROOT)
    sources = {
        declarations_path: declarations,
        high_beam_declaration_path: high_beam_event_declaration(ROOT),
        **gateway_provider_sources(ROOT),
    }
    for path, content in sources.items():
        if not path.exists() or path.read_text() != content:
            stale.append(str(path.relative_to(ROOT)))
            if args.write:
                path.write_text(content)
    if stale:
        print(("Updated: " if args.write else "Out of date: ") + ", ".join(stale))
    return 0 if args.write or not stale else 1


if __name__ == "__main__":
    raise SystemExit(main())
