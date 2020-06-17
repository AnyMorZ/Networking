//
//  Pinger.swift
//  Monitor
//
//  Created by zhangbangjun on 2019/1/31.
//  Copyright © 2019 zhangbangjun. All rights reserved.
//

import UIKit
import SystemConfiguration.CaptiveNetwork

public class Pinger: NSObject {
    
    var isLogEnabled = true
    
    private(set) var tasks: [PingTask] = []
   
    // MARK: -
    
    @discardableResult
    public func ping(hostName: String, timeInverval: TimeInterval = 1.0, repeatCount: UInt = UInt.max, completionHandler: @escaping (PingTask.Result) -> Void) -> PingTask {
        let pinger = SimplePing(hostName: hostName)
        let task = PingTask(pinger: pinger, timeInverval: timeInverval, repeatCount: repeatCount) { [weak self] task, result in
            guard let strongSelf = self else {
                return
            }
            strongSelf.tasks.removeAll(where: { $0.id == task.id })
            completionHandler(result)
        }
        task.isLogEnabled = isLogEnabled
        tasks.append(task)
        return task
    }
    
    @discardableResult
    public func ping(address: String, timeInverval: TimeInterval = 1.0, repeatCount: UInt = UInt.max, completionHandler: @escaping (PingTask.Result) -> Void) -> PingTask {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout.size(ofValue: addr))
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr(address)
        let data = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1, {
                Data(bytes: $0, count: MemoryLayout<sockaddr>.size)
            })
        }
        let pinger = SimplePing(address: data)
        let task = PingTask(pinger: pinger, timeInverval: timeInverval, repeatCount: repeatCount) { [weak self] task, result in
            guard let strongSelf = self else {
                return
            }
            strongSelf.tasks.removeAll(where: { $0.id == task.id })
            completionHandler(result)
        }
        task.isLogEnabled = isLogEnabled
        tasks.append(task)
        return task
    }
}


// MARK: -

public class PingTask {
    
    // MARK: - Result
    
    public struct Result {
        /// transmitted packets number
        let transmitted: Int
        /// received packets number
        let received: Int
        /// min round trip time, ms
        let minRTT: TimeInterval
        /// avg round trip time, ms
        let avgRTT: TimeInterval
        /// max round trip time, ms
        let maxRTT: TimeInterval
    }
    
    let id = UUID().uuidString
    
    var isLogEnabled = false
    
    private var count: UInt = 0
    
    private let pinger: SimplePing
    
    private var ping: Ping?
    
    private let timeInverval: TimeInterval
    
    private let repeatCount: UInt
    
    private var results: [Ping.Result] = []
    
    private var completionHandler: (PingTask, Result) -> Void
    
    init(pinger: SimplePing, timeInverval: TimeInterval = 1.0, repeatCount: UInt = UInt.max, completionHandler: @escaping (PingTask, Result) -> Void) {
        self.timeInverval = timeInverval
        self.repeatCount = repeatCount
        self.pinger = pinger
        self.completionHandler = completionHandler
    }
    
    public func start() {
        startPing()
    }
    
    @discardableResult
    public func stop() -> Result {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(startPing), object: nil)
        
        let transmitted = results.count
        var received = 0
        var minRTT: TimeInterval = 0
        var totalRTT: TimeInterval = 0
        var maxRTT: TimeInterval = 0
        
        results.forEach { (result) in
            guard case .success(_, _, _, let rtt) = result else {
                return
            }
            received += 1
            if minRTT != 0 {
                minRTT = min(rtt, minRTT)
            } else {
                minRTT = rtt
            }
            maxRTT = max(rtt, maxRTT)
            totalRTT += rtt
        }
        
        let avgRTT: TimeInterval = {
            if received == 0 {
                return 0
            }
            return totalRTT / TimeInterval(received)
        }()
        
        let result = Result(transmitted: transmitted, received: received, minRTT: minRTT, avgRTT: avgRTT, maxRTT: maxRTT)
        
        completionHandler(self, result)
        
        return result
    }
    
    @objc private func startPing() {
        self.ping?.timeout()
        self.ping = Ping(pinger: pinger) { [weak self] (result) in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.isLogEnabled {
                print(result)
            }
            strongSelf.results.append(result)
            if strongSelf.count >= strongSelf.repeatCount {
                strongSelf.stop()
            } else {
                if strongSelf.timeInverval <= 0 {
                    strongSelf.startPing()
                }
            }
        }
        self.ping?.start()
        Timer.scheduledTimer(withTimeInterval: timeInverval, repeats: false) { [weak self] _ in
            self?.startPing()
        }
        count += 1
    }
}


private class Ping: NSObject, SimplePingDelegate {
    
    // MARK: -
    
    enum Error: CustomDebugStringConvertible {
        case unexpectedPacket(_ packet: Data)
        case failToResolveAddress(_ hostName: String, _ error: Swift.Error)
        case failToSendPacket(_ packet: Data, _ sequenceNumber: UInt16, _ error: Swift.Error)
        case serverError(_ error: Swift.Error)
        case unknownError
        case timeout(_ sequenceNumber: UInt16)
        
        var debugDescription: String {
            switch self {
            case .unexpectedPacket(_):
                return "did receive unexpected packet"
            case .failToSendPacket(_, let sequenceNumber, let error):
                return "fail to send packet: icmp_seq=\(sequenceNumber) error=\(error)"
            case .unknownError:
                return "unkown error"
            case .serverError(let error):
                return "server error: error=\(error)"
            case .failToResolveAddress(let hostName, let error):
                return "cannot resolve \(hostName): error=\(error)"
            case .timeout(let sequenceNumber):
                return "Request timeout for icmp_seq \(sequenceNumber)"
            }
        }
    }
    
    enum Result: CustomDebugStringConvertible {
        case success(_ packetSize: Int, _ sequenceNumber: UInt16, _ address: String, _ rtt: TimeInterval)
        case failure(Error)
        
        var debugDescription: String {
            switch self {
            case .failure(let error):
                return error.debugDescription
            case .success(let packetSize, let sequenceNumber, let address, let rtt):
                return "\(packetSize) bytes from \(address): icmp_seq=\(sequenceNumber) time=\(rtt) ms"
            }
        }
    }
    
    class Statistics {
        var requestStartTime: TimeInterval? = nil
        var domainLookupEndTime: TimeInterval? = nil
        var address: String? = nil
        var packet: Data? = nil
        var sequenceNumber: UInt16? = nil
    }
    
    private enum State {
        case idle
        case start
        case resolved
        case send
        case finished
    }
    
    // MARK: -
    
    private let pinger: SimplePing
    private let completionHander: (Result) -> Void
    private var statistics: Statistics? = nil
    private var state: State = .idle
    
    init(pinger: SimplePing, completionHander: @escaping (Result) -> Void) {
        self.pinger = pinger
        self.completionHander = completionHander
        super.init()
        
        pinger.delegate = self
    }
    
    @objc func start() {
        self.statistics = Statistics()
        self.statistics?.requestStartTime = CACurrentMediaTime()
        pinger.start()
        state = .start
    }
    
    func timeout() {
        if state == .finished {
            return
        }
        pinger.stop()
        guard let statistics = self.statistics, let sequenceNumber = statistics.sequenceNumber  else {
            finishPing(with: .failure(.unknownError))
            return
        }
        finishPing(with: .failure(.timeout(sequenceNumber)))
    }
    
    // MARK: -
    
    private func finishPing(with result: Result) {
        state = .finished
        pinger.stop()
        completionHander(result)
    }
  
    func simplePing(_ pinger: SimplePing, didFailWithError error: Swift.Error) {
        /// 解析 DNS 的问题
        if pinger.hostAddress == nil {
            finishPing(with: .failure(.failToResolveAddress(pinger.hostName, error)))
        } else {
            /// 其他问题
            finishPing(with: .failure(.serverError(error)))
        }
    }
    
    func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        guard pinger.hostAddress != nil, let statistics = self.statistics else {
            finishPing(with: .failure(.unknownError))
            return
        }
        statistics.address = Network.ipAddress(from: address)
        pinger.send(with: nil)
        statistics.domainLookupEndTime = CACurrentMediaTime()
        state = .resolved
    }
    
    func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Swift.Error) {
        finishPing(with: .failure(.failToSendPacket(packet, sequenceNumber, error)))
    }
    
    func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        guard let statistics = self.statistics else {
            finishPing(with: .failure(.unknownError))
            return
        }
        statistics.packet = packet
        statistics.sequenceNumber = sequenceNumber
        state = .send
    }
 
    func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        pinger.stop()
        guard let statistics = self.statistics, let requestStartTime = statistics.requestStartTime, let packet = statistics.packet, let sequenceNumber = statistics.sequenceNumber, let addr = statistics.address else {
            finishPing(with: .failure(.unknownError))
            return
        }
        let latency = round((CACurrentMediaTime() - requestStartTime) * 1_000_000) / 1_000
        completionHander(.success(packet.count, sequenceNumber, addr, latency))
        state = .finished
    }
    
    func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        finishPing(with: .failure(.unexpectedPacket(packet)))
    }
}

