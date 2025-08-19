import Foundation

struct WatermarkSettings: Codable {
    var isEnabled: Bool = false
    var authorName: String = ""
    var showDeviceModel: Bool = true
    var showFocalLength: Bool = true
    var showShutterSpeed: Bool = true
    var showISO: Bool = true
    var showDate: Bool = true
    
    static let shared = WatermarkSettings()
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "WatermarkSettings")
        }
    }
    
    static func load() -> WatermarkSettings {
        guard let data = UserDefaults.standard.data(forKey: "WatermarkSettings"),
              let settings = try? JSONDecoder().decode(WatermarkSettings.self, from: data) else {
            return WatermarkSettings()
        }
        return settings
    }
}