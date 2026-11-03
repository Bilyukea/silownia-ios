import SwiftUI

@main
struct SilowniaWatchApp: App {
    @StateObject private var workout = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(workout)
        }
    }
}

struct WatchRootView: View {
    @EnvironmentObject var workout: WorkoutManager

    var body: some View {
        if workout.isRunning {
            SessionView()
        } else if let s = workout.summary {
            SummaryView(runner: s)
        } else {
            StartView()
        }
    }
}
