#include "score/mw/com/example/vehicle-dynamics-example/com-api-gen/vehicle_gen.h"

#include <gtest/gtest.h>

#include <cstddef>
#include <string>
#include <type_traits>
#include <vector>

namespace score::mw::com
{
namespace
{

struct RecordingTraits
{
    struct Base
    {
        std::vector<std::string> event_names;
    };

    template <typename Sample>
    struct Event
    {
        using SampleType = Sample;

        Event(Base& service, const char* name)
        {
            service.event_names.emplace_back(name);
        }
    };
};

TEST(BodySignalInterfaceTest, BodyAndHighBeamUseSeparateInterfaces)
{
    const BodyControlModuleTx<RecordingTraits> body_tx;
    const BodyControlModuleRx<RecordingTraits> body_rx;
    const HighBeamTx<RecordingTraits> high_beam_tx;
    const VehicleHighBeamRx<RecordingTraits> high_beam_rx;
    EXPECT_EQ(body_tx.event_names.size(), 43U);
    EXPECT_EQ(body_rx.event_names, body_tx.event_names);
    EXPECT_EQ(body_tx.event_names.front(), "horn_state");
    EXPECT_EQ(body_tx.event_names.back(), "transmission_performance_mode_state");
    EXPECT_EQ(high_beam_tx.event_names, (std::vector<std::string>{"high_beam_state"}));
    EXPECT_EQ(high_beam_rx.event_names, high_beam_tx.event_names);

    static_assert(std::is_same_v<decltype(body_tx.horn_state)::SampleType, HighBeamCommand>);
    static_assert(std::is_same_v<decltype(body_rx.horn_state)::SampleType, HighBeamState>);
    static_assert(std::is_same_v<decltype(body_rx.rear_trunk_position_state)::SampleType, HighBeamCommand>);
    static_assert(std::is_same_v<decltype(body_tx.front_wiping_mode_state)::SampleType, BodySignalText>);
    static_assert(std::is_same_v<decltype(body_rx.front_wiping_mode_state)::SampleType, BodySignalText>);
    static_assert(std::is_same_v<decltype(high_beam_tx.high_beam_state)::SampleType, HighBeamCommand>);
    static_assert(std::is_same_v<decltype(high_beam_rx.high_beam_state)::SampleType, HighBeamState>);
}

TEST(BodySignalInterfaceTest, SamplesMatchGatewaySharedMemoryLayouts)
{
    EXPECT_EQ(sizeof(HighBeamState), 1U);
    EXPECT_EQ(offsetof(HighBeamState, value), 0U);
    EXPECT_EQ(sizeof(HighBeamCommand), 32U);
    EXPECT_EQ(alignof(HighBeamCommand), 16U);
    EXPECT_EQ(offsetof(HighBeamCommand, data), 16U);
    EXPECT_EQ(sizeof(BodySignalText), 48U);
    EXPECT_EQ(alignof(BodySignalText), 16U);
    EXPECT_EQ(offsetof(BodySignalText, data), 16U);
    const BodySignalText text{};
    EXPECT_EQ(sizeof(text.data), 32U);
}

TEST(BodySignalInterfaceTest, CommandIngressDeclaresHighBeamCommand)
{
    const ScoreAppCommandIngress<RecordingTraits> ingress;
    EXPECT_EQ(ingress.event_names, (std::vector<std::string>{"high_beam_command"}));
    static_assert(std::is_same_v<decltype(ingress.high_beam_command)::SampleType, HighBeamCommand>);
}

}
}