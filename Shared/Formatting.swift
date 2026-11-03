import Foundation

func formatClock(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds.rounded(.down)))
    return String(format: "%d:%02d", s / 60, s % 60)
}

extension Double {
    /// 6.5 → «6,5», 5.0 → «5»
    var short: String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: self)) ?? String(self)
    }
}

struct HRPoint: Identifiable, Hashable, Codable {
    var t: TimeInterval
    var bpm: Double
    var id: TimeInterval { t }
}

/// Пульсовые зоны пользователя.
enum HRZone {
    case below, z2, z3, z4, z5

    init(bpm: Double) {
        switch bpm {
        case ..<125: self = .below
        case ..<141: self = .z2
        case ..<153: self = .z3
        case ..<170: self = .z4
        default: self = .z5
        }
    }

    var label: String {
        switch self {
        case .below: return "Z1"
        case .z2: return "Z2"
        case .z3: return "Z3"
        case .z4: return "Z4"
        case .z5: return "Z5"
        }
    }
}
