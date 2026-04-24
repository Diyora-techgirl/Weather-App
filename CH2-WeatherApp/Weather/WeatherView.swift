import SwiftUI
import Charts

struct WeatherView: View {

    @State private var weather: WeatherSnapshot
    @State private var selectedDayIndex: Int = 0
    @State private var isLoading = false

    // MARK: - INIT (mock only for preview/start)
    init(initial: WeatherSnapshot = MockWeather.sample) {
        _weather = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            if isLoading {
                ProgressView("Loading weather...")
                    .foregroundStyle(.white)
            } else {
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
            }
        }
        .preferredColorScheme(.dark)

        // 🔥 REAL API CALL
        .task {
            await loadWeather()
        }
    }

    // MARK: - API LOADER

    private func loadWeather() async {
        print("🌐 Starting API call...")

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await OpenMeteoService.fetch(
                lat: -8.5069,
                lon: 115.2625,
                name: "Ubud"
            )

            print("✅ API SUCCESS:", result.location)
            print("🌡 Temp:", result.currentTemp)

            await MainActor.run {
                weather = result   // 🔥 THIS replaces mock
            }

        } catch {
            print("❌ API FAILED:", error)
        }
    }

    // MARK: - SELECTED DAY

    private var selectedDay: DayForecast {
        weather.days[selectedDayIndex]
    }

    // MARK: - HEADER

    private var header: some View {
        ZStack(alignment: .topLeading) {

            HStack {
                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(weather.advisory)
                        .font(.footnote)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            Ellipse()
                                .fill(.white.opacity(0.35))
                                .blur(radius: 6)
                        )

                    Image(systemName: "figure.stand")
                        .font(.system(size: 90))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            VStack(alignment: .leading, spacing: 4) {

                Text(weather.location)
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.85))

                Text(headerWeekday)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                Text("\(headerTemp) °C")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .padding(.top, 180)
        }
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
                .foregroundStyle(.white.opacity(0.75))
                .interpolationMethod(.catmullRom)
            }

            if let h = highlight {
                PointMark(
                    x: .value("Hour", h.hour),
                    y: .value("Temp", h.temp)
                )
                .symbolSize(160)
            }
        }
        .chartXScale(domain: 0...24)
        .chartYAxis(.hidden)
        .frame(height: 160)
        .id(selectedDay.date)
    }

    // MARK: - PILLS

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
                Text("Weather")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Feels like:")
                    .foregroundStyle(.white.opacity(0.7))

                Text("\(feelsLikeValue) °C")
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

    // MARK: - HOURLY FILTER

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

    // MARK: - BACKGROUND

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.35, green: 0.65, blue: 0.90),
                Color(red: 0.95, green: 0.45, blue: 0.20),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
