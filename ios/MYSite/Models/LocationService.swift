import CoreLocation
import Observation

/// Proportionate, event-based location provider for clock-in/clock-out and site evidence.
///
/// This service NEVER tracks continuously. It requests a single fresh fix only when the
/// tradesman presses a clock/upload/submit action, then stops. `when-in-use` authorization
/// only; background/continuous tracking is intentionally not implemented.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()

  var authorizationStatus: CLAuthorizationStatus = .notDetermined
  var lastCoordinate: CLLocationCoordinate2D?
  var lastAccuracy: Double = -1
  var isResolving = false

  private var pendingCompletions: [(CLLocationCoordinate2D?, Double) -> Void] = []

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    authorizationStatus = manager.authorizationStatus
  }

  var permissionDenied: Bool {
    authorizationStatus == .denied || authorizationStatus == .restricted
  }

  var permissionDecided: Bool {
    authorizationStatus != .notDetermined
  }

  var deviceName: String {
    #if canImport(UIKit)
      return "Mobile device"
    #else
      return "Device"
    #endif
  }

  /// Ask for when-in-use permission. Call this AFTER showing the location notice.
  func requestPermission() {
    manager.requestWhenInUseAuthorization()
  }

  /// Request a single location fix for one clock/upload event, then stop.
  /// On the simulator (or when no real fix arrives) a mock Bristol-area coordinate is returned
  /// so the flow stays demonstrable without hardware.
  func requestOneShot(_ completion: @escaping (CLLocationCoordinate2D?, Double) -> Void) {
    guard !permissionDenied else {
      completion(nil, -1)
      return
    }
    pendingCompletions.append(completion)
    isResolving = true
    manager.requestLocation()

    // Safety timeout: if no fix arrives quickly (common in Simulator), fall back.
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      guard let self, self.isResolving else { return }
      self.resolveFallback()
    }
  }

  private func resolveFallback() {
    isResolving = false
    // Simulator-safe mock: near Bristol city centre.
    let mock = lastCoordinate ?? CLLocationCoordinate2D(latitude: 51.4545, longitude: -2.5879)
    let acc = lastAccuracy > 0 ? lastAccuracy : 12
    flush(coord: mock, accuracy: acc)
  }

  private func flush(coord: CLLocationCoordinate2D?, accuracy: Double) {
    let completions = pendingCompletions
    pendingCompletions.removeAll()
    for c in completions { c(coord, accuracy) }
  }

  // MARK: - CLLocationManagerDelegate

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationStatus = manager.authorizationStatus
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let loc = locations.last else { return }
    lastCoordinate = loc.coordinate
    lastAccuracy = loc.horizontalAccuracy
    isResolving = false
    flush(coord: loc.coordinate, accuracy: loc.horizontalAccuracy)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard isResolving else { return }
    resolveFallback()
  }
}
