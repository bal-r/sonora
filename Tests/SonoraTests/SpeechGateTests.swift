import Foundation
import XCTest
@testable import Sonora

final class SpeechGateTests: XCTestCase {
    private let rate = AudioFormat.sampleRate

    func testSilenceIsRejected() {
        let samples = [Float](repeating: 0, count: Int(rate))
        let result = SpeechGate.trim(samples)
        XCTAssertFalse(result.hadSpeech)
        XCTAssertTrue(result.samples.isEmpty)
    }

    func testEmptyInputIsRejected() {
        let result = SpeechGate.trim([])
        XCTAssertFalse(result.hadSpeech)
    }

    func testToneIsKeptAndTrimmed() {
        let seconds = 1.0
        let count = Int(rate * seconds)
        var samples = [Float](repeating: 0, count: count)
        let start = Int(rate * 0.25)
        let end = Int(rate * 0.75)
        for index in start..<end {
            samples[index] = 0.25 * sin(2 * Float.pi * 440 * Float(index) / Float(rate))
        }

        let result = SpeechGate.trim(samples)
        XCTAssertTrue(result.hadSpeech)
        XCTAssertGreaterThan(result.samples.count, Int(rate * 0.4))
        XCTAssertLessThan(result.samples.count, samples.count)
        XCTAssertGreaterThan(result.samples.count, Int(rate * 0.2))
    }

    func testShortClickIsRejected() {
        var samples = [Float](repeating: 0, count: Int(rate))
        for index in 0..<Int(rate * 0.05) {
            samples[index] = 0.3
        }
        let result = SpeechGate.trim(samples)
        XCTAssertFalse(result.hadSpeech)
    }

    func testVeryQuietSpeechIsRejected() {
        var samples = [Float](repeating: 0, count: Int(rate))
        for index in 0..<Int(rate * 0.5) {
            samples[index] = 0.0002 * sin(2 * Float.pi * 300 * Float(index) / Float(rate))
        }
        let result = SpeechGate.trim(samples)
        XCTAssertFalse(result.hadSpeech)
    }
}
