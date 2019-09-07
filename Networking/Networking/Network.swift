//
//  Network.swift
//  Network
//
//  Created by zhangbangjun on 2019/1/17.
//  Copyright © 2019 zhangbangjun. All rights reserved.
//


#if !os(watchOS)

import UIKit
import SystemConfiguration.CaptiveNetwork
import CoreTelephony.CTCarrier
import CoreTelephony.CTTelephonyNetworkInfo

// MARK: - Network

public enum NetworkType {
    case unknown
    case noNetwork
    case wifi
    case wwan(String)
}

public var networkType: NetworkType {
    guard let flags = Network.reachability?.flags else {
        return .unknown
    }
    return Network.parse(flags)
}

// MARK: -

public struct Network {
    
    public static let reachability = ReachabilityManager()
    
    public static let pinger = Pinger()
    
    public static let resolver = DNSResolver()
    
    public static let traffic = NetworkTraffic()
    
    public static var type: NetworkType {
        guard let flags = reachability?.flags else {
            return .unknown
        }
        return parse(flags)
    }
    
    /// Convert a SCNetworkReachability flags to NetworkType(2g 3g 4g)
    ///
    /// - Parameter flags: SCNetworkReachabilityFlags
    /// - Returns: NetworkType
    public static func parse(_ flags: SCNetworkReachabilityFlags) -> NetworkType {
        if flags.contains(.isWWAN) {
            guard let accessTechnology = Carrier.currentRadioAccessTechnology else {
                return .unknown
            }
            return parse(accessTechnology: accessTechnology)
        }
        
        if flags.contains(.reachable) {
            return .wifi
        }
        
        return .noNetwork
    }
    
    /// Convert radio access technology to NetworkType(2g 3g 4g)
    ///
    /// - Parameter accessTechnology: cuurent radio access technology
    /// - Returns: NetworkType
    private static func parse(accessTechnology: String) -> NetworkType {
        /// 4g
        if  CTRadioAccessTechnologyLTE == accessTechnology {
            return .wwan("4G")
        }
        
        if  CTRadioAccessTechnologyWCDMA == accessTechnology ||
            CTRadioAccessTechnologyHSDPA == accessTechnology ||
            CTRadioAccessTechnologyCDMA1x == accessTechnology ||
            CTRadioAccessTechnologyCDMAEVDORev0 == accessTechnology ||
            CTRadioAccessTechnologyCDMAEVDORevA == accessTechnology ||
            CTRadioAccessTechnologyCDMAEVDORevB == accessTechnology ||
            CTRadioAccessTechnologyCDMAEVDORevA == accessTechnology {
            return .wwan("3G")
        }
        
        if  CTRadioAccessTechnologyGPRS == accessTechnology ||
            CTRadioAccessTechnologyEdge == accessTechnology {
            return .wwan("2G")
        }
        
        return .wwan("unknown")
    }
    
    /// Convert a sockaddr structure data into an IP address
    ///
    /// - Parameter data: The contents of the data is a (struct sockaddr)
    /// - Returns: IP address
    public static func ipAddress(from data: Data) -> String? {
        var addr = CFDataGetBytePtr(data as CFData).withMemoryRebound(to: sockaddr.self, capacity: 1) {
            return $0.pointee
        }
        return ipAddress(from: &addr)
    }
    
    /// Convert a sockaddr structure into an IP address
    ///
    /// - Parameter addr: The sockaddr structure
    /// - Returns: IP address
    public static func ipAddress(from addr: inout sockaddr) -> String? {
        switch addr.sa_family {
        case sa_family_t(AF_INET):
            let ipv4 = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    $0.pointee
                }
            }
            return String(cString: inet_ntoa(ipv4.sin_addr), encoding: .ascii)
        case sa_family_t(AF_INET6):
            var ipv6 = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    $0.pointee
                }
            }
            var cString = [CChar](repeating: 0, count:Int(INET6_ADDRSTRLEN))
            inet_ntop(AF_INET6, &ipv6.sin6_addr, &cString, socklen_t(INET6_ADDRSTRLEN))
            return String(cString: cString, encoding: .ascii)
        default:
            return nil
        }
    }
}


// MARK: - Carrier
extension Network {
    
    public static var carrierName: String? {
        return Carrier.name
    }
}

public struct Carrier {
    
    static var key = "0000000100000001"
    
    /// Carrier Name
    public static var name: String? {
        guard let carrier = Carrier.current else {
            return nil
        }
        return carrier.carrierName
    }
    
    /// Carrier Country iso Code
    public static var isoCountryCode: String? {
        guard let carrier = Carrier.current else {
            return nil
        }
        return carrier.isoCountryCode
    }
    
    /// Current radio access technology
    public static var currentRadioAccessTechnology: String? {
        let networkInfo = CTTelephonyNetworkInfo()
        if #available(iOS 12.0, *) {
            let technology = networkInfo.serviceCurrentRadioAccessTechnology
            return technology?[key]
        } else {
            return networkInfo.currentRadioAccessTechnology
        }
    }
    
    /// Is VOIP allowed
    public static var allowsVOIP: Bool {
        return Carrier.current?.allowsVOIP ?? false
    }
    
    /// Carrier
    private static var current: CTCarrier? {
        let networkInfo = CTTelephonyNetworkInfo()
        if #available(iOS 12.0, *) {
            let technology = networkInfo.serviceSubscriberCellularProviders
            return technology?[key]
        } else {
            return networkInfo.subscriberCellularProvider
        }
    }
}

// MARK: - WIFI

public struct WIFI {
    
    public static var ssid: String? {
        guard let interfaces = CNCopySupportedInterfaces() as? [CFString] else {
            return nil
        }
        for interface in interfaces {
            guard let info = CNCopyCurrentNetworkInfo(interface) as? [String:Any] else { continue }
            if let ssid = info[kCNNetworkInfoKeySSID as String] as? String {
                return ssid
            }
        }
        return nil
    }
}

// MARK: - Interface

extension Network {
    
    public static var interfaces: [NetworkInterface] {
        get {
            var interfaces: [NetworkInterface] = []
            var ifaddrs: UnsafeMutablePointer<ifaddrs>? = nil
            getifaddrs(&ifaddrs); defer { freeifaddrs(ifaddrs) }
            while let addr = ifaddrs {
                if let interface = NetworkInterface(addr.pointee) {
                    interfaces.append(interface)
                }
                ifaddrs = addr.pointee.ifa_next
            }
            return interfaces
        }
    }
}

#endif
