import XCTest
@testable import MDCore

final class ImagePolicyTests: XCTestCase {
    func testFileURLIsAllowed() {
        let url = URL(fileURLWithPath: "/tmp/photo.png")
        XCTAssertTrue(ImagePolicy.allows(url))
    }

    func testHTTPIsRejected() throws {
        let url = try XCTUnwrap(URL(string: "http://example.com/photo.png"))
        XCTAssertFalse(ImagePolicy.allows(url))
    }

    func testHTTPSIsRejected() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/photo.png"))
        XCTAssertFalse(ImagePolicy.allows(url))
    }

    func testDataURLIsRejected() throws {
        let url = try XCTUnwrap(URL(string: "data:image/png;base64,aaaa"))
        XCTAssertFalse(ImagePolicy.allows(url))
    }

    func testFTPIsRejected() throws {
        let url = try XCTUnwrap(URL(string: "ftp://example.com/photo.png"))
        XCTAssertFalse(ImagePolicy.allows(url))
    }
}
