// *******************************************************************************
// Copyright (c) 2026 Contributors to the Eclipse Foundation
//
// SPDX-License-Identifier: Apache-2.0
// *******************************************************************************

#include <array>
#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <string>
#include <string_view>
#include <thread>
#include <utility>

#include "score/mw/com/runtime.h"
#include "score/mw/com/types.h"
#include "score/mw/lifecycle/report_running.h"
#include "score/mw/log/logging.h"
#include "score/serializer/pre_serialized_data.h"

namespace {

constexpr std::string_view kRxInstanceSpecifier{"/vehicle_high_beam/network_rx"};
constexpr std::string_view kEventName{"high_beam_state"};
constexpr std::string_view kCommandInstanceSpecifier{"/score_app_command/menu_tx"};
constexpr std::string_view kCommandEventName{"high_beam_command"};
constexpr std::string_view kDynamicsTxInstanceSpecifier{"/Vehicle/Service1/Instance"};
constexpr std::string_view kDynamicsRxInstanceSpecifier{"/Vehicle/Service2/Instance"};
constexpr std::string_view kSpeedEventName{"speed"};
constexpr std::string_view kSpeedAckEventName{"speedAck"};
constexpr std::string_view kSpeedApiName{"Vehicle.speed"};
constexpr std::size_t kMaxSampleCount{4U};
constexpr std::size_t kCommandPayloadSize{1U};

using RawCommand = score::someip_gateway::serializer::PreSerializedData<0>;

struct SpeedSample {
    double value;
    std::uint8_t quality;
};

constexpr score::mw::com::DataTypeMetaInfo kSpeedMetaInfo{sizeof(SpeedSample), alignof(SpeedSample)};
constexpr score::mw::com::DataTypeMetaInfo kCommandMetaInfo{
    score::someip_gateway::serializer::get_size_of_pre_serialized_data(kCommandPayloadSize),
    alignof(RawCommand)};
constexpr std::array<score::mw::com::EventInfo, 2> kDynamicsEvents{{
    {kSpeedEventName, kSpeedMetaInfo},
    {kSpeedAckEventName, kSpeedMetaInfo},
}};
constexpr std::array<score::mw::com::EventInfo, 1> kCommandEvents{{
    {kCommandEventName, kCommandMetaInfo},
}};

std::string ResolveConfigurationPath(const std::string& path) {
    if (std::filesystem::exists(path)) {
        return path;
    }
    for (const char* variable : {"TEST_SRCDIR", "RUNFILES_DIR"}) {
        const char* const root = std::getenv(variable);
        if (root == nullptr || root[0] == '\0') {
            continue;
        }
        const std::string candidate = std::string{root} + "/score_someip_gateway+/" + path;
        if (std::filesystem::exists(candidate)) {
            return candidate;
        }
    }
    return path;
}

std::optional<bool> ParseBooleanInput(const std::string& input) {
    if (input == "true") {
        return true;
    }
    if (input == "false") {
        return false;
    }
    return std::nullopt;
}

// gatewayd creates the shared-memory segment for a remote-produced instance
// asynchronously; a proxy Create() attempted right when the service is
// announced can still race that setup and fail once. Retry briefly instead
// of giving up on the first failure.
score::Result<score::mw::com::GenericProxy> CreateProxyWithRetry(
    const score::mw::com::HandleType& handle) {
    constexpr int kMaxAttempts = 40;
    constexpr auto kRetryDelay = std::chrono::milliseconds{300};
    score::Result<score::mw::com::GenericProxy> result = score::mw::com::GenericProxy::Create(handle);
    for (int attempt = 1; !result.has_value() && attempt < kMaxAttempts; ++attempt) {
        std::this_thread::sleep_for(kRetryDelay);
        result = score::mw::com::GenericProxy::Create(handle);
    }
    return result;
}

std::optional<double> ParseSpeedInput(const std::string& input) {
    try {
        std::size_t parsed = 0U;
        const double value = std::stod(input, &parsed);
        if (parsed != input.size()) {
            return std::nullopt;
        }
        return value;
    } catch (const std::exception&) {
        return std::nullopt;
    }
}

void PrintVehicleMenu() {
    std::cout << "\nVehicle menu\n"
              << "1  High-beam (true/false)\n"
              << "2  Vehicle.speed (number)\n"
              << "q  Quit\n"
              << "Select: " << std::flush;
}

}  // namespace

class VehicleHighBeamApplication {
   public:
    explicit VehicleHighBeamApplication(std::string configuration_path)
        : configuration_path_{std::move(configuration_path)} {}

    int Run() {
        const std::string manifest = ResolveConfigurationPath(configuration_path_);
        if (!std::filesystem::exists(manifest)) {
            score::mw::log::LogError() << "Cannot locate mw::com configuration: " << configuration_path_;
            return EXIT_FAILURE;
        }
        score::mw::com::runtime::InitializeRuntime(score::mw::com::runtime::RuntimeConfiguration{manifest});
        if (!OfferCommandIngressService() || !SubscribeToRemoteService() || !OfferDynamicsService() ||
            !SubscribeToDynamicsService()) {
            Cleanup();
            return EXIT_FAILURE;
        }
        if (std::getenv("PROCESSIDENTIFIER") != nullptr) {
            score::mw::lifecycle::report_running();
        }

        std::ifstream terminal_input{"/dev/tty"};
        std::istream& input_stream = terminal_input.is_open() ? static_cast<std::istream&>(terminal_input)
                                                               : std::cin;
        PrintVehicleMenu();
        std::string input;
        while (std::getline(input_stream, input)) {
            if (input == "q") {
                break;
            }
            if (input == "1") {
                std::cout << "High-beam value (true/false): " << std::flush;
                if (!std::getline(input_stream, input)) {
                    break;
                }
                const auto value = ParseBooleanInput(input);
                if (!value.has_value()) {
                    score::mw::log::LogWarn() << "Invalid high-beam input. Enter true or false.";
                    continue;
                }
                PublishLocalState(value.value());
                PrintVehicleMenu();
                continue;
            }
            if (input == "2") {
                std::cout << kSpeedApiName << " value: " << std::flush;
                if (!std::getline(input_stream, input)) {
                    break;
                }
                const auto speed = ParseSpeedInput(input);
                if (!speed.has_value()) {
                    score::mw::log::LogWarn() << "Invalid speed input. Enter a number.";
                    continue;
                }
                PublishSpeed(speed.value(), 3U);
                PrintVehicleMenu();
                continue;
            }
            score::mw::log::LogWarn() << "Invalid menu option. Select 1, 2, or q.";
        }
        Cleanup();
        return EXIT_SUCCESS;
    }

   private:
    bool OfferCommandIngressService() {
        const auto instance = score::mw::com::InstanceSpecifier::Create(
            std::string{kCommandInstanceSpecifier});
        if (!instance.has_value()) {
            return false;
        }
        score::mw::com::GenericSkeletonServiceElementInfo create_params;
        create_params.events = kCommandEvents;
        auto skeleton_result = score::mw::com::GenericSkeleton::Create(instance.value(), create_params);
        if (!skeleton_result.has_value()) {
            score::mw::log::LogError() << "Cannot create score_app command ingress service";
            return false;
        }
        command_skeleton_.emplace(std::move(skeleton_result).value());
        if (!command_skeleton_->OfferService().has_value()) {
            score::mw::log::LogError() << "Cannot offer score_app command ingress service";
            return false;
        }
        auto events = command_skeleton_->GetEvents();
        const auto command = events.find(kCommandEventName);
        if (command == events.cend()) {
            score::mw::log::LogError() << "Missing high-beam command event";
            return false;
        }
        command_event_ = &command->second;
        return true;
    }

    bool SubscribeToRemoteService() {
        const auto instance = score::mw::com::InstanceSpecifier::Create(std::string{kRxInstanceSpecifier});
        if (!instance.has_value()) {
            return false;
        }
        const auto result = score::mw::com::GenericProxy::StartFindService(
            [this](score::mw::com::ServiceHandleContainer<score::mw::com::HandleType> handles,
                   score::mw::com::FindServiceHandle handle) noexcept {
                OnRemoteServiceAvailable(std::move(handles), handle);
            },
            instance.value());
        return result.has_value();
    }

    bool OfferDynamicsService() {
        const auto instance = score::mw::com::InstanceSpecifier::Create(
            std::string{kDynamicsTxInstanceSpecifier});
        if (!instance.has_value()) {
            return false;
        }
        score::mw::com::GenericSkeletonServiceElementInfo create_params;
        create_params.events = kDynamicsEvents;
        auto skeleton_result = score::mw::com::GenericSkeleton::Create(instance.value(), create_params);
        if (!skeleton_result.has_value()) {
            return false;
        }
        dynamics_skeleton_.emplace(std::move(skeleton_result).value());
        if (!dynamics_skeleton_->OfferService().has_value()) {
            return false;
        }
        auto events = dynamics_skeleton_->GetEvents();
        const auto speed = events.find(kSpeedEventName);
        if (speed == events.cend()) {
            return false;
        }
        dynamics_speed_event_ = &speed->second;
        return true;
    }

    bool SubscribeToDynamicsService() {
        const auto instance = score::mw::com::InstanceSpecifier::Create(
            std::string{kDynamicsRxInstanceSpecifier});
        if (!instance.has_value()) {
            return false;
        }
        const auto result = score::mw::com::GenericProxy::StartFindService(
            [this](score::mw::com::ServiceHandleContainer<score::mw::com::HandleType> handles,
                   score::mw::com::FindServiceHandle handle) noexcept {
                OnDynamicsServiceAvailable(std::move(handles), handle);
            },
            instance.value());
        return result.has_value();
    }

    void PublishLocalState(const bool value) {
        if (command_event_ == nullptr) {
            score::mw::log::LogError() << "score_app command ingress is unavailable";
            return;
        }
        auto sample_result = command_event_->Allocate();
        if (!sample_result.has_value()) {
            score::mw::log::LogError() << "Cannot allocate high-beam command sample";
            return;
        }
        auto sample = std::move(sample_result).value();
        auto* const raw = static_cast<RawCommand*>(sample.Get());
        raw->size = kCommandPayloadSize;
        raw->data[0] = static_cast<std::byte>(value ? 1U : 0U);
        if (!command_event_->Send(std::move(sample)).has_value()) {
            score::mw::log::LogError() << "Cannot publish high-beam command to mw::com";
            return;
        }
        score::mw::log::LogWarn() << "Vehicle menu published high-beam command to mw::com shared memory";
    }

    void PublishSpeed(const double value, const std::uint8_t quality) {
        if (dynamics_speed_event_ == nullptr) {
            score::mw::log::LogError() << "Vehicle dynamics Tx service is unavailable";
            return;
        }
        auto sample_result = dynamics_speed_event_->Allocate();
        if (!sample_result.has_value()) {
            return;
        }
        auto sample = std::move(sample_result).value();
        auto* const data = static_cast<SpeedSample*>(sample.Get());
        data->value = value;
        data->quality = quality;
        if (!dynamics_speed_event_->Send(std::move(sample)).has_value()) {
            score::mw::log::LogError() << "Cannot publish vehicle speed";
            return;
        }
        score::mw::log::LogWarn() << "Vehicle app published " << kSpeedApiName << "=" << value;
    }

    void OnRemoteServiceAvailable(
        score::mw::com::ServiceHandleContainer<score::mw::com::HandleType> handles,
        score::mw::com::FindServiceHandle handle) noexcept {
        if (rx_proxy_.has_value()) {
            return;
        }
        if (handles.empty()) {
            return;
        }
        auto proxy_result = CreateProxyWithRetry(handles.front());
        if (!proxy_result.has_value()) {
            score::mw::log::LogError() << "Cannot create proxy for remote high-beam updates";
            return;
        }
        rx_proxy_.emplace(std::move(proxy_result).value());
        auto events = rx_proxy_->GetEvents();
        const auto event = events.find(kEventName);
        if (event == events.cend()) {
            return;
        }
        rx_event_ = &event->second;
        if (!rx_event_->SetReceiveHandler([this]() noexcept { OnRemoteState(); }).has_value() ||
            !rx_event_->Subscribe(kMaxSampleCount).has_value()) {
            score::mw::log::LogError() << "Cannot subscribe to remote high-beam updates";
            return;
        }
        (void)score::mw::com::GenericProxy::StopFindService(handle);
        score::mw::log::LogWarn() << "Vehicle app subscribed to remote high-beam updates.";
    }

    void OnRemoteState() noexcept {
        const auto samples = rx_event_->GetNewSamples(
            [](score::mw::com::SamplePtr<void> sample) noexcept {
                const auto* const value = static_cast<const bool*>(sample.Get());
                if (value == nullptr) {
                    score::mw::log::LogError() << "Invalid remote high-beam sample";
                    return;
                }
                score::mw::log::LogWarn() << "Vehicle app received Vehicle.Body.Lights.Beam.High.IsOn="
                                          << (*value ? "true" : "false");
            },
            kMaxSampleCount);
        if (!samples.has_value()) {
            score::mw::log::LogError() << "Cannot retrieve remote high-beam samples";
        }
    }

    void OnDynamicsServiceAvailable(
        score::mw::com::ServiceHandleContainer<score::mw::com::HandleType> handles,
        score::mw::com::FindServiceHandle handle) noexcept {
        if (dynamics_proxy_.has_value()) {
            return;
        }
        if (handles.empty()) {
            return;
        }
        auto proxy_result = CreateProxyWithRetry(handles.front());
        if (!proxy_result.has_value()) {
            score::mw::log::LogError() << "Cannot create proxy for remote " << kSpeedApiName;
            return;
        }
        dynamics_proxy_.emplace(std::move(proxy_result).value());
        auto events = dynamics_proxy_->GetEvents();
        const auto speed = events.find(kSpeedEventName);
        if (speed == events.cend()) {
            return;
        }
        dynamics_rx_speed_event_ = &speed->second;
        if (!dynamics_rx_speed_event_->SetReceiveHandler([this]() noexcept { OnRemoteSpeed(); }).has_value() ||
            !dynamics_rx_speed_event_->Subscribe(kMaxSampleCount).has_value()) {
            score::mw::log::LogError() << "Cannot subscribe to remote " << kSpeedApiName;
            return;
        }
        (void)score::mw::com::GenericProxy::StopFindService(handle);
        score::mw::log::LogWarn() << "Vehicle app subscribed to remote " << kSpeedApiName << ".";
    }

    void OnRemoteSpeed() noexcept {
        const auto samples = dynamics_rx_speed_event_->GetNewSamples(
            [](score::mw::com::SamplePtr<void> sample) noexcept {
                const auto* const data = static_cast<const SpeedSample*>(sample.Get());
                if (data == nullptr) {
                    score::mw::log::LogError() << "Invalid remote " << kSpeedApiName << " payload";
                    return;
                }
                score::mw::log::LogWarn() << "Vehicle app received " << kSpeedApiName << "=" << data->value;
            },
            kMaxSampleCount);
        if (!samples.has_value()) {
            score::mw::log::LogError() << "Cannot retrieve remote " << kSpeedApiName << " samples";
        }
    }

    void Cleanup() noexcept {
        if (rx_event_ != nullptr) {
            (void)rx_event_->UnsetReceiveHandler();
            rx_event_->Unsubscribe();
        }
        if (dynamics_rx_speed_event_ != nullptr) {
            (void)dynamics_rx_speed_event_->UnsetReceiveHandler();
            dynamics_rx_speed_event_->Unsubscribe();
        }
        if (dynamics_skeleton_.has_value()) {
            dynamics_skeleton_->StopOfferService();
        }
        if (command_skeleton_.has_value()) {
            command_skeleton_->StopOfferService();
        }
    }

    std::string configuration_path_;
    std::optional<score::mw::com::GenericSkeleton> command_skeleton_;
    std::optional<score::mw::com::GenericSkeleton> dynamics_skeleton_;
    std::optional<score::mw::com::GenericProxy> rx_proxy_;
    std::optional<score::mw::com::GenericProxy> dynamics_proxy_;
    score::mw::com::GenericProxyEvent* rx_event_{nullptr};
    score::mw::com::GenericSkeletonEvent* dynamics_speed_event_{nullptr};
    score::mw::com::GenericProxyEvent* dynamics_rx_speed_event_{nullptr};
    score::mw::com::GenericSkeletonEvent* command_event_{nullptr};
};

int main(int argc, char* argv[]) {
    std::string configuration_path{"score/gatewayd/etc/mw_com_config.json"};
    for (int index = 1; index + 1 < argc; ++index) {
        if (std::string_view{argv[index]} == "--configuration") {
            configuration_path = argv[++index];
        }
    }
    return VehicleHighBeamApplication{std::move(configuration_path)}.Run();
}
