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

    @Test func `task step runs after front matter removal and before remote image linkify`() {
        let markdown = "---\n- [x] meta\n---\n- [ ] todo ![p](https://e.com/a.png)\n"
        let withObsidian = RenderPipeline.prepare(markdown, obsidian: true)
        #expect(!withObsidian.contains("meta"))
        #expect(withObsidian.contains("- ![Not done](x-mdview-task:unchecked) todo [Image: p](https://e.com/a.png)"))
        let without = RenderPipeline.prepare(markdown, obsidian: false)
        #expect(without.contains("- ![Done](x-mdview-task:checked) meta"))
    }
}
