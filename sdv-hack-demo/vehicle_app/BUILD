# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

cc_binary(
    name = "vehicle_high_beam_mw_com",
    srcs = ["main.cc"],
    data = ["@score_someip_gateway//score/gatewayd:etc/mw_com_config.json"],
    visibility = ["//visibility:public"],
    deps = [
        "//:kuksa_val_client",
        "@grpc//:grpc++",
        "@score_lifecycle//score/launch_manager:lifecycle_cc",
        "@score_logging//score/mw/log:log",
        "@score_communication//score/mw/com",
        "@score_someip_gateway//score/serializer:pre_serialized_data",
    ],
)