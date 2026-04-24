import Foundation
import Darwin

enum SecureMemory {
    static func zero(_ buffer: inout [UInt8]) {
        buffer.withUnsafeMutableBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            memset_s(base, ptr.count, 0, ptr.count)
        }
    }

    static func zero(_ data: inout Data) {
        data.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            memset_s(base, ptr.count, 0, ptr.count)
        }
    }

    static func disableCoreDumps() {
        var rl = rlimit(rlim_cur: 0, rlim_max: 0)
        setrlimit(RLIMIT_CORE, &rl)
    }

    static func lockMemory(_ pointer: UnsafeMutableRawPointer, size: Int) {
        mlock(pointer, size)
    }

    static func unlockMemory(_ pointer: UnsafeMutableRawPointer, size: Int) {
        munlock(pointer, size)
    }
}

final class SecureBuffer {
    private let pointer: UnsafeMutableRawBufferPointer
    let count: Int

    init(count: Int) {
        self.count = count
        self.pointer = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: MemoryLayout<UInt8>.alignment)
        mlock(pointer.baseAddress!, count)
    }

    init(data: Data) {
        self.count = data.count
        self.pointer = UnsafeMutableRawBufferPointer.allocate(byteCount: data.count, alignment: MemoryLayout<UInt8>.alignment)
        mlock(pointer.baseAddress!, count)
        _ = data.copyBytes(to: pointer.bindMemory(to: UInt8.self))
    }

    var bytes: UnsafeMutableRawBufferPointer { pointer }

    var data: Data {
        Data(bytes: pointer.baseAddress!, count: count)
    }

    deinit {
        memset_s(pointer.baseAddress!, count, 0, count)
        munlock(pointer.baseAddress!, count)
        pointer.deallocate()
    }
}
