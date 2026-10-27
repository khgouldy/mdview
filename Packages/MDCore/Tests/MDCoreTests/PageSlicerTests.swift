import Foundation
import Testing
@testable import MDCore

struct PageSlicerTests {
    private typealias Slice = PageSlicer.Slice

    @Test func `exact multiple gives full pages and no empty last page`() {
        #expect(PageSlicer.slices(contentHeight: 1584, pageHeight: 792) == [
            Slice(offset: 0, height: 792),
            Slice(offset: 792, height: 792),
        ])
    }

    @Test func `remainder becomes a short last page`() {
        #expect(PageSlicer.slices(contentHeight: 2000, pageHeight: 792) == [
            Slice(offset: 0, height: 792),
            Slice(offset: 792, height: 792),
            Slice(offset: 1584, height: 416),
        ])
    }

    @Test func `tiny content is one short page`() {
        #expect(PageSlicer.slices(contentHeight: 10, pageHeight: 792) == [Slice(offset: 0, height: 10)])
    }

    @Test func `zero content is one empty page`() {
        #expect(PageSlicer.slices(contentHeight: 0, pageHeight: 792) == [Slice(offset: 0, height: 0)])
    }

    @Test(arguments: [-5, Double.nan, -Double.infinity])
    func `invalid content height is one empty page`(height: Double) {
        #expect(PageSlicer.slices(contentHeight: height, pageHeight: 792) == [Slice(offset: 0, height: 0)])
    }

    @Test func `layout rounding joins the last page instead of adding one`() {
        let slices = PageSlicer.slices(contentHeight: 1584.25, pageHeight: 792)
        #expect(slices.count == 2)
        #expect(slices.last == Slice(offset: 792, height: 792.25))
    }

    @Test(arguments: [0, -1, Double.nan, Double.infinity])
    func `a bad page height gives one slice of everything`(pageHeight: Double) {
        #expect(PageSlicer.slices(contentHeight: 900, pageHeight: pageHeight) == [Slice(offset: 0, height: 900)])
    }

    @Test(arguments: [1.0, 791.5, 792, 5000.3, 123_456.789])
    func `slices are contiguous and cover the content exactly`(content: Double) {
        let slices = PageSlicer.slices(contentHeight: content, pageHeight: 792)
        var offset = 0.0
        for slice in slices {
            #expect(slice.offset == offset)
            #expect(slice.height > 0)
            offset += slice.height
        }
        #expect(abs(offset - content) < 1e-9)
        #expect(slices.dropLast().allSatisfy { $0.height == 792 })
    }

    @Test(arguments: ["US", "CA", "MX", "us"])
    func `letter regions get letter paper`(region: String) {
        #expect(PaperSize.forRegion(region) == .usLetter)
    }

    @Test(arguments: ["GB", "DE", "JP", "AU", "", "ZZ"])
    func `other regions get a4`(region: String) {
        #expect(PaperSize.forRegion(region) == .isoA4)
    }

    @Test func `no region gets a4`() {
        #expect(PaperSize.forRegion(nil) == .isoA4)
    }

    @Test func `paper sizes are in points`() {
        #expect(PaperSize.usLetter.width == 612)
        #expect(PaperSize.usLetter.height == 792)
        #expect(abs(PaperSize.isoA4.width - 595.28) < 0.01)
        #expect(abs(PaperSize.isoA4.height - 841.89) < 0.01)
    }
}
