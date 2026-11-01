import Foundation
import VoiceCore

/// One request to Farol over its socket, and its answer. Blocks until answered, so it's never called on the main thread.
public enum FarolSocket {
    public enum Failure: Error, Equatable {
        case notRunning
        /// It closed without answering, which is what a Farol from before these commands does.
        case tooOld
    }

    private static let timeout = timeval(tv_sec: 5, tv_usec: 0)

    public static func isRunning(at path: String) -> Bool {
        let descriptor = connected(to: path)
        if descriptor >= 0 { close(descriptor) }
        return descriptor >= 0
    }

    public static func send(_ action: FarolAction, to path: String) throws -> FarolReply {
        let descriptor = connected(to: path)
        guard descriptor >= 0 else { throw Failure.notRunning }
        defer { close(descriptor) }
        var line = try JSONEncoder().encode(FarolRequest(action: action))
        line.append(UInt8(ascii: "\n"))
        _ = line.withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(descriptor, &buffer, buffer.count)
            guard count > 0 else { break }
            data.append(contentsOf: buffer[0..<count])
            if buffer[0..<count].contains(UInt8(ascii: "\n")) { break }
        }
        guard !data.isEmpty, let reply = try? JSONDecoder().decode(FarolReply.self, from: data) else { throw Failure.tooOld }
        return reply
    }

    private static func connected(to path: String) -> Int32 {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return -1 }
        var on: Int32 = 1
        // Farol quitting mid-request should fail here, and not take this app down with a signal.
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        var limit = timeout
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < capacity else {
            close(descriptor)
            return -1
        }
        _ = withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: capacity) { strcpy($0, path) }
        }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard result == 0 else {
            close(descriptor)
            return -1
        }
        return descriptor
    }
}
