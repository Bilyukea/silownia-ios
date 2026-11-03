import SwiftUI

struct StartView: View {
    @EnvironmentObject var workout: WorkoutManager
    @AppStorage("transitionMode") private var modeRaw: String = TransitionMode.confirm.rawValue
    @AppStorage("autoDelaySeconds") private var autoDelay: Int = 10

    private var settings: EngineSettings {
        var s = EngineSettings()
        s.mode = TransitionMode(rawValue: modeRaw) ?? .confirm
        s.autoDelaySeconds = autoDelay
        return s
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Дорожка") {
                    ForEach(TreadmillProgram.builtIn) { program in
                        Button {
                            workout.start(program: program, settings: settings)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(program.title).font(.headline)
                                Text(program.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text("≈\(program.estimatedSeconds / 60) мин")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Переходы по пульсу") {
                    Picker("Режим", selection: $modeRaw) {
                        ForEach(TransitionMode.allCases) { mode in
                            Text(mode.shortTitle).tag(mode.rawValue)
                        }
                    }
                    if modeRaw == TransitionMode.auto.rawValue {
                        Stepper(value: $autoDelay, in: 0...60, step: 5) {
                            Text("Задержка \(autoDelay) с")
                        }
                    }
                }
                if let err = workout.lastError {
                    Section {
                        Text(err).font(.caption2).foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Siłownia")
        }
        .onAppear { workout.requestAuthorization() }
    }
}
