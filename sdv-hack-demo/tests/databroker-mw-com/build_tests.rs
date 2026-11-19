// SPDX-License-Identifier: Apache-2.0
include!(env!("COMPOSITION_BUILD_RS"));

#[cfg(all(test, unix))]
mod archive_merge_tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;

    #[test]
    fn alwayslink_merge_replaces_read_only_staged_archives() {
        let root = env::current_dir().unwrap();
        let out = root.join("out");
        fs::create_dir(&out).unwrap();
        let archive = root.join("input.lo");
        fs::write(&archive, b"!<arch>\n").unwrap();
        fs::set_permissions(&archive, fs::Permissions::from_mode(0o444)).unwrap();
        let archives = vec![archive];
        assert!(create_alwayslink_archive(&out, &archives).is_some());
        assert!(fs::metadata(out.join("score_com_alwayslink_part_0.a"))
            .unwrap()
            .permissions()
            .readonly());
        assert!(create_alwayslink_archive(&out, &archives).is_some());
        assert_eq!(
            fs::read(out.join("libscore_com_alwayslink.a")).unwrap(),
            b"!<arch>\n"
        );
    }
}
