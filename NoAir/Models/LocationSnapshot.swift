import CoreLocation
import Foundation

struct LocationSnapshot {
    let coordinate: CLLocationCoordinate2D
    let altitudeMeters: Double?
    let locality: String?
}
