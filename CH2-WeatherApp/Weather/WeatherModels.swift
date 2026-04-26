import Foundation

struct WeatherSnapshot {
    var location: String
    var currentTemp: Int

    var hourly: [HourlyPoint]
    var days: [DayForecast]

    var sunset: Date
    var uvIndex: Int
    var uvAdvice: String
    var airQuality: String
    var feelsLike: Int

    var highlight: HourlyPoint?
    var raw: ForecastResponse?
}

struct HourlyPoint: Identifiable {
    var hour: Int   //
    var temp: Int
    var rain: Double

    var id: Int { hour }
}

struct DayForecast: Identifiable {
    var date: Date
    var iconName: String
    var isNow: Bool = false

    var id: TimeInterval { date.timeIntervalSince1970 }

    var label: String {
        if isNow { return "Now" }
        return String(Calendar.current.component(.day, from: date))
    }
}
