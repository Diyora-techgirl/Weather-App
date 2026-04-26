//
//  SettingsView.swift
//  WeatherAppRemix
//
//  Created by Alex on 23/04/26.
//


// Nothing is connected. UI only for now


import SwiftUI

enum LocationMode: String, CaseIterable {
    case auto = "Auto"
    case manual = "Manual"
}

struct SettingsView: View {

    @AppStorage("locationMode") private var locationMode: LocationMode = .auto
    @AppStorage("manualLocation") private var manualLocation: String = "Paris"
    @AppStorage("useCelsius") private var useCelsius: Bool = true

    @State private var manualLocationDraft: String = ""

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

                        Picker("", selection: $useCelsius) {
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

                            Picker("", selection: $locationMode) {
                                ForEach(LocationMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }

                        if locationMode == .manual {
                            TextField("Enter city", text: $manualLocationDraft)
                                .submitLabel(.done)
                                .onSubmit { manualLocation = manualLocationDraft }
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
        .onAppear { manualLocationDraft = manualLocation }
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
