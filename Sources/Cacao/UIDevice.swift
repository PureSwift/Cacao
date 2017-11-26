//
//  UIDevice.swift
//  Cacao
//
//  Created by Alsey Coleman Miller on 6/24/17.
//

#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

import Foundation

/// Use a `UIDevice` object to get information about the device such as assigned name, device model,
/// and operating-system name and version. You also use the UIDevice instance to detect changes in
/// the device’s characteristics, such as physical orientation.
public final class UIDevice {
    
    // MARK: - Getting the Shared Device Instance
    
    /// Returns an object representing the current device.
    public static let current = UIDevice()
    
    private init() { }
    
    // MARK: - Determining the Available Features
    
    /// A Boolean value indicating whether multitasking is supported on the current device.
    public var isMultitaskingSupported: Bool {
        
        return true
    }
    
    // MARK: - Identifying the Device and Operating System
    
    /// The name identifying the device.
    public var name: String {
        
        #if os(macOS)
            return Mac.name
        #else
            return Host.current().name ?? "" // Use NSHost on other platforms
        #endif
    }
    
    /// The name of the operating system running on the device represented by the receiver.
    public var systemName: String {
        
        #if os(macOS)
            return "macOS"
        #elseif os(Android)
            return "Android"
        #elseif os(Linux)
            return "Linux"
        #endif
    }
    
    /// The current version of the operating system.
    public var systemVersion: String {
        
        return ProcessInfo.processInfo.operatingSystemVersionString
    }
    
    /// The model of the device.
    public var model: String {
        
        #if os(macOS)
            return Mac.model
        #elseif os(Android)
            return "Android"
        #elseif os(Linux)
            return "Linux"
        #endif
    }
    
    /// The model of the device as a localized string.
    public var localizedModel: String {
        
        // just forward model string, no localization
        @inline(__always)
        get { return model }
    }
    
    /// The style of interface to use on the current device.
    public var userInterfaceIdiom: UIUserInterfaceIdiom {
        
        #if os(macOS)
            return .pad
        #elseif os(Android)
            return .phone
        #elseif os(Linux)
            return .pad
        #endif
    }
    
    /// An alphanumeric string that uniquely identifies a device to the app’s vendor.
    public lazy var identifierForVendor: UUID? = UUID()
    
    // MARK: - Getting the Device Orientation
    
    /// Returns the physical orientation of the device.
    public var orientation: UIDeviceOrientation {
        
        // FIXME: Implement rotation
        
        #if os(macOS)
            return .portrait
        #elseif os(Android)
            return Android.orientation
        #elseif os(Linux)
            return .portrait
        #endif
    }
    
    /// A Boolean value that indicates whether the receiver generates orientation notifications (true) or not (false).
    public private(set) var isGeneratingDeviceOrientationNotifications: Bool = false
    
    /// Begins the generation of notifications of device orientation changes.
    public func beginGeneratingDeviceOrientationNotifications() {
        
        isGeneratingDeviceOrientationNotifications = true
    }
    
    /// Ends the generation of notifications of device orientation changes.
    public func endGeneratingDeviceOrientationNotifications() {
        
        isGeneratingDeviceOrientationNotifications = false
    }
    
    // MARK: - Getting the Device Battery State
    
    /// The battery charge level for the device.
    ///
    /// Battery level ranges from 0.0 (fully discharged) to 1.0 (100% charged).
    /// Before accessing this property, ensure that battery monitoring is enabled.
    /// If battery monitoring is not enabled, battery state is `unknown`
    /// and the value of this property is –1.0.
    public var batteryLevel: Float {
        
        #if os(macOS)
            return Mac.batteryLevel
        #elseif os(Linux)
            return -1
        #endif
    }
    
    /// A Boolean value indicating whether battery monitoring is enabled (true) or not (false).
    public var isBatteryMonitoringEnabled: Bool = false
    
    /// The battery state for the device.
    public var batteryState: UIDeviceBatteryState {
        
        #if os(macOS)
            return Mac.batteryState
        #elseif os(Linux)
            return .unknown
        #endif
    }
}

// MARK: - Supporting Types

public enum UIDeviceOrientation: Int {
    
    case unknown
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
    case faceUp
    case faceDown
}

public enum UIUserInterfaceIdiom: Int {
    
    case phone
    case pad
}

public enum UIDeviceBatteryState: Int {
    
    /// The battery state for the device cannot be determined.
    case unknown
    
    /// The device is not plugged into power; the battery is discharging.
    case unplugged
    
    /// The device is plugged into power and the battery is less than 100% charged.
    case charging
    
    /// The device is plugged into power and the battery is 100% charged.
    case full
}

// MARK: - Macintosh Information

#if os(macOS)
    
    import SystemConfiguration
    import IOKit.ps
    
    private extension UIDevice {
        
        /// Macintosh Device information
        struct Mac {
            
            static func systemInformation(for name: String) -> String? {
                
                var size = 0
                
                sysctlbyname(name, nil, &size, nil, 0)
                
                guard size > 0 else { return nil }
                
                let cString = UnsafeMutablePointer<CChar>.allocate(capacity: size)
                
                defer { cString.deallocate(capacity: size) }
                
                sysctlbyname(name, cString, &size, nil, 0)
                
                return String(cString: cString)
            }
            
            /// Get the computer name on a Macintosh.
            static var name: String {
                
                return SCDynamicStoreCopyComputerName(nil, nil) as String? ?? ""
            }
            
            /// Get the model name on a Macintosh.
            static var model: String {
                
                guard let hardwareModel = systemInformation(for: "hw.model")
                    else { return "" }
                
                var family: Family?
                
                for model in Family.all {
                    
                    guard hardwareModel.hasPrefix(model.rawValue)
                        else { continue }
                    
                    family = model
                    break
                }
                
                return family?.description ?? hardwareModel
            }
            
            static var powerSources: [PowerSource] {
                
                let sourcesInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
                
                if let list = IOPSCopyPowerSourcesList(sourcesInfo).takeRetainedValue() as? [[String: Any]] {
                    
                    return list.flatMap({ PowerSource(info: $0)})
                }
                
                return []
            }
            
            static var batteryState: UIDeviceBatteryState {
                
                guard let powerSource = powerSources.first
                    else { return .unknown }
                
                switch powerSource.state {
                    
                case kIOPSACPowerValue:
                    
                    // determine charging
                    if powerSource.currentCapacity == powerSource.maximumCapacity {
                        
                        return .full
                        
                    } else {
                        
                        return .charging
                    }
                    
                case kIOPSBatteryPowerValue:
                    
                    return .unplugged
                    
                default: return .unknown
                }
            }
            
            static var batteryLevel: Float {
                
                guard let powerSource = powerSources.first
                    else { return -1 }
                
                return powerSource.chargedPercentage
            }
        }
    }
    
    extension UIDevice.Mac {
        
        enum Family: String, CustomStringConvertible {
            
            case iMac
            case iMacPro
            case MacBook
            case MacBookPro
            case MacBookAir
            case Macmini
            case MacPro
            
            static var all: [Family] = [iMacPro, iMac, MacBookPro, MacBookAir, MacBook, Macmini, MacPro]
            
            var description: String {
                
                switch self {
                case .iMac: return "iMac"
                case .iMacPro: return "iMac Pro"
                case .MacBook: return "MacBook"
                case .MacBookPro: return "MacBook Pro"
                case .MacBookAir: return "MacBook Air"
                case .Macmini: return "Mac Mini"
                case .MacPro: return "Mac Pro"
                }
            }
        }
        
        struct PowerSource {
            
            let identifier: Int
            let serialNumber: String
            let name: String
            let maximumCapacity: Int
            let currentCapacity: Int
            let charging: Bool
            let present: Bool
            let state: String
            let category: String
            
            var chargedPercentage: Float {
                
                return floor((Float(currentCapacity) / Float(maximumCapacity)))
            }
            
            init?(info: [String: Any]) {
                
                guard let id = info[kIOPSPowerSourceIDKey] as? Int,
                    let serialNumber = info[kIOPSHardwareSerialNumberKey] as? String,
                    let name = info[kIOPSNameKey] as? String,
                    let maximumCapacity = info[kIOPSMaxCapacityKey] as? Int,
                    let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int,
                    let charging = info[kIOPSIsChargingKey] as? Bool,
                    let present = info[kIOPSIsPresentKey] as? Bool,
                    let state = info[kIOPSPowerSourceStateKey] as? String,
                    let type = info[kIOPSTypeKey] as? String
                    else { return nil }
                
                self.identifier = id
                self.serialNumber = serialNumber
                self.name = name
                self.maximumCapacity = maximumCapacity
                self.currentCapacity = currentCapacity
                self.charging = charging
                self.present = present
                self.state = state
                self.category = type
            }
        }
    }
    
#endif
