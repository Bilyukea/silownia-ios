import Foundation
import HealthKit
import WatchKit
import Combine

/// Тренировка на часах: HealthKit‑сессия (пульс) + ход программы дорожки.
final class WorkoutManager: NSObject, ObservableObject {
    let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    var timer: Timer?
    /// Демо‑режим для скриншотов в симуляторе: пульс синтетический, HealthKit не используется.
    var demoMode = false
    var demoHR: Double = 118

    @Published var heartRate: Double?
    @Published var hrSamples: [HRPoint] = []
    @Published var isRunning = false
    @Published var runner: ProgramRunner?
    @Published var startDate: Date?
    @Published var now = Date()
    @Published var lastError: String?
    @Published var summary: ProgramRunner?

    var elapsed: TimeInterval {
        guard let startDate else { return 0 }
        return now.timeIntervalSince(startDate)
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        var read: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) { read.insert(hr) }
        healthStore.requestAuthorization(toShare: share, read: read) { _, error in
            if let error {
                DispatchQueue.main.async { self.lastError = error.localizedDescription }
            }
        }
    }

    func start(program: TreadmillProgram, settings: EngineSettings) {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .indoor

        do {
            let s = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let b = s.associatedWorkoutBuilder()
            b.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            s.delegate = self
            b.delegate = self
            session = s
            builder = b
        } catch {
            lastError = error.localizedDescription
            // Без HealthKit программа всё равно идёт по времени.
        }

        let start = Date()
        session?.startActivity(with: start)
        builder?.beginCollection(withStart: start) { _, _ in }

        var r = ProgramRunner(program: program, settings: settings)
        r.start(at: 0)
        runner = r
        summary = nil
        startDate = start
        now = start
        heartRate = nil
        hrSamples = []
        isRunning = true

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func tick() {
        guard var r = runner else { return }
        now = Date()
        if demoMode, let seg = r.currentSegment {
            demoHR = Self.nextDemoHR(demoHR, segment: seg)
            heartRate = demoHR
            hrSamples.append(HRPoint(t: elapsed, bpm: demoHR))
        }
        let t = elapsed
        let event = r.update(at: t, heartRate: heartRate)
        runner = r
        handle(event)
        // Пока переход не подтверждён — напоминаем вибрацией каждые 5 секунд.
        if r.pending != nil, event == .none, Int(t) % 5 == 0 {
            WKInterfaceDevice.current().play(.notification)
        }
    }

    /// «Переключил дорожку» / «Далее».
    func confirmStep() {
        guard var r = runner else { return }
        now = Date()
        let event = r.confirm(at: elapsed, heartRate: heartRate)
        runner = r
        handle(event)
    }

    private func handle(_ event: ProgramRunner.Event) {
        switch event {
        case .none:
            break
        case .pending:
            WKInterfaceDevice.current().play(.notification)
        case .advanced:
            WKInterfaceDevice.current().play(.directionUp)
        case .finished:
            WKInterfaceDevice.current().play(.success)
            end()
        }
    }

    func end() {
        timer?.invalidate()
        timer = nil
        summary = runner
        session?.end()
        session = nil
        isRunning = false
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        if toState == .ended {
            builder?.endCollection(withEnd: date) { [weak self] _, _ in
                self?.builder?.finishWorkout { _, _ in }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.lastError = error.localizedDescription }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(hrType),
              let stats = workoutBuilder.statistics(for: hrType),
              let quantity = stats.mostRecentQuantity() else { return }
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
        DispatchQueue.main.async {
            self.heartRate = bpm
            if let s = self.startDate {
                self.hrSamples.append(HRPoint(t: Date().timeIntervalSince(s), bpm: bpm))
            }
        }
    }
}
