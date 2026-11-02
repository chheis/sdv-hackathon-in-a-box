/********************************************************************************
 * Copyright (c) 2025 Contributors to the Eclipse Foundation
 *
 * SPDX-License-Identifier: Apache-2.0
 ********************************************************************************/

use score_com::{
    interface,
    CommData,
    ProviderInfo,
    Publisher,
    Reloc,
    Subscriber,
};

use score_log::ScoreDebug;

#[derive(Debug, Reloc, CommData, ScoreDebug)]
#[repr(C)]
#[comm_data(id = "SpeedSample")]
pub struct SpeedSample {
    pub value: f64,
    pub quality: u8,
}

#[derive(Debug, Reloc, CommData, ScoreDebug)]
#[repr(C)]
#[comm_data(id = "SpeedAck")]
pub struct SpeedAck {
    pub value: f64,
    pub quality: u8,
}

interface!(
    interface VehicleDynamicsService {
        Id = "VehicleDynamicsService",

        // Producer -> Consumer
        speed: Event<SpeedSample>,

        // mw_com_provider -> SCORE Consumer
        speedAck: Event<SpeedAck>,
    }
);