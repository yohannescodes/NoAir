import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var continuation: CheckedContinuation<LocationSnapshot?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation() async -> LocationSnapshot? {
        guard CLLocationManager.locationServicesEnabled() else {
            return nil
        }

        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return nil
        case .restricted, .denied:
            return nil
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation else { return }
        self.continuation = nil

        guard let location = locations.last else {
            continuation.resume(returning: nil)
            return
        }

        Task {
            let locality = await reverseGeocode(location: location)
            let snapshot = LocationSnapshot(
                coordinate: location.coordinate,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil,
                locality: locality
            )
            continuation.resume(returning: snapshot)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }

    private func reverseGeocode(location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return placemarks.first?.locality
        } catch {
            return nil
        }
    }
}
