import XCTest
@testable import FLXPad

final class FLX4Tests: XCTestCase {
    func testPackIsMIDI1ChannelVoiceUMP() {
        XCTAssertEqual(UMP.pack(0x90, 0x0B, 0x7F), 0x2090_0B7F)
    }

    func testShortMessagesSkipsSysEx() {
        // A 2-word SysEx7 packet whose 2nd word looks like a channel voice message, then a real note.
        let words: [UInt32] = [0x3006_F000, 0x2000_0000, 0x2090_0B7F, 0x20B0_0240]
        let msgs = UMP.shortMessages(words)
        XCTAssertEqual(msgs.count, 2)
        XCTAssertTrue(msgs[0] == (0x90, 0x0B, 0x7F))
        XCTAssertTrue(msgs[1] == (0xB0, 0x02, 0x40))
    }

    func testSplit14() {
        XCTAssertTrue(FLX4.split14(0) == (0, 0))
        XCTAssertTrue(FLX4.split14(0.5) == (64, 0)) // 8192 = Mixxx tempo centre
        XCTAssertTrue(FLX4.split14(1) == (127, 127))
        XCTAssertTrue(FLX4.split14(2) == (127, 127))
    }

    func testJogValuesAreCentredOn64AndChunked() {
        XCTAssertEqual(FLX4.jogValues(0), [])
        XCTAssertEqual(FLX4.jogValues(5), [69])
        XCTAssertEqual(FLX4.jogValues(-70), [1, 57])
        XCTAssertEqual(FLX4.jogValues(100), [127, 101])
    }

    func testPadAddressing() {
        XCTAssertEqual(FLX4.padStatus(0, shift: false), 0x97)
        XCTAssertEqual(FLX4.padStatus(1, shift: true), 0x9A)
        XCTAssertEqual(FLX4.PadMode.stems.firstPad + 3, 0x43) // stem 4 mute on Mixxx
    }
}
