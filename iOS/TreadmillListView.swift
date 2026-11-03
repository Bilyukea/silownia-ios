import SwiftUI

struct TreadmillListView: View {
    /// Для скриншотов: запуск с аргументом `-openProgram B`.
    @State private var path: [TreadmillProgram] = {
        if let id = UserDefaults.standard.string(forKey: "openProgram"),
           let p = TreadmillProgram.builtIn.first(where: { $0.id == id }) {
            return [p]
        }
        return []
    }()

    var body: some View {
        NavigationStack(path: $path) {
            List(TreadmillProgram.builtIn) { program in
                NavigationLink(value: program) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.title).font(.headline)
                        Text(program.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        Text("≈\(program.estimatedSeconds / 60) мин").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Дорожка")
            .navigationDestination(for: TreadmillProgram.self) { program in
                ProgramDetailView(program: program)
            }
        }
    }
}

struct ProgramDetailView: View {
    let program: TreadmillProgram

    var body: some View {
        List {
            Section {
                Text("Тренировка запускается на часах: Siłownia → \(program.title). Часы ведут программу по пульсу и подают вибрацию при каждом переходе.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(program.steps.enumerated()), id: \.offset) { index, step in
                Section(sectionTitle(index: index, step: step)) {
                    ForEach(step.segments) { seg in
                        SegmentRow(segment: seg)
                    }
                }
            }
        }
        .navigationTitle(program.title)
    }

    private func sectionTitle(index: Int, step: ProgramStep) -> String {
        switch step {
        case .single:
            return "Шаг \(index + 1)"
        case .repeating(_, _, let total):
            return "Шаг \(index + 1) · повторять \(total / 60) мин"
        }
    }
}

struct SegmentRow: View {
    let segment: Segment

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.name)
                Text(segment.exit.summary)
                    .font(.caption)
                    .foregroundStyle(segment.exit.isHeartRateDriven ? Color.green : Color.secondary)
            }
            Spacer()
            Text("\(segment.speed.short) км/ч · \(segment.incline.short)%")
                .font(.callout.monospacedDigit())
        }
    }
}
