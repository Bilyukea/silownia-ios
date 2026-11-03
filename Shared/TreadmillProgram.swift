import Foundation

/// Условие выхода из сегмента: по времени и/или по пульсу.
/// Если заданы и пульс, и время, сегмент заканчивается по тому, что наступит раньше.
struct ExitRule: Codable, Hashable {
    var maxSeconds: Int?
    var hrAbove: Int?
    var hrBelow: Int?

    var isHeartRateDriven: Bool { hrAbove != nil || hrBelow != nil }

    var summary: String {
        var parts: [String] = []
        if let a = hrAbove { parts.append("до пульса \(a)") }
        if let b = hrBelow { parts.append("до пульса \(b)") }
        if let s = maxSeconds {
            parts.append(isHeartRateDriven ? "макс. \(formatClock(Double(s)))" : formatClock(Double(s)))
        }
        return parts.joined(separator: " · ")
    }
}

struct Segment: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case warmup, walk, run, recovery, cooldown
    }

    var id: String
    var name: String
    var kind: Kind
    /// км/ч
    var speed: Double
    /// %
    var incline: Double
    var exit: ExitRule
}

enum ProgramStep: Codable, Hashable {
    case single(Segment)
    /// Сегменты повторяются по кругу, пока блок не продлится `totalSeconds`;
    /// выход из блока — после последнего сегмента круга.
    case repeating(id: String, segments: [Segment], totalSeconds: Int)

    var segments: [Segment] {
        switch self {
        case .single(let s): return [s]
        case .repeating(_, let segs, _): return segs
        }
    }
}

struct TreadmillProgram: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var steps: [ProgramStep]

    /// Оценка длительности по максимальному времени сегментов.
    var estimatedSeconds: Int {
        steps.reduce(0) { sum, step in
            switch step {
            case .single(let s): return sum + (s.exit.maxSeconds ?? 0)
            case .repeating(_, _, let total): return sum + total
            }
        }
    }
}

extension TreadmillProgram {
    static let a = TreadmillProgram(
        id: "A",
        title: "Программа А",
        subtitle: "Тест: ступени скорости, восстановление, 24 мин на дрейф",
        steps: [
            .single(Segment(id: "a1", name: "Разминка, ходьба", kind: .warmup, speed: 5.0, incline: 1, exit: ExitRule(maxSeconds: 300))),
            .single(Segment(id: "a2", name: "Быстрая ходьба", kind: .walk, speed: 6.0, incline: 1, exit: ExitRule(maxSeconds: 180, hrAbove: 160))),
            .single(Segment(id: "a3", name: "Бег 7 км/ч", kind: .run, speed: 7.0, incline: 1, exit: ExitRule(maxSeconds: 180, hrAbove: 160))),
            .single(Segment(id: "a4", name: "Бег 8 км/ч", kind: .run, speed: 8.0, incline: 1, exit: ExitRule(maxSeconds: 180, hrAbove: 160))),
            .single(Segment(id: "a5", name: "Восстановление", kind: .recovery, speed: 4.5, incline: 0, exit: ExitRule(maxSeconds: 120))),
            .single(Segment(id: "a6", name: "Ровный бег, дрейф", kind: .run, speed: 6.5, incline: 1, exit: ExitRule(maxSeconds: 1440, hrAbove: 160))),
            .single(Segment(id: "a7", name: "Заминка", kind: .cooldown, speed: 4.5, incline: 0, exit: ExitRule(maxSeconds: 180)))
        ]
    )

    static let b = TreadmillProgram(
        id: "B",
        title: "Программа Б",
        subtitle: "База: бег‑ходьба по пульсу в Z2",
        steps: [
            .single(Segment(id: "b1", name: "Разминка, ходьба", kind: .warmup, speed: 5.0, incline: 1, exit: ExitRule(maxSeconds: 300))),
            .single(Segment(id: "b2", name: "Ходьба в гору", kind: .walk, speed: 5.5, incline: 5, exit: ExitRule(maxSeconds: 300))),
            .repeating(id: "b-block", segments: [
                Segment(id: "b3", name: "Бег", kind: .run, speed: 6.3, incline: 1, exit: ExitRule(maxSeconds: 240, hrAbove: 140)),
                Segment(id: "b4", name: "Ходьба", kind: .walk, speed: 5.0, incline: 1, exit: ExitRule(maxSeconds: 180, hrBelow: 128))
            ], totalSeconds: 1800),
            .single(Segment(id: "b5", name: "Заминка", kind: .cooldown, speed: 4.5, incline: 0, exit: ExitRule(maxSeconds: 300)))
        ]
    )

    static let builtIn: [TreadmillProgram] = [.a, .b]
}
