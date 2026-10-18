// Package icons is what every icon set in this repository is made of: an
// Icon, its SVG markup, and ways to show it -- drawn into a canvas, as an
// SVG file, or as the elements a page shows (ui/icon). The sets are the
// packages beside it, one per set, generated from react-icons by
// cmd/gen: icons/lucide, icons/material, icons/fontawesome6, ...
//
//     import "icons/lucide"
//
//     let svgText = lucide.Settings.SVG(size: 24)
//     lucide.Settings.Draw(on: canvas, into: draw.Rect(0, 0, 32, 32), color: draw.Color(0, 0, 0))
//
// Each icon is a computed property, so a program carries only the icons
// it names once the linker strips what nothing reaches.
package icons

import (
    "image/draw"
    "web/svg"
)

/// An icon: its name, and its drawing as SVG markup -- an <svg> element
/// with its viewBox and presentation attributes, and the shapes inside,
/// in currentColor wherever the set draws in the text's color.
public struct Icon: Equatable {
    public let Name: string
    /// The <svg> element, without a namespace or a size: attributes are
    /// single-quoted.
    public let Markup: string

    public init(_ name: string, _ markup: string) {
        Name = name
        Markup = markup
    }

    /// The viewBox: where the drawing's coordinates run.
    public var ViewBox: draw.Rect {
        if let v = rootAttribute("viewBox") {
            let n = numbersIn(v)
            if n.count == 4 && n[2] > 0 && n[3] > 0 { return draw.Rect(n[0], n[1], n[2], n[3]) }
        }
        return draw.Rect(0, 0, 24, 24)
    }

    /// An SVG file of the icon: size pixels square (or the viewBox's size),
    /// in color (any CSS color; currentColor's default otherwise).
    public func SVG(size: float32? = nil, color: string? = nil) -> string {
        var extra = " xmlns='http://www.w3.org/2000/svg'"
        if let s = size { extra += " width='\(trimmedNumber(s))' height='\(trimmedNumber(s))'" }
        if let c = color { extra += " color='\(c)' style='color:\(c)'" }
        let b = [uint8](Markup.utf8)
        // After "<svg".
        if b.count < 4 { return Markup }
        return string(decoding: [uint8](b[0..<4]), as: UTF8.self) + extra + string(decoding: [uint8](b[4...]), as: UTF8.self)
    }

    /// Draws the icon fitted into a rectangle of device pixels, in color
    /// (what the icon's currentColor is).
    public func Draw(on canvas: draw.Canvas, into r: draw.Rect, color: draw.Color) {
        guard let doc = drawingFor(Markup) else { return }
        doc.Drawing.Render(on: canvas, into: r, scale: 1, currentColor: color, fill: nil, fillNone: false)
    }

    /// The <svg> element and what is inside it, for building markup.
    public var Root: Element {
        var p = parser(Markup)
        return p.element() ?? Element(Tag: "svg", Attributes: [], Children: [])
    }

    func rootAttribute(_ name: string) -> string? {
        for (k, v) in Root.Attributes where k == name { return v }
        return nil
    }
}

/// An element of an icon's markup: its tag, its attributes in order, and
/// what is inside it.
public struct Element: Equatable {
    public var Tag: string
    public var Attributes: [(string, string)]
    public var Children: [Element]

    public init(Tag: string, Attributes: [(string, string)], Children: [Element]) {
        self.Tag = Tag
        self.Attributes = Attributes
        self.Children = Children
    }

    public static func == (a: Element, b: Element) -> bool {
        if a.Tag != b.Tag || a.Attributes.count != b.Attributes.count || a.Children != b.Children { return false }
        for i in 0..<a.Attributes.count where a.Attributes[i].0 != b.Attributes[i].0 || a.Attributes[i].1 != b.Attributes[i].1 { return false }
        return true
    }
}

// Drawings already parsed, by markup: an icon drawn every frame is read
// once.
var drawings: [string: svg.Document] = [:]

func drawingFor(_ markup: string) -> svg.Document? {
    if let d = drawings[markup] { return d }
    let file = "<svg xmlns='http://www.w3.org/2000/svg'" + string(decoding: [uint8]([uint8](markup.utf8).dropFirst(4)), as: UTF8.self)
    guard let doc = svg.ParseDocument([uint8](file.utf8)) else { return nil }
    if drawings.count > 512 { drawings = [:] }
    drawings[markup] = doc
    return doc
}

/// Reads the markup cmd/gen writes: elements, single- or double-quoted
/// attributes, self-closing or with children, and the five XML entities.
struct parser {
    let b: [uint8]
    var i = 0

    init(_ s: string) {
        b = [uint8](s.utf8)
    }

    mutating func space() {
        while i < b.count && (b[i] == 0x20 || b[i] == 0x0A || b[i] == 0x09 || b[i] == 0x0D) { i += 1 }
    }

    mutating func name() -> string {
        let start = i
        while i < b.count && b[i] != 0x20 && b[i] != 0x2F && b[i] != 0x3E && b[i] != 0x3D && b[i] != 0x0A { i += 1 }
        return string(decoding: [uint8](b[start..<i]), as: UTF8.self)
    }

    mutating func element() -> Element? {
        space()
        if i >= b.count || b[i] != 0x3C { return nil }
        i += 1
        let tag = name()
        var attrs: [(string, string)] = []
        while true {
            space()
            if i >= b.count { return nil }
            if b[i] == 0x2F {  // />
                i += 2
                return Element(Tag: tag, Attributes: attrs, Children: [])
            }
            if b[i] == 0x3E {
                i += 1
                break
            }
            let k = name()
            space()
            var v = ""
            if i < b.count && b[i] == 0x3D {
                i += 1
                space()
                if i < b.count && (b[i] == 0x27 || b[i] == 0x22) {
                    let q = b[i]
                    i += 1
                    let start = i
                    while i < b.count && b[i] != q { i += 1 }
                    v = unescape([uint8](b[start..<i]))
                    i += 1
                }
            }
            attrs.append((k, v))
        }
        var children: [Element] = []
        while true {
            space()
            if i + 1 < b.count && b[i] == 0x3C && b[i + 1] == 0x2F {
                // </tag>
                while i < b.count && b[i] != 0x3E { i += 1 }
                i += 1
                break
            }
            guard let c = element() else { break }
            children.append(c)
        }
        return Element(Tag: tag, Attributes: attrs, Children: children)
    }
}

func unescape(_ v: [uint8]) -> string {
    if !v.contains(0x26) { return string(decoding: v, as: UTF8.self) }
    var s = string(decoding: v, as: UTF8.self)
    for (e, c) in [("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")] {
        s = replaced(s, e, c)
    }
    return s
}

func replaced(_ s: string, _ from: string, _ to: string) -> string {
    let a = [uint8](s.utf8)
    let f = [uint8](from.utf8)
    var out: [uint8] = []
    var i = 0
    while i < a.count {
        if i + f.count <= a.count {
            var j = 0
            while j < f.count && a[i + j] == f[j] { j += 1 }
            if j == f.count {
                out.append(contentsOf: [uint8](to.utf8))
                i += f.count
                continue
            }
        }
        out.append(a[i])
        i += 1
    }
    return string(decoding: out, as: UTF8.self)
}

func numbersIn(_ s: string) -> [float32] {
    var out: [float32] = []
    for part in s.split(whereSeparator: { $0 == " " || $0 == "," }) {
        if let v = float32(String(part)) { out.append(v) }
    }
    return out
}

func trimmedNumber(_ v: float32) -> string {
    if v == float32(int(v)) { return "\(int(v))" }
    return "\(v)"
}
