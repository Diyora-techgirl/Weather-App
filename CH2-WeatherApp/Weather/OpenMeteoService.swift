import Foundation

// Fetches real weather from Open-Meteo (free, no API key).
// Produces the same WeatherSnapshot shape as MockWeather, so the view
// doesn't care which source it came from.

enum OpenMeteoService {
    static func fetch(lat: Double, lon: Double, name: String) async throws -> WeatherSnapshot {
        async let forecast = fetchForecast(lat: lat, lon: lon)
        async let air = fetchAirQuality(lat: lat, lon: lon)
        let (f, aq) = try await (forecast, air)
        return assemble(name: name, forecast: f, air: aq)
    }

    private static func fetchForecast(lat: Double, lon: Double) async throws -> ForecastResponse {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(
                name: "current", value: "temperature_2m,apparent_temperature,weather_code"),
            URLQueryItem(name: "hourly", value: "temperature_2m"),
            URLQueryItem(name: "daily", value: "sunset,uv_index_max,weather_code"),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        let (data, _) = try await URLSession.shared.data(from: c.url!)
        return try JSONDecoder().decode(ForecastResponse.self, from: data)
    }

    private static func fetchAirQuality(lat: Double, lon: Double) async throws -> AirQualityResponse
    {
        var c = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        c.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: "us_aqi"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        let (data, _) = try await URLSession.shared.data(from: c.url!)
        return try JSONDecoder().decode(AirQualityResponse.self, from: data)
    }

    private static func assemble(name: String, forecast: ForecastResponse, air: AirQualityResponse)
        -> WeatherSnapshot
    {
        let hourly = hourlyForToday(forecast: forecast)
        let highlight = hourly.max { $0.temp < $1.temp }

        return WeatherSnapshot(
            location: name,
            currentTemp: Int(forecast.current.temperature_2m.rounded()),
            advisory: advisory(for: forecast.current.weather_code),
            hourly: hourly,
            highlight: highlight,
            days: buildDays(forecast: forecast),
            sunset: parseLocalTime(forecast.daily.sunset.first ?? ""),
            uvIndex: Int((forecast.daily.uv_index_max.first ?? 0).rounded()),
            uvAdvice: uvAdvice(for: Int((forecast.daily.uv_index_max.first ?? 0).rounded())),
            airQuality: airQualityLabel(aqi: air.current?.us_aqi),
            feelsLike: Int(forecast.current.apparent_temperature.rounded())
        )
    }

    // Subsamples every 3h to match the mock shape (9 points, 0…24).
    private static func hourlyForToday(forecast: ForecastResponse) -> [HourlyPoint] {
        let temps = forecast.hourly.temperature_2m
        return stride(from: 0, through: 24, by: 3).map { h in
            let idx = min(h, temps.count - 1)
            return HourlyPoint(hour: h, temp: Int(temps[idx].rounded()))
        }
    }

    private static func buildDays(forecast: ForecastResponse) -> [DayForecast] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: forecast.utc_offset_seconds) ?? .current

        return forecast.daily.time.enumerated().map { i, s in
            let date = f.date(from: s) ?? Date()
            let code = (i < forecast.daily.weather_code.count) ? forecast.daily.weather_code[i] : 0
            return DayForecast(date: date, iconName: iconName(for: code), isNow: i == 0)
        }
    }

    // Open-Meteo returns "2026-04-21T18:47" in the location's tz with no offset.
    // Parse it as UTC to pull out h/m verbatim, then rehouse onto today in the
    // device tz so `Text(date, format: …)` displays the correct clock string.
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

    private static func uvAdvice(for uv: Int) -> String {
        switch uv {
        case 0...2: return "Low — no protection needed"
        case 3...5: return "Wear sunscreen"
        case 6...7: return "Wearing SPF recommended"
        case 8...10: return "SPF 30+ advised"
        default: return "Avoid midday sun"
        }
    }

    // US AQI buckets — standard thresholds from EPA.
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

    // WMO weather interpretation codes: https://open-meteo.com/en/docs
    private static func advisory(for code: Int) -> String {
        switch code {
        case 0: return "clear skies ahead"
        case 1...3: return "a little cloudy, all good"
        case 45, 48: return "drive careful, it's foggy"
        case 51...67, 80...82: return "take umbrella yaa… , it's raining"
        case 71...77, 85, 86: return "bundle up, it's snowing"
        case 95...99: return "thunderstorm outside, stay in"
        default: return "keep an eye on the sky"
        }
    }

    private static func iconName(for code: Int) -> String {
        switch code {
        case 0: return "sun.min.fill"
        case 1...3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: Response models

private struct ForecastResponse: Decodable {
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
    }
    struct Daily: Decodable {
        let time: [String]
        let sunset: [String]
        let uv_index_max: [Double]
        let weather_code: [Int]
    }
}

private struct AirQualityResponse: Decodable {
    let current: Current?
    struct Current: Decodable {
        let us_aqi: Double?
    }
}
