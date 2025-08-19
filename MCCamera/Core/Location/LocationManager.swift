import CoreLocation
import ImageIO

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private(set) var currentLocation: CLLocation?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getLocationMetadata() -> [String: Any]? {
        guard let location = currentLocation else { return nil }
        
        let coordinate = location.coordinate
        let altitude = location.altitude
        let timestamp = location.timestamp
        
        var gpsDict: [String: Any] = [:]
        
        // 纬度
        gpsDict[kCGImagePropertyGPSLatitude as String] = abs(coordinate.latitude)
        gpsDict[kCGImagePropertyGPSLatitudeRef as String] = coordinate.latitude >= 0 ? "N" : "S"
        
        // 经度
        gpsDict[kCGImagePropertyGPSLongitude as String] = abs(coordinate.longitude)
        gpsDict[kCGImagePropertyGPSLongitudeRef as String] = coordinate.longitude >= 0 ? "E" : "W"
        
        // 海拔
        if altitude > 0 {
            gpsDict[kCGImagePropertyGPSAltitude as String] = abs(altitude)
            gpsDict[kCGImagePropertyGPSAltitudeRef as String] = altitude >= 0 ? 0 : 1
        }
        
        // GPS时间戳
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SS"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        gpsDict[kCGImagePropertyGPSTimeStamp as String] = dateFormatter.string(from: timestamp)
        
        let dateFormatterDate = DateFormatter()
        dateFormatterDate.dateFormat = "yyyy:MM:dd"
        dateFormatterDate.timeZone = TimeZone(identifier: "UTC")
        gpsDict[kCGImagePropertyGPSDateStamp as String] = dateFormatterDate.string(from: timestamp)
        
        // 定位精度
        if location.horizontalAccuracy > 0 {
            gpsDict[kCGImagePropertyGPSHPositioningError as String] = location.horizontalAccuracy
        }
        
        return gpsDict
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置获取失败: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("位置权限被拒绝")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}