//
//  HostResolver.swift
//  Monitor
//
//  Created by zhangbangjun on 2019/2/6.
//  Copyright © 2019 zhangbangjun. All rights reserved.
//

import Foundation

// MARK: - DNSResolutionResult

public enum DNSResolutionResult {
    public enum Error {
        case streamError(CFStreamError)
        case unknownError
        case timeout
    }
    case success(String)
    case failure(Error)
}

// MARK: - DNSResolution

public class DNSResolution {
    
    enum ResolvingType {
        case addresses(_ hostName: String)
        case names(_ ipAddr: String)
    }
    
    let type: ResolvingType
    let completionHandler: (DNSResolutionResult) -> Void
    let timeout: TimeInterval
    fileprivate var timer: Timer!
    private var fired: Bool = false
    private var host: CFHost!
    
    init(type: ResolvingType, timeout: TimeInterval, completionHandler: @escaping (DNSResolutionResult) -> Void) {
        self.type = type
        self.timeout = timeout
        self.completionHandler = completionHandler
    }
    
    public func start() {
        if fired { return }

        let pointer = Unmanaged.passRetained(self).toOpaque()
        var context = CFHostClientContext(version: 0, info: pointer, retain: nil, release: nil, copyDescription: unsafeBitCast(0, to: CFAllocatorCopyDescriptionCallBack.self))
        
        var infoType: CFHostInfoType
        switch type {
        case .addresses(let hostName):
            host = CFHostCreateWithName(kCFAllocatorDefault, hostName as CFString).takeUnretainedValue()
            infoType = .addresses
        case .names(let ipAddr):
            var sin = sockaddr_in(
                sin_len: UInt8(MemoryLayout<sockaddr_in>.stride),
                sin_family: sa_family_t(AF_INET),
                sin_port: in_port_t(0),
                sin_addr: in_addr(s_addr: inet_addr(ipAddr)),
                sin_zero: (0,0,0,0,0,0,0,0)
            )
            let data = NSData(bytes: &sin, length: MemoryLayout<sockaddr_in>.size) as CFData
            host = CFHostCreateWithAddress(kCFAllocatorDefault, data).takeUnretainedValue()
            infoType = .names
        }
        
        CFHostSetClient(host, _CFHostClientCallBack, &context)
        CFHostScheduleWithRunLoop(host, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        CFHostStartInfoResolution(host, infoType, nil)

        timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(onTimeout), userInfo: nil, repeats: false)
        fired = true
    }
    
    public func cancel() {
        guard fired else { return }
        CFHostCancelInfoResolution(host, .addresses)
        CFHostUnscheduleFromRunLoop(host, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        CFHostSetClient(host, nil, nil)
    }
    
    @objc private func onTimeout() {
        cancel()
        completionHandler(.failure(.timeout))
    }
}

// MARK: - DNSResolver
/// https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/ResolvingDNSHostnames.html
public struct DNSResolver {

    /// Resolve a DNS hostname.
    ///
    /// - Parameter hostName: The host to be looked up
    /// - Parameter timeout: The connection timeout
    /// - Parameter completionHandler: The callback
    /// - Parameter result: DNSResolutionResult
    /// - Returns: DNSResolution
    public func resolve(host hostName: String, timeout: TimeInterval = 3.0, completionHandler: @escaping (_ result: DNSResolutionResult) -> Void) -> DNSResolution {
        return DNSResolution(type: .addresses(hostName), timeout: timeout, completionHandler: completionHandler)
    }
    
    /// Translating an IP address into a hostname
    ///
    /// - Parameter address: The ip address.
    /// - Parameter timeout: The connection timeout
    /// - Parameter completionHandler: The callback
    /// - Parameter result: DNSResolutionResult
    /// - Returns: DNSResolution
    public func resolve(address: String, timeout: TimeInterval = 3.0, completionHandler: @escaping (_ result: DNSResolutionResult) -> Void) -> DNSResolution {
        return DNSResolution(type: .names(address), timeout: timeout, completionHandler: completionHandler)
    }
}


// MARK: -

private func _CFHostClientCallBack(_ host: CFHost, _ type: CFHostInfoType, _ error: UnsafePointer<CFStreamError>?, _ info: UnsafeMutableRawPointer?) {
    guard let info = info else {
        return
    }
    switch type {
    case .addresses:
        let pointer = Unmanaged<DNSResolution>.fromOpaque(info);
        defer { pointer.release() }
        let resolution = pointer.takeUnretainedValue()
        resolution.timer.invalidate()
        if let serr = error?.pointee, serr.error != 0 {
            resolution.completionHandler(.failure(.streamError(serr)))
            return
        }
        var resolved = DarwinBoolean(false)
        guard let addresses = CFHostGetAddressing(host, &resolved)?.takeUnretainedValue() else {
            resolution.completionHandler(.failure(.unknownError))
            return
        }
        let array = addresses as NSArray
        guard resolved.boolValue && array.count > 0 else {
            resolution.completionHandler(.failure(.unknownError))
            return
        }
        // Find the first appropriate address.
        for address in array {
            guard let data = address as? Data, let ipaddr = Network.ipAddress(from: data), !ipaddr.isEmpty else {
                continue
            }
            resolution.completionHandler(.success(ipaddr))
            return
        }
        resolution.completionHandler(.failure(.unknownError))
    default: break
    }
}

