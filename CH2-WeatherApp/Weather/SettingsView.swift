//
//  SettingsView.swift
//  WeatherAppRemix
//
//  Created by Alex on 23/04/26.
//




import Foundation
import SwiftUI


struct SettingsView: View {

    @EnvironmentObject var settings: AppSettings
    var onCitySelected: (String) -> Void
    
    var body: some View {
        ZStack {
            // background blur
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 20) {

                // drag indicator
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                VStack(spacing: 16) {

                    // Units row
                    HStack {
                        Text("Units")
                            .foregroundStyle(.white.opacity(0.8))

                        Spacer()

                        Picker("", selection: $settings.useCelsius) {
                            Text("°C").tag(true)
                            Text("°F").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    }

                    // LOCATION CONTROL
                    VStack(alignment: .leading, spacing: 12) {

                        HStack {
                            Text("Location")
                                .foregroundStyle(.white.opacity(0.8))

                            Spacer()

                            Picker("", selection: $settings.locationMode) {
                                ForEach(LocationMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }

                        if settings.locationMode == .manual {
                            TextField("Enter city", text: $settings.manualCity)
                                .padding(12)
                                .foregroundStyle(.white)
                                .tint(.white)
                                .background {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(.white.opacity(0.15), lineWidth: 1)
                                        )
                                }
                            Button("Apply") {
                                onCitySelected(settings.manualCity)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(.white.opacity(0.2))
                            .cornerRadius(12)
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    }
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    SettingsView { _ in }
        .environmentObject(AppSettings())
}
