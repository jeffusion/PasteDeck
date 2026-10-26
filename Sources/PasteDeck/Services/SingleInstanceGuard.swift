import Foundation
import Darwin

/// Holds an exclusive, non-blocking process lock for one PasteDeck database directory.
///
/// The file descriptor remains open for the lifetime of this object. In the running app the
/// AppDelegate keeps the object alive until process exit; the lock file itself is never removed,
/// and the operating system releases the advisory lock when a process terminates.
final class SingleInstanceGuard {
    enum LockError: Error, Equatable {
        case directoryCreationFailed
        case openFailed(errno: Int32)
        case flockFailed(errno: Int32)
    }

    private let directoryURL: URL
    private var fileDescriptor: Int32 = -1

    var lockFileURL: URL {
        directoryURL.appendingPathComponent(".instance.lock", isDirectory: false)
    }

    var ownerPID: pid_t? {
        guard let text = try? String(contentsOf: lockFileURL, encoding: .utf8) else { return nil }
        return pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var isLocked: Bool {
        fileDescriptor >= 0
    }

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    deinit {
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    /// The on-disk bundle may have been upgraded while an old process is alive.
    /// Only process exit (not its current Info.plist) establishes safe access.
    static func waitForOtherInstancesToExit(
        timeout: TimeInterval = 3,
        otherInstancesPresent: () -> Bool,
        now: () -> TimeInterval = { Date.timeIntervalSinceReferenceDate },
        wait: () -> Void = { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    ) -> Bool {
        let deadline = now() + timeout
        while otherInstancesPresent() {
            guard now() < deadline else { return false }
            wait()
        }
        return true
    }

    /// Returns `true` when this process owns the lock, and `false` when another process owns it.
    func acquire() throws -> Bool {
        guard fileDescriptor < 0 else { return true }

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw LockError.directoryCreationFailed
        }

        let descriptor = lockFileURL.path.withCString { path in
            open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0o600)
        }
        guard descriptor >= 0 else {
            throw LockError.openFailed(errno: errno)
        }

        let result = flock(descriptor, LOCK_EX | LOCK_NB)
        guard result == 0 else {
            let flockErrno = errno
            close(descriptor)
            if flockErrno == EWOULDBLOCK || flockErrno == EAGAIN {
                return false
            }
            throw LockError.flockFailed(errno: flockErrno)
        }

        let owner = Array("\(getpid())\n".utf8)
        guard ftruncate(descriptor, 0) == 0,
              owner.withUnsafeBytes({ write(descriptor, $0.baseAddress, $0.count) }) == owner.count else {
            let savedErrno = errno
            close(descriptor)
            throw LockError.openFailed(errno: savedErrno)
        }
        fileDescriptor = descriptor
        return true
    }
}
