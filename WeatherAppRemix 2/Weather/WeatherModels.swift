import Foundation

// Plain value types so the mock source can be swapped for a real API later
// without touching the views.

struct WeatherSnapshot {
    var location: String
    var currentTemp: Int        // Celsius
    var advisory: String        // speech-bubble text
    var hourly: [HourlyPoint]   // points for the temperature chart
    var highlight: HourlyPoint? // the single emphasized point on the chart
    var days: [DayForecast]     // horizontal day pills
    var sunset: Date
    var uvIndex: Int
    var uvAdvice: String
    var airQuality: String
    var feelsLike: Int
}

struct HourlyPoint: Identifiable {
    var hour: Int               // 0...24
    var temp: Int               // Celsius
    var id: Int { hour }
}

struct DayForecast: Identifiable {
    var date: Date
    var iconName: String        // SF Symbol name
    var isNow: Bool = false

    var id: TimeInterval { date.timeIntervalSince1970 }

    // First pill reads "Now"; the rest show the day-of-month number.
    var label: String {
        if isNow { return "Now" }
        return String(Calendar.current.component(.day, from: date))
    }
}
