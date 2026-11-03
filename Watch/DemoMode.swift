import Foundation

/// Демо для скриншотов: запуск с аргументами `-screenshots YES -demo YES [-demoPending YES] [-demoPage N]`.
extension WorkoutManager {
    static var isScreenshotRun: Bool { UserDefaults.standard.bool(forKey: "screenshots") }
    static var wantsDemo: Bool { UserDefaults.standard.bool(forKey: "demo") }
    static var wantsDemoPending: Bool { UserDefaults.standard.bool(forKey: "demoPending") }

    /// Простая модель пульса: на беге растёт, на ходьбе падает, на разминке выходит на ~118.
    static func nextDemoHR(_ hr: Double, segment: Segment) -> Double {
        switch segment.kind {
        case .run:
            return min(hr + 0.12, 175)
        case .walk:
            let target = segment.incline >= 4 ? 128.0 : 112.0
            return hr > target ? hr - 0.2 : hr + 0.15
        case .warmup:
            return hr < 118 ? hr + 0.1 : hr - 0.05
        case .recovery, .cooldown:
            return max(hr - 0.5, 100)
        }
    }

    /// Программа Б на ~18-й минуте: идёт беговой отрезок, история пульса уже есть.
    func startDemo() {
        let program = TreadmillProgram.b
        var auto = EngineSettings()
        auto.mode = .auto
        auto.autoDelaySeconds = 3

        var r = ProgramRunner(program: program, settings: auto)
        r.start(at: 0)
        var hr = 96.0
        var samples: [HRPoint] = []
        var t = 0.0
        while t < 4000 {
            guard let seg = r.currentSegment else { break }
            hr = Self.nextDemoHR(hr, segment: seg)
            if Int(t) % 2 == 0 { samples.append(HRPoint(t: t, bpm: hr)) }
            _ = r.update(at: t, heartRate: hr)
            if t >= 1080, let cur = r.currentSegment, cur.kind == .run, r.segmentElapsed(at: t) >= 60 { break }
            t += 1
        }

        r.settings = EngineSettings()   // дальше — режим «Подтверждать»
        if Self.wantsDemoPending {
            for _ in 0..<5 {
                t += 1
                hr = max(hr, 141)
                samples.append(HRPoint(t: t, bpm: hr))
                _ = r.update(at: t, heartRate: hr)
            }
        }

        let start = Date().addingTimeInterval(-t)
        demoMode = true
        demoHR = hr
        runner = r
        summary = nil
        startDate = start
        now = Date()
        heartRate = hr
        hrSamples = samples
        isRunning = true

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
}
