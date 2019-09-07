//
//  Interfaces.swift
//  Monitor
//
//  Created by zhangbangjun on 2019/4/15.
//  Copyright © 2019 zhangbangjun. All rights reserved.
//

import Foundation

extension sockaddr: Equatable {
    public static func == (lhs: sockaddr, rhs: sockaddr) -> Bool {
        if lhs.sa_len != rhs.sa_len {
            return false
        }
        if lhs.sa_family != rhs.sa_family {
            return false
        }
        if lhs.sa_data.0 != rhs.sa_data.0 { return false }
        if lhs.sa_data.1 != rhs.sa_data.1 { return false }
        if lhs.sa_data.2 != rhs.sa_data.2 { return false }
        if lhs.sa_data.3 != rhs.sa_data.3 { return false }
        if lhs.sa_data.4 != rhs.sa_data.4 { return false }
        if lhs.sa_data.5 != rhs.sa_data.5 { return false }
        if lhs.sa_data.6 != rhs.sa_data.6 { return false }
        if lhs.sa_data.7 != rhs.sa_data.7 { return false }
        if lhs.sa_data.8 != rhs.sa_data.8 { return false }
        if lhs.sa_data.9 != rhs.sa_data.9 { return false }
        if lhs.sa_data.10 != rhs.sa_data.10 { return false }
        if lhs.sa_data.11 != rhs.sa_data.11 { return false }
        if lhs.sa_data.12 != rhs.sa_data.12 { return false }
        if lhs.sa_data.13 != rhs.sa_data.13 { return false }
        return true
    }
}

private extension ifaddrs {
    var dstaddr: UnsafeMutablePointer<sockaddr>? {
        #if os(Linux)
        return self.ifa_ifu.ifu_dstaddr
        #elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        return self.ifa_dstaddr
        #endif
    }
    
    var broadaddr: UnsafeMutablePointer<sockaddr>? {
        #if os(Linux)
        return self.ifa_ifu.ifu_broadaddr
        #elseif os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
        return self.ifa_dstaddr
        #endif
    }
}

private extension Optional where Wrapped : Equatable {
    static func == (lhs: Optional, rhs: Optional) -> Bool {
        switch (lhs, rhs) {
        case (.some(let lw), .some(let rw)) :
            return lw == rw
        default:
            return false
        }
    }
}

/// A representation of a single network interface on a system.
public final class NetworkInterface {
    
    private static let cellular    = "pdp_ip0"
    private static let wifi        = "en0"
    private static let ipv4        = "ipv4"
    private static let ipv6        = "ipv6"
    
    // This is a class because in almost all cases this will carry
    // four structs that are backed by classes, and so will incur 4
    // refcount operations each time it is copied.
    
    /// The name of the network interface.
    public let name: String
    
    /// The address associated with the given network interface.
    public let address: sockaddr
    
    /// The netmask associated with this address, if any.
    public let netmask: sockaddr?
    
    /// The broadcast address associated with this socket interface, if it has one. Some
    /// interfaces do not, especially those that have a `pointToPointDestinationAddress`.
    public let broadcastAddress: sockaddr?
    
    /// The address of the peer on a point-to-point interface, if this is one. Some
    /// interfaces do not have such an address: most of those have a `broadcastAddress`
    /// instead.
    public let pointToPointDestinationAddress: sockaddr?
    
    /// If the Interface supports Multicast
    public let multicastSupported: Bool
    
    /// The index of the interface, as provided by `if_nametoindex`.
    public let interfaceIndex: Int
    
    /// Create a brand new network interface.
    ///
    /// This constructor will fail if NIO does not understand the format of the underlying
    /// socket address family. This is quite common: for example, Linux will return AF_PACKET
    /// addressed interfaces on most platforms, which NIO does not currently understand.
    internal init?(_ caddr: ifaddrs) {
        self.name = String(cString: caddr.ifa_name)
        guard let address = caddr.ifa_addr else {
            return nil
        }
        self.address = address.pointee
        
        if let netmask = caddr.ifa_netmask {
            self.netmask = netmask.pointee
        } else {
            self.netmask = nil
        }
        
        if (caddr.ifa_flags & UInt32(IFF_BROADCAST)) != 0, let addr = caddr.broadaddr {
            self.broadcastAddress = addr.pointee
            self.pointToPointDestinationAddress = nil
        } else if (caddr.ifa_flags & UInt32(IFF_POINTOPOINT)) != 0, let addr = caddr.dstaddr {
            self.broadcastAddress = nil
            self.pointToPointDestinationAddress = addr.pointee
        } else {
            self.broadcastAddress = nil
            self.pointToPointDestinationAddress = nil
        }
        
        if (caddr.ifa_flags & UInt32(IFF_MULTICAST)) != 0 {
            self.multicastSupported = true
        } else {
            self.multicastSupported = false
        }
        
        self.interfaceIndex = Int(if_nametoindex(caddr.ifa_name))
    }
}

extension NetworkInterface: CustomDebugStringConvertible {
    public var debugDescription: String {
        let baseString = "Interface \(self.name): address \(self.address)"
        let maskString = self.netmask != nil ? " netmask \(self.netmask!)" : ""
        return baseString + maskString
    }
}

extension NetworkInterface: Equatable {
    public static func ==(lhs: NetworkInterface, rhs: NetworkInterface) -> Bool {
        return lhs.name == rhs.name &&
            lhs.address == rhs.address &&
            lhs.netmask == rhs.netmask &&
            lhs.broadcastAddress == rhs.broadcastAddress &&
            lhs.pointToPointDestinationAddress == rhs.pointToPointDestinationAddress &&
            lhs.interfaceIndex == rhs.interfaceIndex
    }
}
