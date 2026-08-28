import Foundation

enum MotionStyle: String, CaseIterable, Identifiable {
    case nativeSnappy
    case spatialSpring
    case softMaterial

    static let preferenceKey = "motionStyle"
    static let defaultValue: MotionStyle = .nativeSnappy

    var id: String { rawValue }

    static func current(in defaults: UserDefaults = .standard) -> MotionStyle {
        MotionStyle(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? defaultValue
    }
}

enum MotionSpeed: String, CaseIterable, Identifiable {
    case fast
    case normal
    case slow

    static let preferenceKey = "motionSpeed"
    static let defaultValue: MotionSpeed = .normal

    var id: String { rawValue }

    var durationMultiplier: Double {
        switch self {
        case .fast: 0.75
        case .normal: 1.0
        case .slow: 1.5
        }
    }

    static func current(in defaults: UserDefaults = .standard) -> MotionSpeed {
        MotionSpeed(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? defaultValue
    }
}

enum MotionTiming {
    static let drawerEnter = 0.22
    static let drawerExit = 0.18
    static let search = 0.20
    static let filter = 0.24
    static let cardTransition = 0.20
    static let cardReveal = 0.20
    static let drawerCardEntrance = 0.22
}
