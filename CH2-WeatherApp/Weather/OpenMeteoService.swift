import Foundation

enum OpenMeteoService {

    static func fetch(lat: Double, lon: Double, name: String) async throws -> WeatherSnapshot {

        async let forecast = fetchForecast(lat: lat, lon: lon)
        async let air = fetchAirQuality(lat: lat, lon: lon)

        let (f, aq) = try await (forecast, air)

        return assemble(name: name, forecast: f, air: aq)
    }

    // MARK: - FORECAST

    private static func fetchForecast(lat: Double, lon: Double) async throws -> ForecastResponse {

        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!

        c.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),

            URLQueryItem(name: "current",
                         value: "temperature_2m,apparent_temperature,weather_code"),

            URLQueryItem(name: "hourly",
                         value: "temperature_2m,precipitation"),

            URLQueryItem(name: "daily",
                         value: "sunset,uv_index_max,weather_code"),

            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        let (data, _) = try await URLSession.shared.data(from: c.url!)
        return try JSONDecoder().decode(ForecastResponse.self, from: data)
    }

    // MARK: - AIR QUALITY

    private static func fetchAirQuality(lat: Double, lon: Double) async throws -> AirQualityResponse {

        var c = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!

        c.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: "us_aqi"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        let (data, _) = try await URLSession.shared.data(from: c.url!)
        return try JSONDecoder().decode(AirQualityResponse.self, from: data)
    }

    // MARK: - ASSEMBLE (FIXED)

    private static func assemble(
        name: String,
        forecast: ForecastResponse,
        air: AirQualityResponse
    ) -> WeatherSnapshot {

        // ✅ Build hourly correctly ONCE here
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let hourly: [HourlyPoint] = zip(
            forecast.hourly.time,
            zip(forecast.hourly.temperature_2m, forecast.hourly.precipitation)
        ).compactMap { time, values in

            guard let date = formatter.date(from: time) else { return nil }

            let hour = Calendar.current.component(.hour, from: date)

            return HourlyPoint(
                hour: hour,
                temp: Int(values.0.rounded()),
                rain: values.1
            )
        }

        return WeatherSnapshot(
            location: name,
            currentTemp: Int(forecast.current.temperature_2m.rounded()),

            // ✅ FIX: REAL DATA HERE
            hourly: hourly,

            days: buildDays(forecast: forecast),

            sunset: parseLocalTime(forecast.daily.sunset.first ?? ""),
            uvIndex: Int((forecast.daily.uv_index_max.first ?? 0).rounded()),
            uvAdvice: uvAdvice(for: Int((forecast.daily.uv_index_max.first ?? 0).rounded())),
            airQuality: airQualityLabel(aqi: air.current?.us_aqi),
            feelsLike: Int(forecast.current.apparent_temperature.rounded()),

            highlight: nil,
            raw: forecast
        )
    }

    // MARK: - DAYS

    private static func buildDays(forecast: ForecastResponse) -> [DayForecast] {

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: forecast.utc_offset_seconds) ?? .current

        return forecast.daily.time.enumerated().map { i, s in
            let date = f.date(from: s) ?? Date()
            let code = forecast.daily.weather_code[safe: i] ?? 0

            return DayForecast(
                date: date,
                iconName: iconName(for: code),
                isNow: i == 0
            )
        }
    }

    // MARK: - TIME

    private static func parseLocalTime(_ s: String) -> Date {

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")

        guard let utc = f.date(from: s) else { return Date() }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        let h = cal.component(.hour, from: utc)
        let m = cal.component(.minute, from: utc)

        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }

    // MARK: - HELPERS

    static func uvAdvice(for uv: Int) -> String {
        switch uv {
        case 0...2: return "Low — no protection needed"
        case 3...5: return "Wear sunscreen"
        case 6...7: return "Wearing SPF recommended"
        case 8...10: return "SPF 30+ advised"
        default: return "Avoid midday sun"
        }
    }

    private static func airQualityLabel(aqi: Double?) -> String {
        guard let v = aqi else { return "Unknown" }
        switch v {
        case ..<51: return "Good"
        case ..<101: return "Moderate"
        case ..<151: return "Unhealthy (Sensitive)"
        case ..<201: return "Unhealthy"
        case ..<301: return "Very Unhealthy"
        default: return "Hazardous"
        }
    }

    private static func iconName(for code: Int) -> String {
        switch code {
        case 0: return "sun.min.fill"
        case 1...3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...82: return "cloud.rain.fill"
        case 95...99: return "cloud.bolt.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - MODELS

struct ForecastResponse: Decodable {
    let utc_offset_seconds: Int
    let current: Current
    let hourly: Hourly
    let daily: Daily

    struct Current: Decodable {
        let temperature_2m: Double
        let apparent_temperature: Double
        let weather_code: Int
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let precipitation: [Double]
    }

    struct Daily: Decodable {
        let time: [String]
        let sunset: [String]
        let uv_index_max: [Double]
        let weather_code: [Int]
    }
}

struct AirQualityResponse: Decodable {
    let current: Current?

    struct Current: Decodable {
        let us_aqi: Double?
    }
}

// MARK: - SAFE ARRAY

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
