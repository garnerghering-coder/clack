Read ../../CLAUDE.md (the repository's rules) and ../../docs/SWIFT_PORT.md (the plan for this app) before doing anything.

Every update that changes the app: bump `CURRENT_PROJECT_VERSION` on the `Clack` and `ClackWidgetsExtension` targets (via the Xcode tools, never the pbxproj; both must match). Settings shows it ("Version 1.0 (build N)") with the commit the hosted server runs. Tell the owner the version at the end of each update, and update the hosted server after he pushes (see the notes on how to reach it).
