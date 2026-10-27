import Testing
@testable import MDCore

struct RenderPipelineTests {
    private let input = "---\ntitle: x\n---\nSee [[Note]] ![pic](https://example.com/a.png)\n"

    @Test func `obsidian on strips front matter and links remote images`() {
        let output = RenderPipeline.prepare(input, obsidian: true)
        #expect(!output.contains("title: x"))
        #expect(!output.contains("[[Note]]"))
        #expect(output.contains("[Image: pic](https://example.com/a.png)"))
    }

    @Test func `obsidian off keeps front matter and still links remote images`() {
        let output = RenderPipeline.prepare(input, obsidian: false)
        #expect(output.contains("title: x"))
        #expect(output.contains("[[Note]]"))
        #expect(output.contains("[Image: pic](https://example.com/a.png)"))
    }

    @Test func `math is ignored for now`() {
        #expect(RenderPipeline.prepare(input, obsidian: true, math: true) == RenderPipeline.prepare(
            input,
            obsidian: true,
        ))
    }
}
