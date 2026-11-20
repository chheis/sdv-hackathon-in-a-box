// SPDX-License-Identifier: Apache-2.0
include!(env!("COMPOSITION_MAIN_RS"));

#[cfg(test)]
mod demo_tests {
    use super::*;
    use mw_com_provider::config::ActuationBinding;

    #[test]
    fn direct_mode_disables_only_separate_body_tx_bindings() {
        let mut config = ProviderConfig::load_json(env!("COMPOSITION_PROVIDER_CONFIG")).unwrap();
        config.mappings.truncate(1);
        config.mappings[0].direction = Direction::Bidirectional;
        config.mappings[0].actuation_binding = Some(ActuationBinding {
            service: "/body_control_module_tx".into(),
            instance: "test_tx".into(),
            member: "high_beam".into(),
        });
        let mut unrelated = config.mappings[0].clone();
        unrelated.actuation_binding.as_mut().unwrap().service = "/other_tx".into();
        let mut unbound = config.mappings[0].clone();
        unbound.actuation_binding = None;
        config.mappings.extend([unrelated, unbound]);

        configure_command_mode(&mut config, false);
        assert!(config.mappings[0].actuation_binding.is_some());
        assert!(config
            .mappings
            .iter()
            .all(|mapping| { mapping.direction == Direction::Bidirectional }));

        configure_command_mode(&mut config, true);
        assert_eq!(config.mappings[0].direction, Direction::Datapoint);
        assert!(config.mappings[0].actuation_binding.is_none());
        assert_eq!(config.mappings[1].direction, Direction::Bidirectional);
        assert_eq!(
            config.mappings[1]
                .actuation_binding
                .as_ref()
                .unwrap()
                .service,
            "/other_tx"
        );
        assert_eq!(config.mappings[2].direction, Direction::Bidirectional);
        assert!(config.mappings[2].actuation_binding.is_none());
    }
}
