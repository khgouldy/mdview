import XCTest
@testable import MDCore

final class RemoteImagesTests: XCTestCase {
    func testRemoteImageBecomesLink() {
        let input = "![cat](https://example.com/cat.png) and ![dog](http://example.com/dog.png)"
        let expected = """
        [Image: cat](https://example.com/cat.png) and [Image: dog](http://example.com/dog.png)
        """
        XCTAssertEqual(RemoteImages.linkify(input), expected)
    }

    func testLocalImagesAreUntouched() {
        let input = "![local](images/cat.png) ![file](file:///tmp/cat.png)"
        XCTAssertEqual(RemoteImages.linkify(input), input)
    }

    func testFencedCodeImageIsUntouched() {
        let input = """
        ```markdown
        ![cat](https://example.com/cat.png)
        ```
        ![outside](https://example.com/outside.png)
        """
        let expected = """
        ```markdown
        ![cat](https://example.com/cat.png)
        ```
        [Image: outside](https://example.com/outside.png)
        """
        XCTAssertEqual(RemoteImages.linkify(input), expected)
    }

    func testInlineCodeImageIsUntouched() {
        let input = "Type `![cat](https://example.com/cat.png)` then ![dog](https://example.com/dog.png)."
        let expected = """
        Type `![cat](https://example.com/cat.png)` then [Image: dog](https://example.com/dog.png).
        """
        XCTAssertEqual(RemoteImages.linkify(input), expected)
    }

    func testTildeFenceAndPlainLinkAreUntouched() {
        let input = """
        ~~~
        ![cat](https://example.com/cat.png)
        ~~~
        [site](https://example.com)
        """
        XCTAssertEqual(RemoteImages.linkify(input), input)
    }

    func testEscapedRemoteImageIsUntouched() {
        let input = "\\![cat](https://example.com/cat.png)"
        XCTAssertEqual(RemoteImages.linkify(input), input)
    }
}
