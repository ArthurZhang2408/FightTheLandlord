//
//  FightTheLandloardApp.swift
//  FightTheLandlord
//
//  Created by Arthur Zhang on 2024-10-04.
//

import FirebaseCore
import SwiftUI
import UIKit

/// Reports the orientations the fullscreen chart asks for (see `OrientationController`).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationController.mask
    }
}

@main
struct FightTheLandloardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var store: DataStore
    @State private var settings: AppSettings
    @State private var session: MatchSession
    @State private var router = AppRouter()

    init() {
        FirebaseApp.configure()
        let store = DataStore.shared
        let settings = AppSettings.shared
        let session = MatchSession(store: store)
        session.idleTimeout = settings.autoFinishInterval
        _store = State(initialValue: store)
        _settings = State(initialValue: settings)
        _session = State(initialValue: session)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(store)
                .environment(settings)
                .environment(session)
                .environment(router)
                .tint(AppTheme.accent)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background:
                        session.appDidEnterBackground()
                    case .active:
                        session.appDidBecomeActive()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
                .onChange(of: settings.autoFinishHours) { _, hours in
                    session.idleTimeout = hours * 3600
                }
        }
    }
}
