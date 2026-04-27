//
//  AppSettings.swift
//  WeatherAppRemix
//
//  Created by Alex on 26/04/26.
//

import SwiftUI
import Combine

enum LocationMode: String, CaseIterable {
    case auto = "Auto"
    case manual = "Manual"
}

@MainActor
class AppSettings: ObservableObject {

    @Published var useCelsius: Bool = true
    @Published var locationMode: LocationMode = .auto
    @Published var manualCity: String = ""

    func formatTemp(_ celsius: Int) -> String {
        if useCelsius {
            return "\(celsius)°C"
        } else {
            let f = Int((Double(celsius) * 9/5) + 32)
            return "\(f)°F"
        }
    }
}
