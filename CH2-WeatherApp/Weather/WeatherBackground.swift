//
//  WeatherBackground.swift
//  WeatherAppRemix
//

import SwiftUI

// MARK: - WEATHER CONDITION

enum WeatherCondition {
    case clear
    case partlyCloudy
    case clouds
    case rain
    case thunder
    case snow
}

// MARK: - MAIN BACKGROUND VIEW

struct WeatherBackground: View {
    let condition: WeatherCondition

    var body: some View {
        ZStack {
            SkyLayer(condition: condition)
                .ignoresSafeArea()

            WeatherEffectLayer(condition: condition)
                .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.6), value: condition)
    }
}

// MARK: - SKY

struct SkyLayer: View {
    let condition: WeatherCondition

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var isNight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour > 18
    }

    private var colors: [Color] {
        switch condition {

        case .clear:
            return isNight
                ? [
                    Color.blue.opacity(0.55),
                    Color.indigo.opacity(0.35),
                    Color.black.opacity(0.6)
                ]
                : [
                    Color.blue.opacity(0.7),
                    Color.cyan.opacity(0.6),
                    Color.white.opacity(0.35)
                ]

        case .partlyCloudy:
            return [
                Color.gray.opacity(0.7),
                Color.blue.opacity(0.5),
                Color.white.opacity(0.15)
            ]

        case .clouds:
            return [
                Color.gray.opacity(0.8),
                Color.blue.opacity(0.6),
                Color.white.opacity(0.1)
            ]

        case .rain:
            return [
                Color.black,
                Color.gray.opacity(0.8),
                Color.blue.opacity(0.3)
            ]

        case .thunder:
            return [
                Color.black,
                Color.gray.opacity(0.9),
                Color.blue.opacity(0.25)
            ]

        case .snow:
            return [
                Color.gray.opacity(0.6),
                Color.blue.opacity(0.4),
                Color.white.opacity(0.3)
            ]
        }
    }
}

// MARK: - EFFECTS

struct WeatherEffectLayer: View {
    let condition: WeatherCondition

    var body: some View {
        switch condition {

        case .clear:
            SunView()

        case .partlyCloudy:
            ZStack {
                SunView()
                    .offset(x: 40, y: -20)

                CloudsView()
                    .opacity(0.6)
                    .offset(x: -20, y: 10)
            }

        case .clouds:
            CloudsView()

        case .rain:
            RainView()

        case .thunder:
            ZStack {
                RainView()
                LightningView()
            }

        case .snow:
            SnowView()
        }
    }
}

// MARK: - SUN

struct SunView: View {
    var body: some View {
        LottieView(name: "sun")
            .frame(width: 180, height: 180)
            .offset(x: 100, y: -340) // sky position (top-right sky)
            .allowsHitTesting(false)
    }
}

// MARK: - CLOUDS

struct CloudsView: View {
    var body: some View {
        ZStack {
            CloudItem(
                delay: 0,
                xOffset: -140,
                yOffset: -320, // was -260
                scale: 1.0
            )

            CloudItem(
                delay: 1.5,
                xOffset: 0,
                yOffset: -300, // was -230
                scale: 0.85
            )

            CloudItem(
                delay: 3,
                xOffset: 140,
                yOffset: -340, // was -280
                scale: 1.2
            )
        }
        .allowsHitTesting(false)
    }
}

struct CloudItem: View {
    let delay: Double
    let xOffset: CGFloat
    let yOffset: CGFloat
    let scale: CGFloat

    @State private var move = false

    var body: some View {
        LottieView(name: "cloudy")
            .frame(width: 220, height: 150)
            .scaleEffect(scale)
            .offset(
                x: move ? xOffset + 20 : xOffset - 20,
                y: yOffset
            )
            .opacity(0.9)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: Double.random(in: 6...10))
                        .delay(delay)
                        .repeatForever(autoreverses: true)
                ) {
                    move = true
                }
            }
    }
}



// MARK: - RAIN

struct RainView: View {

    private let drops = (0..<60).map { _ in
        (
            x: CGFloat.random(in: 0...1),
            delay: Double.random(in: 0...1)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<drops.count, id: \.self) { i in
                RainDrop(delay: drops[i].delay)
                    .position(
                        x: drops[i].x * geo.size.width,
                        y: -50
                    )
            }
        }
    }
}

struct RainDrop: View {
    let delay: Double
    @State private var fall = false

    var body: some View {
        Rectangle()
            .fill(Color.blue.opacity(0.5))
            .frame(width: 2, height: 12)
            .offset(y: fall ? 500 : -100)
            .onAppear {
                withAnimation(
                    .linear(duration: 1)
                    .delay(delay)
                    .repeatForever(autoreverses: false)
                ) {
                    fall = true
                }
            }
    }
}

// MARK: - LIGHTNING

struct LightningView: View {
    @State private var flashOpacity: Double = 0
    @State private var showBolt = false
    @State private var timer: Timer?

    private let xPositions: [CGFloat] = [-140, 0, 140]
    private let yPositions: [CGFloat] = [-320, -300, -340]

    @State private var strikeIndex = 0

    var body: some View {
        ZStack {
            // 🌫 screen flash
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()

            // ⚡ single lightning bolt
            if showBolt {
                LottieView(name: "lightning")
                    .frame(width: 220, height: 220)
                    .offset(
                        x: xPositions[strikeIndex],
                        y: yPositions[strikeIndex]
                    )
                    .opacity(0.9)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            timer = Timer.scheduledTimer(
                withTimeInterval: Double.random(in: 6...12),
                repeats: true
            ) { _ in
                triggerLightning()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func triggerLightning() {

        // 🎯 pick random sky position
        strikeIndex = Int.random(in: 0..<xPositions.count)

        // ⚡ flash
        withAnimation(.easeOut(duration: 0.05)) {
            flashOpacity = 0.2
        }

        // ⚡ show bolt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            showBolt = true
        }

        // 🌫 fade flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.6)) {
                flashOpacity = 0
            }
        }

        // ⚡ hide bolt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showBolt = false
        }
    }
}

//Snow
struct SnowView: View {

    private let flakes = (0..<60).map { _ in
        (
            x: CGFloat.random(in: 0...1),
            delay: Double.random(in: 0...1),
            speed: Double.random(in: 3...7),
            size: CGFloat.random(in: 2...5),
            drift: CGFloat.random(in: -20...20)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<flakes.count, id: \.self) { i in
                SnowFlake(
                    delay: flakes[i].delay,
                    duration: flakes[i].speed,
                    size: flakes[i].size,
                    drift: flakes[i].drift
                )
                .position(
                    x: flakes[i].x * geo.size.width,
                    y: -20
                )
            }
        }
        .ignoresSafeArea()
    }
}


struct SnowFlake: View {
    let delay: Double
    let duration: Double
    let size: CGFloat
    let drift: CGFloat

    @State private var fall = false

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.8))
            .frame(width: size, height: size)
            .blur(radius: 0.2)
            .offset(
                x: fall ? drift : 0,
                y: fall ? 800 : -50
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                        .delay(delay)
                        .repeatForever(autoreverses: false)
                ) {
                    fall = true
                }
            }
    }
}

// Partially cloudy

