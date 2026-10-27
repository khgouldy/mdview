# Third-party notices

mdview is MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Kevin Gould / Par72 Labs, LLC.

The app target depends on Textual 0.5.0, vendored at `Vendor/textual` (its MIT `LICENSE` kept) with one mdview patch described in `Vendor/textual/MDVIEW_PATCH.md`. Textual links swiftui-math and swift-concurrency-extras, and it bundles Prism.js for code highlighting. Those four components ship in the app. All four are MIT.

`mdview.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` pins two Swift packages; Textual is vendored, not pinned. Each is MIT, which is compatible with this MIT repository. Nothing in that file is under a license outside MIT, BSD, and Apache-2.0.

| Package | Version | License |
| --- | --- | --- |
| [textual](https://github.com/gonzalezreal/textual) | 0.5.0 (`01b51875a5406eefc95f52a058cb059e7bc94dc4`), vendored in `Vendor/textual` with one patch | MIT |
| [swiftui-math](https://github.com/gonzalezreal/swiftui-math) | 0.1.0 (`0b5c2cfaaec8d6193db206f675048eeb5ce95f71`) | MIT |
| [swift-concurrency-extras](https://github.com/pointfreeco/swift-concurrency-extras) | 1.4.3 (`8a4260f7373493435bd21194585c95b72bfdd401`) | MIT |

Textual's test-only dependency swift-snapshot-testing is not in this app's `Package.resolved` and is not linked.

Math is off by default. The reader menu has a Math (LaTeX) switch (`reader.math`); only when it is on does mdview apply Textual's math syntax, which draws formulas with swiftui-math. swiftui-math ships either way because Textual links the SwiftUIMath product.

## Textual

https://github.com/gonzalezreal/textual

MIT License

Copyright (c) 2024 Guille Gonzalez

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## swiftui-math

https://github.com/gonzalezreal/swiftui-math

The upstream license names SwiftUIMath and the projects it incorporates (SwiftMath, iosMath). One MIT license covers them.

MIT License

Copyright (c) 2026 Guille Gonzalez
Copyright (c) 2023 Computer Inspirations (SwiftMath)
Copyright (c) 2013 MathChat (iosMath)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## swift-concurrency-extras

https://github.com/pointfreeco/swift-concurrency-extras

Product name in Textual: ConcurrencyExtras.

MIT License

Copyright (c) 2023 Point-Free

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Prism.js

Bundled inside Textual 0.5.0 at `Sources/Textual/Internal/Highlighter/Prism/prism-bundle.js`. Textual's `Scripts/bundle-prism.sh` builds that file from Prism.js 1.29.0 (core plus language components from the same project).

https://github.com/PrismJS/prism

MIT LICENSE

Copyright (c) 2012 Lea Verou

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
