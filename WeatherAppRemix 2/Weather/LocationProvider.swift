import CoreLocation
import Foundation

// Thin async wrapper around CLLocationManager.
// One-shot: ensures authorization, fetches a single fix, reverse-geocodes a city name.
// Main-actor isolated because CLLocationManager expects main-thread use.

final class LocationProvider: NSObject, CLLocationManagerDelegate {
    struct Resolved {
        let latitude: Double
        let longitude: Double
        let name: String
    }

    enum Failure: Error {
        case denied
        case unavailable
    }

    private let manager = CLLocationManager()
    private var locationCont: CheckedContinuation<CLLocation, Error>?
    private var authCont: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func resolveCurrent() async throws -> Resolved {
        let status = await ensureAuthorized()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw Failure.denied
        }
        let location = try await requestLocation()
        let name = (try? await reverseGeocode(location)) ?? "Nearby"
        return Resolved(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            name: name
        )
    }

    private func ensureAuthorized() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        if current != .notDetermined { return current }
        return await withCheckedContinuation { cont in
            self.authCont = cont
            manager.requestWhenInUseAuthorization()
        }
    }

    private func requestLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            self.locationCont = cont
            manager.requestLocation()
        }
    }

    private func reverseGeocode(_ location: CLLocation) async throws -> String {
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        let p = placemarks.first
        return p?.locality ?? p?.subAdministrativeArea ?? p?.name ?? "Nearby"
    }

    // MARK: CLLocationManagerDelegate

    // Skip the initial .notDetermined callback — only the post-prompt status matters.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined, let cont = authCont else { return }
        authCont = nil
        cont.resume(returning: status)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, let cont = locationCont else { return }
        locationCont = nil
        cont.resume(returning: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let cont = locationCont else { return }
        locationCont = nil
        cont.resume(throwing: error)
    }
}
