import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Пульсовые зоны") {
                    zoneRow("Z2", "125–140")
                    zoneRow("Z3", "141–152")
                    zoneRow("Z4", "153–169")
                }
                Section {
                    Text("Режим переходов («Подтверждать» или «Авто» с задержкой) пока выбирается на часах перед стартом. Синхронизация настроек с iPhone появится в следующей версии.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("О приложении") {
                    LabeledContent("Версия", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                }
            }
            .navigationTitle("Настройки")
        }
    }

    private func zoneRow(_ name: String, _ range: String) -> some View {
        LabeledContent(name, value: "\(range) уд/мин")
    }
}
