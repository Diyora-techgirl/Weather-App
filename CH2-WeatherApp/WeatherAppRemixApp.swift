//
//  WeatherAppRemixApp.swift
//  WeatherAppRemix
//
//  Created by Asadullokh Nurullaev on 21/04/26.
//

import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .portrait
    }
}

@main
struct WeatherAppRemixApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            WeatherView()
        }
    }
}
