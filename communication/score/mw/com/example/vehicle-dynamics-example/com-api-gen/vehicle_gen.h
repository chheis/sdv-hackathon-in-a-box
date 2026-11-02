/********************************************************************************
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

#ifndef SCORE_MW_COM_EXAMPLE_VEHICLE_DYNAMICS_EXAMPLE_VEHICLE_GEN_H
#define SCORE_MW_COM_EXAMPLE_VEHICLE_DYNAMICS_EXAMPLE_VEHICLE_GEN_H

#include <cstdint>
#include <cstddef>

#include "score/mw/com/types.h"

namespace score::mw::com
{

struct SpeedSample
{
    double value;
    std::uint8_t quality;
};

struct SpeedAck
{
    double value;
    std::uint8_t quality;
};

struct HighBeamState
{
    bool value;
};

struct HighBeamCommand
{
    std::size_t size{};
    alignas(std::max_align_t) std::uint8_t data[16]{};
};

static_assert(sizeof(HighBeamCommand) == 32U);
static_assert(alignof(HighBeamCommand) == 16U);
static_assert(offsetof(HighBeamCommand, data) == 16U);

template <typename Trait>
class VehicleDynamicsService : public Trait::Base
{
  public:
    using Trait::Base::Base;

    typename Trait::template Event<SpeedSample> speed{*this, "speed"};

    typename Trait::template Event<SpeedAck> speedAck{*this, "speedAck"};
};

using VehicleDynamicsServiceProxy = AsProxy<VehicleDynamicsService>;
using VehicleDynamicsServiceSkeleton = AsSkeleton<VehicleDynamicsService>;

template <typename Trait>
class VehicleHighBeamRx : public Trait::Base
{
    public:
        using Trait::Base::Base;

        typename Trait::template Event<HighBeamState> high_beam_state{*this, "high_beam_state"};
};

using VehicleHighBeamRxProxy = AsProxy<VehicleHighBeamRx>;
using VehicleHighBeamRxSkeleton = AsSkeleton<VehicleHighBeamRx>;

template <typename Trait>
class HighBeamTx : public Trait::Base
{
    public:
        using Trait::Base::Base;
        typename Trait::template Event<HighBeamCommand> high_beam_state{*this, "high_beam_state"};
};

using HighBeamTxProxy = AsProxy<HighBeamTx>;
using HighBeamTxSkeleton = AsSkeleton<HighBeamTx>;

}  // namespace score::mw::com

#endif  // SCORE_MW_COM_EXAMPLE_VEHICLE_DYNAMICS_EXAMPLE_VEHICLE_GEN_H