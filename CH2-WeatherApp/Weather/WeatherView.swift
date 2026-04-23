import SwiftUI
import Charts

struct WeatherView: View {
    // Initial value drives the first paint; replaced by real data from .task.
    @State private var weather: WeatherSnapshot

    init(initial: WeatherSnapshot = MockWeather.sample) {
        _weather = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

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
        // Light-content status bar over the bright sky gradient
        .preferredColorScheme(.dark)
        .task(id: "load") { await loadWeather() }
    }

    // Resolve the device location (falls back to Denpasar on denial/error),
    // then fetch weather for those coordinates.
    private func loadWeather() async {
        let provider = LocationProvider()
        let resolved = try? await provider.resolveCurrent()

        let lat = resolved?.latitude ?? -8.6705
        let lon = resolved?.longitude ?? 115.2126
        let name = resolved?.name ?? "Denpasar"

        if let fresh = try? await OpenMeteoService.fetch(lat: lat, lon: lon, name: name) {
            weather = fresh
        }
    }

    // Sky → sunset → night, matches the mockup mood
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

    private var header: some View {
        ZStack(alignment: .topLeading) {
            // Character + speech bubble sit in the upper-right of the header
            HStack(alignment: .top) {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text(weather.advisory)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            Ellipse()
                                .fill(.white.opacity(0.35))
                                .blur(radius: 6)
                        )
                    // Placeholder until a real illustration asset is added
                    Image(systemName: "figure.stand")
                        .font(.system(size: 90))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(weather.location)
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.85))
                Text("\(weather.currentTemp) °C")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .padding(.top, 180) // leave room for the character above
        }
    }

    private var chart: some View {
        Chart {
            ForEach(weather.hourly) { point in
                LineMark(
                    x: .value("Hour", point.hour),
                    y: .value("Temp", point.temp)
                )
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .foregroundStyle(.white.opacity(0.75))
                .interpolationMethod(.catmullRom)
            }
            if let h = weather.highlight {
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
    }

    // Seven pills spanning full width, using iOS 26 Liquid Glass.
    private var pills: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(weather.days) { day in
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
                }
            }
        }
    }

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
                Text("\(weather.feelsLike) °C")
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

    // "6:47" — locale-aware clock without AM/PM
    private var sunsetClock: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: weather.sunset)
    }

    // "PM" — the AM/PM portion, rendered next to the clock at a smaller size
    private var sunsetAmPm: String {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f.string(from: weather.sunset)
    }
}

#Preview {
    WeatherView(initial: MockWeather.sample)
}
