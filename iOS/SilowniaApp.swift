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
    var body: some View {
        TabView {
            StrengthView()
                .tabItem { Label("Силовые", systemImage: "dumbbell") }
            TreadmillListView()
                .tabItem { Label("Дорожка", systemImage: "figure.run") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
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
