// AtrestPreviewApp.swift
// App entry point. No logic belongs here.

import SwiftUI

@main
struct AtrestPreviewApp: App {
    @StateObject private var store = SceneStore()

    var body: some Scene {
        WindowGroup {
            MasterSceneLab()
                .environmentObject(store)
        }
    }
}
