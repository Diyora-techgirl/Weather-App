import Foundation

// Single place for fake data. When the real API lands, replace `sample`
// with a fetcher that returns the same `WeatherSnapshot` shape.

enum MockWeather {
    // Computed so dates stay fresh across days (midnight rollover, previews, etc.)
    static var sample: WeatherSnapshot {
        WeatherSnapshot(
            location: "Denpasar",
            currentTemp: 15,
            advisory: "take umbrella yaa… , it's raining",
            hourly: [
                HourlyPoint(hour: 0, temp: 22),
                HourlyPoint(hour: 3, temp: 30),
                HourlyPoint(hour: 6, temp: 25),
                HourlyPoint(hour: 9, temp: 20),
                HourlyPoint(hour: 12, temp: 26),
                HourlyPoint(hour: 15, temp: 35),
                HourlyPoint(hour: 18, temp: 28),
                HourlyPoint(hour: 21, temp: 22),
                HourlyPoint(hour: 24, temp: 20),
            ],
            highlight: HourlyPoint(hour: 15, temp: 35),
            days: nextSevenDays(),
            sunset: sunsetToday(hour: 18, minute: 47),
            uvIndex: 8,
            uvAdvice: "Wearing SPF recommended",
            airQuality: "Moderate",
            feelsLike: 17
        )
    }

    // Today + next 6 days; first entry is flagged as "Now".
    private static func nextSevenDays() -> [DayForecast] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: today) ?? today
            return DayForecast(date: date, iconName: "sun.min.fill", isNow: offset == 0)
        }
    }

    private static func sunsetToday(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour, minute: minute, second: 0, of: Date()
        ) ?? Date()
    }
}
