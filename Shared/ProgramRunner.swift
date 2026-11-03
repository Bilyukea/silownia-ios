import Foundation

enum TransitionMode: String, Codable, CaseIterable, Identifiable {
    /// Вибрация, затем подтверждение касанием после переключения дорожки.
    case confirm
    /// Автоматический переход после задержки.
    case auto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .confirm: return "Вибрация + подтверждение"
        case .auto: return "Автоматически"
        }
    }

    var shortTitle: String {
        switch self {
        case .confirm: return "Подтверждать"
        case .auto: return "Авто"
        }
    }
}

struct EngineSettings: Codable, Hashable {
    var mode: TransitionMode = .confirm
    /// В авто‑режиме: сколько секунд пульс должен держаться за порогом.
    var autoDelaySeconds: Int = 10
    /// В режиме подтверждения: фильтр от коротких скачков пульса.
    var confirmFilterSeconds: Int = 3

    var holdSeconds: Int { mode == .auto ? autoDelaySeconds : confirmFilterSeconds }
}

struct TransitionLogEntry: Codable, Hashable, Identifiable {
    enum Reason: String, Codable {
        case time, hrAbove, hrBelow, manual

        var title: String {
            switch self {
            case .time: return "по времени"
            case .hrAbove: return "пульс выше порога"
            case .hrBelow: return "пульс ниже порога"
            case .manual: return "вручную"
            }
        }
    }

    var id = UUID()
    /// Секунды от старта тренировки.
    var at: TimeInterval
    var fromSegment: String
    var toSegment: String?
    var reason: Reason
    var heartRate: Double?
}

/// Ход программы. Чистая логика без HealthKit: время передаётся снаружи (секунды от старта).
struct ProgramRunner {
    enum Event: Equatable {
        case none
        case pending(TransitionLogEntry.Reason)
        case advanced(TransitionLogEntry.Reason)
        case finished
    }

    let program: TreadmillProgram
    var settings: EngineSettings

    private(set) var stepIndex = 0
    private(set) var blockSegmentIndex = 0
    private(set) var blockStartedAt: TimeInterval = 0
    private(set) var segmentStartedAt: TimeInterval = 0
    private(set) var conditionSince: TimeInterval?
    private(set) var pending: TransitionLogEntry.Reason?
    private(set) var finished = false
    private(set) var log: [TransitionLogEntry] = []
    /// Сколько полных кругов пройдено в текущем повторяющемся блоке.
    private(set) var cycles = 0

    init(program: TreadmillProgram, settings: EngineSettings) {
        self.program = program
        self.settings = settings
    }

    mutating func start(at t: TimeInterval) {
        stepIndex = 0
        blockSegmentIndex = 0
        blockStartedAt = t
        segmentStartedAt = t
        conditionSince = nil
        pending = nil
        finished = program.steps.isEmpty
        log = []
        cycles = 0
    }

    var currentSegment: Segment? {
        guard !finished, stepIndex < program.steps.count else { return nil }
        let segs = program.steps[stepIndex].segments
        guard !segs.isEmpty else { return nil }
        return segs[blockSegmentIndex % segs.count]
    }

    /// Номер сегмента для показа: «3 из 7» (для блока — номер шага программы).
    var stepNumber: Int { min(stepIndex + 1, program.steps.count) }

    var isInRepeatingBlock: Bool {
        guard !finished, stepIndex < program.steps.count else { return false }
        if case .repeating = program.steps[stepIndex] { return true }
        return false
    }

    func segmentElapsed(at t: TimeInterval) -> TimeInterval { max(0, t - segmentStartedAt) }

    func blockElapsed(at t: TimeInterval) -> TimeInterval { max(0, t - blockStartedAt) }

    func nextSegment(at t: TimeInterval) -> Segment? {
        guard !finished, stepIndex < program.steps.count else { return nil }
        switch program.steps[stepIndex] {
        case .single:
            return Self.firstSegment(program.steps, from: stepIndex + 1)
        case .repeating(_, let segs, let total):
            let i = blockSegmentIndex % segs.count
            if i < segs.count - 1 { return segs[i + 1] }
            if t - blockStartedAt >= Double(total) {
                return Self.firstSegment(program.steps, from: stepIndex + 1)
            }
            return segs.first
        }
    }

    private static func firstSegment(_ steps: [ProgramStep], from i: Int) -> Segment? {
        guard i < steps.count else { return nil }
        return steps[i].segments.first
    }

    /// Вызывается раз в секунду.
    mutating func update(at t: TimeInterval, heartRate: Double?) -> Event {
        guard let seg = currentSegment else { return .none }
        if pending != nil { return .none }

        var hrReason: TransitionLogEntry.Reason?
        if let hr = heartRate {
            if let a = seg.exit.hrAbove, hr >= Double(a) {
                hrReason = .hrAbove
            } else if let b = seg.exit.hrBelow, hr <= Double(b) {
                hrReason = .hrBelow
            }
        }
        if hrReason != nil {
            if conditionSince == nil { conditionSince = t }
        } else {
            conditionSince = nil
        }

        var trigger: TransitionLogEntry.Reason?
        if let since = conditionSince, let r = hrReason, t - since >= Double(settings.holdSeconds) {
            trigger = r
        } else if let maxS = seg.exit.maxSeconds, t - segmentStartedAt >= Double(maxS) {
            trigger = .time
        }
        guard let reason = trigger else { return .none }

        switch settings.mode {
        case .confirm:
            pending = reason
            return .pending(reason)
        case .auto:
            advance(at: t, reason: reason, heartRate: heartRate)
            return finished ? .finished : .advanced(reason)
        }
    }

    /// Подтверждение перехода (или ручной переход, если ничего не ожидалось).
    mutating func confirm(at t: TimeInterval, heartRate: Double?) -> Event {
        guard currentSegment != nil else { return .none }
        let reason = pending ?? .manual
        pending = nil
        advance(at: t, reason: reason, heartRate: heartRate)
        return finished ? .finished : .advanced(reason)
    }

    private mutating func advance(at t: TimeInterval, reason: TransitionLogEntry.Reason, heartRate: Double?) {
        guard let from = currentSegment else { return }
        conditionSince = nil
        switch program.steps[stepIndex] {
        case .single:
            moveToNextStep(at: t)
        case .repeating(_, let segs, let total):
            let lastInCycle = blockSegmentIndex % segs.count == segs.count - 1
            if lastInCycle { cycles += 1 }
            if lastInCycle && t - blockStartedAt >= Double(total) {
                moveToNextStep(at: t)
            } else {
                blockSegmentIndex += 1
                segmentStartedAt = t
            }
        }
        log.append(TransitionLogEntry(at: t, fromSegment: from.name, toSegment: currentSegment?.name, reason: reason, heartRate: heartRate))
    }

    private mutating func moveToNextStep(at t: TimeInterval) {
        stepIndex += 1
        blockSegmentIndex = 0
        blockStartedAt = t
        segmentStartedAt = t
        cycles = 0
        if stepIndex >= program.steps.count { finished = true }
    }
}
