import SwiftUI
import Charts

struct WeatherView: View {

    // MARK: - STATE
    @State private var weather: WeatherSnapshot
    @State private var showSettings = false
    @State private var isLoading = false
    @State private var selectedDayIndex: Int = 0

    // MARK: - INIT
    init(initial: WeatherSnapshot = MockWeather.sample) {
        _weather = State(initialValue: initial)
    }

    // MARK: - WEATHER CONDITION
    private var condition: WeatherCondition {
        switch weather.code {
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

                if isLoading {
                    ProgressView()
                        .foregroundStyle(.white)
                        .padding(.top, 200)
                } else {
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

            // Settings button overlay
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
        .task(id: "load") {
            await loadWeather()
        }
    }

    // MARK: - LOAD WEATHER
    private func loadWeather() async {
        isLoading = true
        defer { isLoading = false }

        let provider = LocationProvider()
        let resolved = try? await provider.resolveCurrent()

        let lat = resolved?.latitude ?? -8.6705
        let lon = resolved?.longitude ?? 115.2126
        let name = resolved?.name ?? "Denpasar"

        do {
            let fresh = try await OpenMeteoService.fetch(lat: lat, lon: lon, name: name)
            await MainActor.run {
                weather = fresh
            }
        } catch {
            print("❌ Weather fetch failed:", error)
        }
    }

    // MARK: - SELECTED DAY
    private var selectedDay: DayForecast {
        weather.days[selectedDayIndex]
    }

    private var selectedHourly: [HourlyPoint] {
        weather.hourly
    }

    // MARK: - HEADER
    private var header: some View {
        ZStack {

            // LEFT SIDE
            VStack(alignment: .leading, spacing: 4) {
                Text(weather.location)
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.85))

                Text("\(weather.currentTemp) °C")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 180)

            // CENTER CHARACTER + BUBBLE
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
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.white.opacity(0.85))
                )
                .frame(maxWidth: 180)
                .offset(x: 90, y: -40)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - CHART
    private var chart: some View {
        Chart {
            ForEach(selectedHourly) { point in
                LineMark(
                    x: .value("Hour", point.hour),
                    y: .value("Temp", point.temp)
                )
                .foregroundStyle(.white.opacity(0.75))
                .interpolationMethod(.catmullRom)
            }

            if let h = selectedHourly.max(by: { $0.temp < $1.temp }) {
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
        .id(selectedDayIndex)
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

    // MARK: - INFO CARD (your version retained)
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

            VStack(alignment: .leading, spacing: 4) {
                Text("Feels like:")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Text("\(weather.feelsLike) °C")
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("UV Index")
                    .foregroundStyle(.white.opacity(0.7))

                Text("\(weather.uvIndex)")
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.55))
        )
    }
}

#Preview {
    WeatherView(initial: MockWeather.sample)
}
