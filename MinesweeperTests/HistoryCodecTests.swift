import XCTest
@testable import Minesweeper

final class HistoryCodecTests: XCTestCase {
    private let magic = Data([0x4D, 0x53, 0x48, 0x31]) // "MSH1"

    func testLargePayloadRoundTripsAndCompresses() throws {
        let json = Data(repeating: 0x41, count: 64 * 1024)
        let payload = try XCTUnwrap(HistoryCodec.encode(json))

        XCTAssertTrue(payload.starts(with: magic))
        XCTAssertLessThan(payload.count, json.count)
        XCTAssertEqual(HistoryCodec.decode(payload), json)
    }

    func testSmallPayloadStaysRaw() throws {
        let json = Data("[]".utf8)
        let payload = try XCTUnwrap(HistoryCodec.encode(json))

        XCTAssertFalse(payload.starts(with: magic))
        XCTAssertEqual(payload, json)
        XCTAssertEqual(HistoryCodec.decode(payload), json)
    }

    func testLegacyRawJSONDecodesUnchanged() throws {
        let legacy = Data(#"[{"id":"legacy","date":123.5}]"#.utf8)
        XCTAssertEqual(HistoryCodec.decode(legacy), legacy)
    }

    func testCorruptEnvelopeReturnsNil() {
        let corrupt = magic + Data([0x00, 0x01, 0x02])
        XCTAssertNil(HistoryCodec.decode(corrupt))
    }
}
