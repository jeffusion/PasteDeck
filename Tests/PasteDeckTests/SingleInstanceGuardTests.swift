import XCTest
import Darwin
@testable import PasteDeck

final class SingleInstanceGuardTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PasteDeckInstanceLock-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testAcquireIsMutuallyExclusive() throws {
        let lockDirectory = makeDirectory("mutual")
        let first = SingleInstanceGuard(directoryURL: lockDirectory)
        let second = SingleInstanceGuard(directoryURL: lockDirectory)

        XCTAssertTrue(try first.acquire())
        XCTAssertFalse(try second.acquire())
        XCTAssertTrue(first.isLocked)
        XCTAssertFalse(second.isLocked)
    }

    func testIndependentDirectoriesDoNotInterfere() throws {
        let first = SingleInstanceGuard(directoryURL: makeDirectory("first"))
        let second = SingleInstanceGuard(directoryURL: makeDirectory("second"))

        XCTAssertTrue(try first.acquire())
        XCTAssertTrue(try second.acquire())
    }

    func testRealChildProcessHoldsLockAndCrashReleasesIt() throws {
        let lockDirectory = makeDirectory("child")
        let helper = try compileLockHelper()
        let process = try launchLockHelper(helper, arguments: [lockDirectory.appendingPathComponent(".instance.lock").path, "crash"])

        defer {
            if process.isRunning { process.terminate(); process.waitUntilExit() }
        }
        let parentGuard = SingleInstanceGuard(directoryURL: lockDirectory)
        XCTAssertFalse(try parentGuard.acquire())

        XCTAssertEqual(kill(process.processIdentifier, SIGUSR1), 0)
        process.waitUntilExit()
        XCTAssertEqual(process.terminationReason, .uncaughtSignal)

        let replacement = SingleInstanceGuard(directoryURL: lockDirectory)
        XCTAssertTrue(try replacement.acquire())
    }

    func testReleaseAllowsReacquisition() throws {
        let directory = makeDirectory("release")
        var first: SingleInstanceGuard? = SingleInstanceGuard(directoryURL: directory)
        XCTAssertTrue(try first!.acquire())
        XCTAssertEqual(first?.ownerPID, getpid())
        first = nil
        XCTAssertTrue(try SingleInstanceGuard(directoryURL: directory).acquire())
    }

    func testLockFileIsCreatedWithoutRemoval() throws {
        let lockDirectory = makeDirectory("file")
        let guardObject = SingleInstanceGuard(directoryURL: lockDirectory)
        XCTAssertTrue(try guardObject.acquire())

        XCTAssertTrue(FileManager.default.fileExists(atPath: guardObject.lockFileURL.path))
    }

    func testLiveProcessIsRejectedRegardlessOfUpgradedBundleMetadata() {
        var time: TimeInterval = 0
        XCTAssertFalse(SingleInstanceGuard.waitForOtherInstancesToExit(
            timeout: 1, otherInstancesPresent: { true }, now: { time }, wait: { time += 0.1 }
        ))
        XCTAssertGreaterThanOrEqual(time, 1)
    }

    func testContendingStartupCanExitBeforeDatabaseIsOpened() {
        var time: TimeInterval = 0
        XCTAssertTrue(SingleInstanceGuard.waitForOtherInstancesToExit(
            timeout: 1, otherInstancesPresent: { time < 0.2 }, now: { time }, wait: { time += 0.1 }
        ))
        XCTAssertLessThan(time, 1)
    }

    private func makeDirectory(_ name: String) -> URL {
        let url = temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func compileLockHelper() throws -> URL {
        let sourceURL = temporaryDirectory.appendingPathComponent("lock_helper.c")
        let executableURL = temporaryDirectory.appendingPathComponent("lock_helper")
        let source = """
        #include <errno.h>
        #include <fcntl.h>
        #include <signal.h>
        #include <stdlib.h>
        #include <stdio.h>
        #include <sys/file.h>
        #include <unistd.h>

        static void crash(int signalNumber) {
            (void)signalNumber;
            abort();
        }

        int main(int argc, char **argv) {
            if (argc != 3) { return 2; }
            int fd = open(argv[1], O_RDWR | O_CREAT, 0600);
            if (fd < 0) { return 3; }
            if (flock(fd, LOCK_EX | LOCK_NB) != 0) { return 4; }
            fputs("LOCKED\\n", stdout);
            fflush(stdout);
            if (argv[2][0] == 'c') {
                signal(SIGUSR1, crash);
            }
            for (;;) { pause(); }
        }
        """
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/clang")
        process.arguments = [sourceURL.path, "-o", executableURL.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, "The system clang lock helper failed to compile")
        return executableURL
    }

    private func launchLockHelper(_ executableURL: URL, arguments: [String]) throws -> Process {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        try process.run()
        let marker = output.fileHandleForReading.readData(ofLength: "LOCKED\n".utf8.count)
        XCTAssertEqual(String(data: marker, encoding: .utf8), "LOCKED\n")
        return process
    }
}
