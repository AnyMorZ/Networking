//
//  NetworkTraffic.swift
//  Monitor
//
//  Created by zhangbangjun on 2019/2/1.
//  Copyright © 2019 zhangbangjun. All rights reserved.
//

import Darwin

extension String {
    fileprivate var trimmed: String {
        var buf = [UInt8]()
        var trimming = true
        for c in self.utf8 {
            if trimming && c < 33 { continue }
            trimming = false
            buf.append(c)
        }
        while let last = buf.last, last < 33 {
            buf.removeLast()
        }
        buf.append(0)
        return String(cString: buf)
    }
}

public struct NetworkTraffic {
    
    /// return total traffic summary from all interfaces,
    /// i for receiving and o for transmitting, both in bytes
    public var summary: [String:[String: UInt32]] {
        get {
            var io : [String:[String: UInt32]] = [:]
            let ifaces = interfaces
            var mib = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2]
            let NULL = UnsafeMutableRawPointer(bitPattern: 0)
            
            let _ = mib.withUnsafeMutableBufferPointer { ptr -> Bool in
                var len = 0
                guard 0 == sysctl(ptr.baseAddress, 6, NULL, &len, NULL, 0) else {
                    return false
                }
                let buf = UnsafeMutablePointer<Int8>.allocate(capacity: len)
                guard sysctl(ptr.baseAddress, 6, buf, &len, NULL, 0) == KERN_SUCCESS else {
                    return true
                }
                var cursor = 0
                var index = 0
                repeat {
                    cursor = buf.advanced(by: cursor).withMemoryRebound(to: if_msghdr.self, capacity: MemoryLayout<if_msghdr>.size) { pIfm -> Int in
                        let ifm = pIfm.pointee
                        cursor += Int(ifm.ifm_msglen)
                        if integer_t(ifm.ifm_type) == 0x12 { /// RTM_IFINFO2
                            pIfm.withMemoryRebound(to: if_msghdr2.self, capacity: MemoryLayout<if_msghdr2>.size) {
                                pIfm2 in
                                let pd = pIfm.pointee
                                if index < ifaces.count {
                                    io[ifaces[index]] = ["i": pd.ifm_data.ifi_ibytes, "o": pd.ifm_data.ifi_obytes]
                                }//end if
                                index += 1
                            }//end ifm2
                        }//end if
                        return cursor
                    }//end bound
                } while (cursor < len)
                return true
            }
            
            return io
        }
    }
}

private var interfaces: [String]   {
    get {
        var ifaces = [String]()
        var mib = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST, 0]
        let NULL = UnsafeMutableRawPointer(bitPattern: 0)
        _ = mib.withUnsafeMutableBufferPointer { ptr -> Bool in
            
            guard let pmib = ptr.baseAddress else { return false }
            
            var len = 0
            guard 0 == sysctl(pmib, 6, NULL, &len, NULL, 0), len > 0
                else { return false }
            
            let buf = UnsafeMutablePointer<Int8>.allocate(capacity: len)
            if 0 == sysctl(pmib, 6, buf, &len, NULL, 0) {
                var cursor = 0
                repeat {
                    cursor = buf.advanced(by: cursor).withMemoryRebound(to: if_msghdr.self, capacity: MemoryLayout<if_msghdr>.size) { pIfm -> Int in
                        let ifm = pIfm.pointee
                        if integer_t(ifm.ifm_type) == 0xe { /// RTM_IFINFO
                            let interface = pIfm.advanced(by: 1).withMemoryRebound(to: Int8.self, capacity: 20) { sdl -> String in
                                let size = Int(sdl.advanced(by: 5).pointee)
                                let buf = sdl.advanced(by: 8)
                                buf.advanced(by: size).pointee = 0
                                let name = String(cString: buf)
                                return name
                            }//end if
                            if !interface.trimmed.isEmpty {
                                ifaces.append(interface)
                            }//end if
                        }//end if
                        cursor += Int(ifm.ifm_msglen)
                        return cursor
                    }//end bound
                } while (cursor < len)
            }//end if
            return true
        }//end pointer
        return ifaces
    }//end get
}
