# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# SPDX-License-Identifier: Apache-2.0

"""Check remote menu publication using loopback UDP and no GPIO hardware."""

import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time


def collect_samples(binary, routes, option, answer=None):
    with tempfile.TemporaryDirectory(prefix="sdv-sweep-test-") as directory:
        root = Path(directory)
        config = root / "routes.json"
        config.write_text(json.dumps({"routes": routes}))
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as receiver:
            receiver.bind(("127.0.0.1", 0))
            receiver.settimeout(0.25)
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
                reservation.bind(("127.0.0.1", 0))
                remote_port = reservation.getsockname()[1]
            env = dict(os.environ)
            env.update({
                "SIGNAL_ROUTE_CONFIG": str(config),
                "SDV_BRIDGE_IP": "127.0.0.1",
                "SDV_BIND_IP": "127.0.0.1",
                "SDV_BRIDGE_UDP_PORT": str(receiver.getsockname()[1]),
                "SDV_REMOTE_UDP_PORT": str(remote_port),
                "HIGH_BEAM_GPIO_CHIP": str(root / "no-gpio"),
                "HIGH_BEAM_GPIO_OUTPUT_CHIP": str(root / "no-gpio"),
                "SDV_KVS_DIR": str(root / "state"),
            })
            log_path = root / "remote.log"
            with log_path.open("w+") as output:
                process = subprocess.Popen(
                    [str(Path(binary).resolve())],
                    stdin=subprocess.PIPE,
                    stdout=output,
                    stderr=subprocess.STDOUT,
                    env=env,
                    start_new_session=True,
                    text=True,
                )
                samples = []
                try:
                    process.stdin.write(f"{option}\n")
                    process.stdin.flush()
                    if answer is not None:
                        prompt_deadline = time.monotonic() + 3
                        while "PerformanceMode value (" not in log_path.read_text():
                            assert time.monotonic() < prompt_deadline, log_path.read_text()
                            time.sleep(0.02)
                        process.stdin.write(f"{answer}\n")
                        process.stdin.flush()
                    deadline = time.monotonic() + 6
                    quit_at = time.monotonic() + 1.5
                    quit_sent = False
                    while time.monotonic() < deadline:
                        if not quit_sent and time.monotonic() >= quit_at:
                            process.stdin.write("q\n")
                            process.stdin.flush()
                            quit_sent = True
                        try:
                            data, _ = receiver.recvfrom(1024)
                        except socket.timeout:
                            if process.poll() is not None:
                                break
                            continue
                        if len(data) >= 15:
                            event = int.from_bytes(data[10:12], "big")
                            samples.append((time.monotonic(), event, data[14:14 + data[12]]))
                    process.wait(timeout=3)
                    if process.returncode:
                        output.seek(0)
                        raise AssertionError(output.read())
                    return samples
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=5)


def main(binary):
    source = Path(__file__).resolve().parents[1] / "config/signal_routes.json"
    routes = {route["name"]: route for route in json.loads(source.read_text())["routes"]}
    high_beam = routes["high_beam"]
    samples = collect_samples(binary, [high_beam], 4)
    beam_samples = [(t, payload) for t, event, payload in samples if event == high_beam["remoteEvent"]]
    first_true = next(t for t, value in beam_samples if value == b"\x01")
    preceding_false = max(t for t, value in beam_samples if value == b"\x00" and t < first_true)
    following_false = next(t for t, value in beam_samples if value == b"\x00" and t > first_true)
    for gap in (first_true - preceding_false, following_false - first_true):
        assert 0.18 <= gap <= 1.0, samples
    print(f"PASS: option 4 high-beam false -> true -> false in {following_false - preceding_false:.2f}s")

    mode = routes["transmission_performance_mode"]
    for answer, expected in (("SPORT", [(mode["remoteEvent"], b"SPORT")]), ("INVALID", [])):
        samples = collect_samples(binary, [high_beam, routes["parking_lights"], mode], 5, answer)
        test_samples = [(event, payload) for _, event, payload in samples if event != high_beam["remoteEvent"]]
        assert test_samples == expected, samples
    print("PASS: option 5 publishes the selected mode once and publishes nothing for invalid input")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("binary")
    main(parser.parse_args().binary)
