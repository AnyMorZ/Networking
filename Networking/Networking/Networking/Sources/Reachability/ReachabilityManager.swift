//
//  ReachabilityManager.swift
//  Network
//
//  Created by zhangbangjun on 2019/1/17.
//  Copyright © 2019 zhangbangjun. All rights reserved.
//


#if !os(watchOS)

import Foundation
import SystemConfiguration.CaptiveNetwork
import CoreTelephony.CTCarrier
import CoreTelephony.CTTelephonyNetworkInfo

extension Notification.Name {
    /// Post when reachability changed
    static let reachabilityChanged =
        Notification.Name(rawValue: "networkReachabilityChanged")
}

/// The `ReachabilityManager` class listens for reachability changes of hosts and addresses for both WWAN and WiFi network interfaces.
open class ReachabilityManager {
    
    /// A closure executed when the network reachability status changes. The closure takes a single argument: the
    /// network reachability status.
    public typealias Listener = (SCNetworkReachabilityFlags) -> Void
    
    public class Token {
        
        public let id = UUID().uuidString
        
        private let callback: (String) -> Void
        deinit {
            callback(id)
        }
        fileprivate init(_ callback: @escaping (String) -> Void) {
            self.callback = callback
        }
    }
        
    /// The dispatch queue to execute the `listener` closure on.
    public var queue: DispatchQueue = DispatchQueue.main
    
    public var flags: SCNetworkReachabilityFlags? {
        var flags = SCNetworkReachabilityFlags()
        if SCNetworkReachabilityGetFlags(reachability, &flags) {
            return flags
        }
        return nil
    }
    
    private let reachability: SCNetworkReachability
    
    private var previousFlags: SCNetworkReachabilityFlags
    
    private var listeners: [String: Listener] = [:]
    
    // MARK: - Lefecycle
    
    deinit {
        stopListening()
    }
    
    init(reachability: SCNetworkReachability) {
        self.reachability = reachability
        self.previousFlags = SCNetworkReachabilityFlags()
    }
    
    /// Creates a `ReachabilityManager` instance that monitors the address 0.0.0.0.
    ///
    /// Reachability treats the 0.0.0.0 address as a special token that causes it to monitor the general routing
    /// status of the device, both IPv4 and IPv6.
    ///
    /// - returns: The new `ReachabilityManager` instance.
    convenience init() {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        let reachability = withUnsafePointer(to: &address, { pointer in
            return pointer.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
                return SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        })!
        self.init(reachability: reachability)
    }
    
    /// Creates a `ReachabilityManager` instance with the specified host.
    ///
    /// - parameter host: The host used to evaluate network reachability.
    ///
    /// - returns: The new `ReachabilityManager` instance.
    public convenience init?(host: String) {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, host) else {
            return nil
        }
        self.init(reachability: reachability)
    }
    
    // MARK: - Listening
    
    /// Starts listening for changes in network reachability status.
    ///
    /// - returns: `true` if listening was started successfully, `false` otherwise.
    @discardableResult
    open func startListening() -> Bool {
        var context =
            SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        var success =
            SCNetworkReachabilitySetCallback(reachability, { (_, flags, info) in
                let reachability = Unmanaged<ReachabilityManager>.fromOpaque(info!).takeUnretainedValue()
                reachability.notify(flags)
            }, &context)
        
        success = success &&
            SCNetworkReachabilitySetDispatchQueue(reachability, queue)
        
        queue.async {
            self.previousFlags = SCNetworkReachabilityFlags()
            self.notify(self.flags ?? SCNetworkReachabilityFlags())
        }
        
        return success
    }
    
    /// Stops listening for changes in network reachability status.
    open func stopListening() {
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
    }
    
    
    /// Register a listener for changes in network reachability status, return a simple token object.
    ///
    /// - note: You must retain the token object, otherwise listener will be release.
    ///
    /// - Parameter listener: The listener closure.
    /// - Parameter flags: Flags that indicate the reachability of a network node name or address.
    /// - Returns: A token.
    open func register(_ listener: @escaping (_ flags: SCNetworkReachabilityFlags) -> Void) -> Token {
        let token = Token { id in
            self.listeners[id] = nil
        }
        listeners[token.id] = listener
        return token
    }
    
    private func notify(_ flags: SCNetworkReachabilityFlags) {
        guard previousFlags != flags else {
            return
        }
        previousFlags = flags
        listeners.forEach { (pair) in
            pair.value(flags)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .reachabilityChanged, object: flags)
        }
    }
    
    // MARK: - Parse

    /// Convert a SCNetworkReachability flags to NetworkType(2g 3g 4g)
    ///
    /// - Parameter flags: SCNetworkReachabilityFlags
    /// - Returns: NetworkType
    public static func parseNetworkType(_ flags: SCNetworkReachabilityFlags) -> NetworkType {
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
    
    /// Detect VPN connectivity
    ///
    /// - Parameter flags: SCNetworkReachabilityFlags
    /// - Returns: NetworkType
    public static func parseVPN(_ flags: SCNetworkReachabilityFlags) -> Bool {
        if flags.contains(.reachable) {
            return false
        }
        return flags.contains(.transientConnection)
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
}

#endif
