import SwiftUI
import Charts

struct WeatherView: View {

    // MARK: - STATE
    @State private var weather: WeatherSnapshot
    @State private var showSettings = false
    @State private var selectedDayIndex: Int = 0
    @State private var showLocationAlert = false
    @State private var locationAlertText = ""
    @EnvironmentObject var settings: AppSettings

    // MARK: - INIT
    init(initial: WeatherSnapshot = MockWeather.sample) {
        _weather = State(initialValue: initial)
    }

    // MARK: - CONDITION (driven by selected day's weather code)
    private var condition: WeatherCondition {
        let code = weather.raw?.daily.weather_code[safe: selectedDayIndex] ?? 0
        switch code {
        case 0: return .clear
        case 1: return .partlyCloudy
        case 2, 3: return .clouds
        case 45, 48: return .clouds
        case 51...67, 80...82: return .rain
        case 95, 96, 99: return .thunder
        case 71...77: return .snow
        default: return .clear
        }
    }

    // MARK: - BODY
    var body: some View {
        ZStack {
            WeatherBackground(condition: condition)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    header
                    chart
                    pills
                    infoCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView { city in
                    Task {
                        await loadWeatherForCity(city)
                    }
                }
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
            }

            VStack {
                HStack {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 0)
            .padding(.leading, 24)
        }
        .preferredColorScheme(.dark)
        .alert(locationAlertText, isPresented: $showLocationAlert) {
            Button("OK", role: .cancel) { }
        }
        .task(id: settings.locationMode) {
            switch settings.locationMode {
            case .auto:
                await loadWeather()

            case .manual:
                if !settings.manualCity.isEmpty {
                    await loadWeatherForCity(settings.manualCity)
                }
            }
        }
        .onChange(of: settings.locationMode) { _, newValue in
            Task {
                switch newValue {

                case .auto:
                    settings.manualCity = ""
                    await loadWeather()

                case .manual:
                    if !settings.manualCity.isEmpty {
                        await loadWeatherForCity(settings.manualCity)
                    }
                }
            }
        }    }

    // MARK: - LOAD
    private func loadWeather() async {
        let provider = LocationProvider()
        let resolved = try? await provider.resolveCurrent()

        let lat = resolved?.latitude ?? -8.6705
        let lon = resolved?.longitude ?? 115.2126
        let name = resolved?.name ?? "Denpasar"

        if let fresh = try? await OpenMeteoService.fetch(lat: lat, lon: lon, name: name) {
            weather = fresh
            showLocationUpdate("Using current location: \(name)")
        }
    }

    private func loadWeatherForCity(_ city: String) async {
        settings.locationMode = .manual
        settings.manualCity = city

        do {
            let place = try await GeocodingService.resolve(city: city)

            if let fresh = try? await OpenMeteoService.fetch(
                lat: place.lat,
                lon: place.lon,
                name: place.name
            ) {
                weather = fresh
                showLocationUpdate("Updated to \(place.name)")
            }
        } catch {
            print("City not found")
        }
    }
    
    private func showLocationUpdate(_ text: String) {
        locationAlertText = text
        showLocationAlert = true
    }
    
    
    // MARK: - SELECTED DAY
    private var selectedDay: DayForecast {
        weather.days[selectedDayIndex]
    }

    private var headerWeekday: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDay.date) { return "Today" }
        if calendar.isDateInTomorrow(selectedDay.date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: selectedDay.date)
    }

    private var headerTemp: Int {
        selectedHourly.map(\.temp).max() ?? weather.currentTemp
    }

    // MARK: - HEADER
    private var header: some View {
        ZStack {

            // LEFT: location + weekday + temperature
            VStack(alignment: .leading, spacing: 4) {
                Text(weather.location)
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.85))

                Text(headerWeekday)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                Text(settings.formatTemp(headerTemp))
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 180)

            // CENTER: character + speech cloud
            ZStack {

                Image(systemName: "figure.stand")
                    .font(.system(size: 90))
                    .foregroundStyle(.white.opacity(0.9))

                VStack {
                    Text(weather.advisory)
                        .font(.footnote)
                        .foregroundStyle(.black.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.white.opacity(0.85))

                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.6), lineWidth: 1)
                    }
                )
                .frame(maxWidth: 180)
                .offset(x: 90, y: -40)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        }
    }

    // MARK: - CHART
    private var chart: some View {
        let data = selectedHourly
        let highlight = data.max(by: { $0.temp < $1.temp })

        return Chart {
            ForEach(data) { point in
                LineMark(
                    x: .value("Hour", point.hour),
                    y: .value("Temp", point.temp)
                )
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .foregroundStyle(.white.opacity(0.75))
                .interpolationMethod(.catmullRom)
            }

            if let h = highlight {
                PointMark(
                    x: .value("Hour", h.hour),
                    y: .value("Temp", h.temp)
                )
                .symbolSize(220)
                .foregroundStyle(.white.opacity(0.55))
                .annotation(position: .top) {
                    Text("\(h.temp)°")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
        }
        .chartXScale(domain: 0...24)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text(String(format: "%02d", hour % 24))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 160)
        .id(selectedDay.date)
    }

    // MARK: - PILLS (tappable)
    private var pills: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array(weather.days.enumerated()), id: \.element.id) { index, day in
                    VStack(spacing: 8) {
                        Image(systemName: day.iconName)
                            .font(.title3)
                            .foregroundStyle(.orange)

                        Text(day.label)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
                    .glassEffect(.regular, in: Capsule())
                    .opacity(selectedDayIndex == index ? 1 : 0.5)
                    .scaleEffect(selectedDayIndex == index ? 1.05 : 0.95)
                    .onTapGesture {
                        selectedDayIndex = index
                    }
                }
            }
        }
    }

    // MARK: - INFO CARD
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 24) {

            HStack {
                Text("Today's Sunset")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(weather.sunset, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(sunsetClock)
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(.white)
                Text(sunsetAmPm)
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sun Protection")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(weather.uvIndex)")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange)
                        Text(weather.uvAdvice)
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .frame(maxWidth: 90, alignment: .leading)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Air Quality")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Text(weather.airQuality)
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Feels like :")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Text(settings.formatTemp(feelsLikeValue))
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.55))
        )
    }

    private var feelsLikeValue: Int {
        let data = selectedHourly
        guard !data.isEmpty else { return weather.feelsLike }
        return data.map { $0.temp }.reduce(0, +) / data.count
    }

    // MARK: - HOURLY FILTER (per selected day)
    private var selectedHourly: [HourlyPoint] {
        guard let raw = weather.raw else {
            return weather.hourly
        }

        let calendar = Calendar.current
        let selectedDate = selectedDay.date

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let times = raw.hourly.time
        let temps = raw.hourly.temperature_2m
        let rain = raw.hourly.precipitation

        var result: [HourlyPoint] = []

        for i in 0..<times.count {
            guard let date = formatter.date(from: times[i]) else { continue }
            guard calendar.isDate(date, inSameDayAs: selectedDate) else { continue }

            let hour = calendar.component(.hour, from: date)

            result.append(
                HourlyPoint(
                    hour: hour,
                    temp: Int(temps[i].rounded()),
                    rain: rain.indices.contains(i) ? rain[i] : 0
                )
            )
        }

        return result.sorted { $0.hour < $1.hour }
    }

    // Clock helpers
    private var sunsetClock: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: weather.sunset)
    }

    private var sunsetAmPm: String {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f.string(from: weather.sunset)
    }
}


#Preview {
    WeatherView(initial: MockWeather.sample)
        .environmentObject(AppSettings())

}
