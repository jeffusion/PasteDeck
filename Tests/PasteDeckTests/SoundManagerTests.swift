import XCTest
@testable import PasteDeck

@MainActor
final class SoundManagerTests: XCTestCase {
    func testPlayingSoundIsStoppedRewoundAndRestarted() {
        let sound = MockSound(isPlaying: true, currentTime: 0.4)
        let manager = SoundManager(
            sounds: [.captured: sound],
            isSoundEnabled: { true }
        )

        manager.playSound(for: .captured)

        XCTAssertEqual(sound.events, [.stop, .seek(0), .play])
        XCTAssertTrue(sound.isPlaying)
    }

    func testIdleSoundIsRewoundAndPlayedImmediately() {
        let sound = MockSound(isPlaying: false, currentTime: 0.4)
        let manager = SoundManager(
            sounds: [.captured: sound],
            isSoundEnabled: { true }
        )

        manager.playSound(for: .captured)

        XCTAssertEqual(sound.events, [.seek(0), .play])
        XCTAssertTrue(sound.isPlaying)
    }

    func testDisabledSoundDoesNotChangePlayback() {
        let sound = MockSound(isPlaying: true, currentTime: 0.4)
        let manager = SoundManager(
            sounds: [.captured: sound],
            isSoundEnabled: { false }
        )

        manager.playSound(for: .captured)

        XCTAssertTrue(sound.events.isEmpty)
        XCTAssertEqual(sound.currentTime, 0.4)
    }
}

private final class MockSound: SoundPlayback {
    enum Event: Equatable {
        case stop
        case seek(TimeInterval)
        case play
    }

    var currentTime: TimeInterval {
        didSet {
            events.append(.seek(currentTime))
        }
    }
    private(set) var isPlaying: Bool
    private(set) var events: [Event] = []

    init(isPlaying: Bool, currentTime: TimeInterval) {
        self.isPlaying = isPlaying
        self.currentTime = currentTime
    }

    func play() -> Bool {
        events.append(.play)
        isPlaying = true
        return true
    }

    func stop() -> Bool {
        events.append(.stop)
        isPlaying = false
        return true
    }
}
