/*********************************************************************************
 * Copyright (c) 2025 Contributors to the Eclipse Foundation
 *
 * See the NOTICE file(s) distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0
 ********************************************************************************/

#include "score/mw/com/example/vehicle-dynamics-example/com-api-gen/vehicle_gen.h"

#include "score/mw/com/rust/score_com_cpp_bridge/register_interface.h"

BEGIN_EXPORT_MW_COM_INTERFACE(
    VehicleDynamicsService,
    ::score::mw::com::VehicleDynamicsServiceProxy,
    ::score::mw::com::VehicleDynamicsServiceSkeleton)

EXPORT_MW_COM_EVENT(::score::mw::com::SpeedSample, speed)
EXPORT_MW_COM_EVENT(::score::mw::com::SpeedAck, speedAck)

END_EXPORT_MW_COM_INTERFACE()

EXPORT_MW_COM_TYPE(SpeedSample, ::score::mw::com::SpeedSample)
EXPORT_MW_COM_TYPE(SpeedAck, ::score::mw::com::SpeedAck)

BEGIN_EXPORT_MW_COM_INTERFACE(
    VehicleHighBeamRx,
    ::score::mw::com::VehicleHighBeamRxProxy,
    ::score::mw::com::VehicleHighBeamRxSkeleton)

EXPORT_MW_COM_EVENT(::score::mw::com::HighBeamState, high_beam_state)

END_EXPORT_MW_COM_INTERFACE()

EXPORT_MW_COM_TYPE(HighBeamState, ::score::mw::com::HighBeamState)

BEGIN_EXPORT_MW_COM_INTERFACE(
    HighBeamTx,
    ::score::mw::com::HighBeamTxProxy,
    ::score::mw::com::HighBeamTxSkeleton)

EXPORT_MW_COM_EVENT(::score::mw::com::HighBeamCommand, high_beam_state)

END_EXPORT_MW_COM_INTERFACE()

EXPORT_MW_COM_TYPE(HighBeamCommand, ::score::mw::com::HighBeamCommand)