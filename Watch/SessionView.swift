import SwiftUI
import Charts

/// Во время тренировки: страницы листаются колёсиком Digital Crown.
struct SessionView: View {
    @State private var page: Int = UserDefaults.standard.integer(forKey: "demoPage")

    var body: some View {
        TabView(selection: $page) {
            MainPage().tag(0)
            ChartPage().tag(1)
            ProgramPage().tag(2)
        }
        .tabViewStyle(.verticalPage)
    }
}

extension HRZone {
    var color: Color {
        switch self {
        case .below: return .gray
        case .z2: return .green
        case .z3: return .yellow
        case .z4: return .orange
        case .z5: return .red
        }
    }
}

// MARK: - Главный экран

struct MainPage: View {
    @EnvironmentObject var workout: WorkoutManager

    var body: some View {
        if let r = workout.runner, let seg = r.currentSegment {
            content(r, seg)
        } else {
            Text("Программа завершена")
        }
    }

    @ViewBuilder
    private func content(_ r: ProgramRunner, _ seg: Segment) -> some View {
        let t = workout.elapsed
        let segElapsed = r.segmentElapsed(at: t)
        let next = r.nextSegment(at: t)

        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(seg.name)
                    .font(.footnote)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(formatClock(t))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(hrText)
                    .font(.system(size: 50, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(hrColor)
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: "heart.fill").foregroundStyle(.red).font(.caption)
                    if let hr = workout.heartRate {
                        Text(HRZone(bpm: hr).label).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            Text("\(seg.speed.short) км/ч · \(seg.incline.short)%")
                .font(.title3.weight(.semibold))

            Text(segmentProgress(seg, elapsed: segElapsed))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            if r.pending != nil, let next {
                Button {
                    workout.confirmStep()
                } label: {
                    VStack(spacing: 0) {
                        Text("Переключил").font(.caption.weight(.bold))
                        Text("\(next.speed.short) км/ч · \(next.incline.short)%").font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .tint(.green)
            } else if r.pending != nil {
                Button("Завершить") { workout.confirmStep() }
                    .tint(.green)
            } else if let next {
                Text("Далее: \(next.name), \(next.speed.short) км/ч")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 2)
    }

    private var hrText: String {
        guard let hr = workout.heartRate else { return "--" }
        return String(Int(hr.rounded()))
    }

    private var hrColor: Color {
        guard let hr = workout.heartRate else { return .gray }
        return HRZone(bpm: hr).color
    }

    private func segmentProgress(_ seg: Segment, elapsed: TimeInterval) -> String {
        var parts = [formatClock(elapsed)]
        if let a = seg.exit.hrAbove { parts.append("до \(a)↑") }
        if let b = seg.exit.hrBelow { parts.append("до \(b)↓") }
        if let m = seg.exit.maxSeconds { parts.append("из \(formatClock(Double(m)))") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - График пульса

struct ChartPage: View {
    @EnvironmentObject var workout: WorkoutManager

    var body: some View {
        let points = Array(workout.hrSamples.suffix(300))
        VStack(alignment: .leading, spacing: 4) {
            Text("Пульс, последние ~10 мин")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Chart {
                RuleMark(y: .value("Z2 низ", 125))
                    .foregroundStyle(.green.opacity(0.4))
                RuleMark(y: .value("Z2 верх", 140))
                    .foregroundStyle(.green.opacity(0.4))
                ForEach(points) { p in
                    LineMark(x: .value("Время", p.t / 60), y: .value("Пульс", p.bpm))
                        .foregroundStyle(.red)
                }
            }
            .chartYScale(domain: 90...180)
            .chartXAxis(.hidden)
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Вся программа

struct ProgramPage: View {
    @EnvironmentObject var workout: WorkoutManager

    var body: some View {
        List {
            if let r = workout.runner {
                ForEach(Array(r.program.steps.enumerated()), id: \.offset) { index, step in
                    StepRow(step: step, isCurrent: index == r.stepIndex, isDone: index < r.stepIndex, cycles: index == r.stepIndex ? r.cycles : nil)
                }
            }
            Section {
                Button("Пропустить сегмент") { workout.confirmStep() }
                Button("Завершить тренировку", role: .destructive) { workout.end() }
            }
        }
    }
}

struct StepRow: View {
    let step: ProgramStep
    let isCurrent: Bool
    let isDone: Bool
    let cycles: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch step {
            case .single(let s):
                Text(s.name).font(.footnote.weight(isCurrent ? .bold : .regular))
                Text("\(s.speed.short) км/ч · \(s.incline.short)% · \(s.exit.summary)")
                    .font(.caption2).foregroundStyle(.secondary)
            case .repeating(_, let segs, let total):
                Text("Блок \(total / 60) мин" + (cycles.map { ", кругов: \($0)" } ?? ""))
                    .font(.footnote.weight(isCurrent ? .bold : .regular))
                ForEach(segs) { s in
                    Text("\(s.name): \(s.speed.short) км/ч · \(s.exit.summary)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .opacity(isDone ? 0.45 : 1)
        .listRowBackground(isCurrent ? Color.green.opacity(0.2) : nil)
    }
}

// MARK: - Итог

struct SummaryView: View {
    @EnvironmentObject var workout: WorkoutManager
    let runner: ProgramRunner

    var body: some View {
        List {
            Section(runner.program.title) {
                Text("Переходов: \(runner.log.count)")
                ForEach(runner.log) { e in
                    VStack(alignment: .leading) {
                        Text("\(formatClock(e.at)) → \(e.toSegment ?? "конец")").font(.footnote)
                        Text(e.reason.title + (e.heartRate.map { ", пульс \(Int($0))" } ?? ""))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Button("Готово") { workout.summary = nil }
        }
    }
}
