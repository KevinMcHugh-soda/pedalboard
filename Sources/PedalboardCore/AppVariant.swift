/// Which copy of the app this build is.
///
/// A build from a working checkout is the dev variant: its own name, bundle
/// identifier and defaults domain, so testing a change never touches the copy
/// in the menu bar. Only `make install`, which builds `origin/main`, compiles
/// the installed variant (`-D PEDALBOARD_INSTALLED`). See
/// plans/build-system.md.
public enum AppVariant: Sendable {
    case dev
    case installed

    public static var current: AppVariant {
        #if PEDALBOARD_INSTALLED
        .installed
        #else
        .dev
        #endif
    }

    /// The bundle's name.
    public var appName: String {
        switch self {
        case .dev: "Pedalboard Dev"
        case .installed: "Pedalboard"
        }
    }

    /// The bundle identifier, which is also the UserDefaults domain — the CLI
    /// reads the app's settings through it.
    public var bundleIdentifier: String {
        switch self {
        case .dev: "dev.pedalboard.app.dev"
        case .installed: "dev.pedalboard.app"
        }
    }
}
