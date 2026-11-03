import SwiftUI

@main
struct SilowniaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    /// Для скриншотов: запуск с аргументом `-tab N`.
    @State private var tab: Int = UserDefaults.standard.integer(forKey: "tab")

    var body: some View {
        TabView(selection: $tab) {
            StrengthView()
                .tabItem { Label("Силовые", systemImage: "dumbbell") }
                .tag(0)
            TreadmillListView()
                .tabItem { Label("Дорожка", systemImage: "figure.run") }
                .tag(1)
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
                .tag(2)
        }
    }
}

struct StrengthView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Силовые переезжают",
                systemImage: "dumbbell",
                description: Text("Планы и журнал силовых из веб‑приложения появятся в следующей версии.")
            )
            .navigationTitle("Силовые")
        }
    }
}
