import Observation

/// Runtime state the settings window displays.
@MainActor
@Observable
final class AppStatus {
    var accessibilityGranted = false
    /// The latest thing that happened, e.g. "Typed 42 characters".
    var message = "Idle"
    var hotKeyError: String?
}
