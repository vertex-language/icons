// gen: writes this repository's icon sets from the react-icons npm
// package -- every set it has, each icon as SVG markup in a Vertex
// package of its own. The package is data here: its JavaScript is read
// for the JSON each icon is, and nothing of it runs.
//
//     npm pack react-icons@5.5.0 && tar xzf react-icons-5.5.0.tgz
//     vsc run gen -- package/          # from the repository's root
package main

import (
    "encoding/json"
    "fs"
    "os/process"
)

/// A set: react-icons' id for it, the package it becomes, and the prefix
/// its icons' names carry there.
struct set {
    var id: string
    var leaf: string
    var prefix: string
}

let sets: [set] = [
    set(id: "ai", leaf: "antdesign", prefix: "Ai"),
    set(id: "bi", leaf: "boxicons", prefix: "Bi"),
    set(id: "bs", leaf: "bootstrap", prefix: "Bs"),
    set(id: "cg", leaf: "cssgg", prefix: "Cg"),
    set(id: "ci", leaf: "circum", prefix: "Ci"),
    set(id: "di", leaf: "devicons", prefix: "Di"),
    set(id: "fa", leaf: "fontawesome5", prefix: "Fa"),
    set(id: "fa6", leaf: "fontawesome6", prefix: "Fa"),
    set(id: "fc", leaf: "flatcolor", prefix: "Fc"),
    set(id: "fi", leaf: "feather", prefix: "Fi"),
    set(id: "gi", leaf: "gameicons", prefix: "Gi"),
    set(id: "go", leaf: "octicons", prefix: "Go"),
    set(id: "gr", leaf: "grommet", prefix: "Gr"),
    set(id: "hi", leaf: "heroicons", prefix: "Hi"),
    set(id: "hi2", leaf: "heroicons2", prefix: "Hi"),
    set(id: "im", leaf: "icomoon", prefix: "Im"),
    set(id: "io", leaf: "ionicons4", prefix: "Io"),
    set(id: "io5", leaf: "ionicons5", prefix: "Io"),
    set(id: "lia", leaf: "lineawesome", prefix: "Lia"),
    set(id: "lu", leaf: "lucide", prefix: "Lu"),
    set(id: "md", leaf: "material", prefix: "Md"),
    set(id: "pi", leaf: "phosphor", prefix: "Pi"),
    set(id: "ri", leaf: "remix", prefix: "Ri"),
    set(id: "rx", leaf: "radix", prefix: "Rx"),
    set(id: "si", leaf: "simpleicons", prefix: "Si"),
    set(id: "sl", leaf: "simpleline", prefix: "Sl"),
    set(id: "tb", leaf: "tabler", prefix: "Tb"),
    set(id: "tfi", leaf: "themify", prefix: "Tfi"),
    set(id: "ti", leaf: "typicons", prefix: "Ti"),
    set(id: "vsc", leaf: "codicons", prefix: "Vsc"),
    set(id: "wi", leaf: "weather", prefix: "Wi"),
]

/// React's attribute names, as SVG has them.
let attributeNames: [string: string] = [
    "strokeWidth": "stroke-width", "strokeLinecap": "stroke-linecap", "strokeLinejoin": "stroke-linejoin",
    "strokeMiterlimit": "stroke-miterlimit", "strokeOpacity": "stroke-opacity", "strokeDasharray": "stroke-dasharray",
    "fillRule": "fill-rule", "clipRule": "clip-rule", "fillOpacity": "fill-opacity", "stopColor": "stop-color",
    "stopOpacity": "stop-opacity", "clipPath": "clip-path",
]

/// What says nothing about how an icon looks.
let dropped: [string] = ["role", "aria-hidden", "version", "baseProfile", "enableBackground", "t", "xmlns", "xmlnsXlink",
                         "className", "class"]

/// What the <svg> drops besides: its size is the caller's. A <rect> or
/// <image> keeps its own.
let droppedAtRoot: [string] = ["width", "height"]

/// Names a set can't use as they are.
let reserved: [string] = ["Self", "Any", "Type", "Protocol", "Never", "Some", "Ok", "None"]

func fail(_ s: string) -> Never {
    print("gen: \(s)")
    process.Exit(1)
}

func escapeAttribute(_ s: string) -> string {
    var out = ""
    for ch in s {
        switch ch {
        case "&": out += "&amp;"
        case "'": out += "&#39;"
        case "<": out += "&lt;"
        default: out.append(ch)
        }
    }
    return out
}

/// Text in a Vertex string literal.
func literal(_ s: string) -> string {
    var out = ""
    for ch in s {
        switch ch {
        case "\\": out += "\\\\"
        case "\"": out += "\\\""
        case "\n": out += " "
        default: out.append(ch)
        }
    }
    return out
}

/// An element and what's inside it, as markup. The <svg> gets
/// react-icons' defaults under its own attributes: the current color for
/// fill and stroke, and no stroke width, as IconBase draws it.
func markup(_ v: json.Value, root: bool) -> string {
    guard let o = v.Object, let tag = o["tag"]?.String else { return "" }
    var attrs: [(string, string)] = []
    func set(_ k: string, _ value: string) {
        for i in 0..<attrs.count where attrs[i].0 == k {
            attrs[i].1 = value
            return
        }
        attrs.append((k, value))
    }
    if root {
        if let vb = o["attr"]?["viewBox"]?.String { set("viewBox", vb) }
        set("fill", "currentColor")
        set("stroke", "currentColor")
        set("stroke-width", "0")
    }
    if let a = o["attr"]?.Object {
        for (k, val) in a.Members {
            if dropped.contains(k) || (root && (k == "viewBox" || droppedAtRoot.contains(k))) { continue }
            let name = attributeNames[k] ?? k
            var text = val.String ?? (val.Double.map { "\($0)" } ?? "")
            if let n = val.Int { text = "\(n)" }
            set(name, text)
        }
    }
    var s = "<" + tag
    for (k, val) in attrs { s += " \(k)='\(escapeAttribute(val))'" }
    let children = o["child"]?.Array ?? []
    if children.isEmpty { return s + "/>" }
    s += ">"
    for c in children { s += markup(c, root: false) }
    return s + "</\(tag)>"
}

/// The icon's name in its package: the set's prefix taken off.
func vertexName(_ reactName: string, _ prefix: string) -> string {
    var n = reactName
    if n.hasPrefix(prefix) { n = String(n.dropFirst(prefix.count)) }
    if n.isEmpty { n = reactName }
    if let f = n.unicodeScalars.first, f.value >= 0x30 && f.value <= 0x39 { n = "Icon" + n }
    if reserved.contains(n) { n += "Icon" }
    return n
}

/// The icons of a set's index.js: each a name and the JSON GenIcon is
/// given.
func iconsIn(_ js: string) -> [(string, string)] {
    var out: [(string, string)] = []
    let b = [uint8](js.utf8)
    let head = [uint8]("module.exports.".utf8)
    let gen = [uint8]("GenIcon(".utf8)
    let tail = [uint8](")(props);".utf8)
    func find(_ needle: [uint8], from: int) -> int {
        var i = from
        while i + needle.count <= b.count {
            if b[i] == needle[0] {
                var j = 1
                while j < needle.count && b[i + j] == needle[j] { j += 1 }
                if j == needle.count { return i }
            }
            i += 1
        }
        return -1
    }
    var at = 0
    while true {
        let h = find(head, from: at)
        if h < 0 { break }
        var e = h + head.count
        while e < b.count && b[e] != 0x20 && b[e] != 0x3D { e += 1 }
        let name = string(decoding: [uint8](b[(h + head.count)..<e]), as: UTF8.self)
        let g = find(gen, from: e)
        if g < 0 { break }
        let t = find(tail, from: g)
        if t < 0 { break }
        out.append((name, string(decoding: [uint8](b[(g + gen.count)..<t]), as: UTF8.self)))
        at = t + tail.count
    }
    return out
}

let args = CommandLine.arguments
if args.count < 2 { fail("give the react-icons package's directory: vsc run gen -- package/") }
let src = args[1]
let out = args.count > 2 ? args[2] : "."
let pkgVersion = (try? json.Parse(try fs.ReadText(fs.Path(src + "/package.json"))))?["version"]?.String ?? "?"

// The manifest: each set's name, home and license.
let manifestJS = (try? fs.ReadText(fs.Path(src + "/lib/iconsManifest.js"))) ?? ""
var manifest: [string: json.Object] = [:]
do {
    let mb = [uint8](manifestJS.utf8)
    var a = 0
    while a < mb.count && mb[a] != 0x5B { a += 1 }
    var z = mb.count - 1
    while z > a && mb[z] != 0x5D { z -= 1 }
    if a < z, let list = try? json.Parse(string(decoding: [uint8](mb[a...z]), as: UTF8.self)).Array {
        for item in list {
            if let o = item.Object, let id = o["id"]?.String { manifest[id] = o }
        }
    }
}

var total = 0
var table: [string] = []
for s in sets {
    guard let js = try? fs.ReadText(fs.Path(src + "/" + s.id + "/index.js")) else { fail("no \(s.id)/index.js in \(src)") }
    let info = manifest[s.id] ?? json.Object()
    let setName = info["name"]?.String ?? s.leaf
    let home = info["projectUrl"]?.String ?? ""
    let license = info["license"]?.String ?? ""
    let licenseUrl = info["licenseUrl"]?.String ?? ""
    let dir = out + "/" + s.leaf
    try? fs.RemoveAll(fs.Path(dir))
    try fs.CreateDir(fs.Path(dir), all: true)
    // By the first letter of the name, a file each.
    var files: [string: [string]] = [:]
    var seen: [string: bool] = [:]
    var count = 0
    var first = ""
    for (reactName, data) in iconsIn(js) {
        guard let tree = try? json.Parse(data) else { fail("\(reactName): its JSON doesn't parse") }
        var name = vertexName(reactName, s.prefix)
        while seen[name] != nil { name += "Alt" }
        seen[name] = true
        if first.isEmpty { first = name }
        let letter = String(name.prefix(1)).lowercased()
        let line = "public var \(name): icons.Icon { return icons.Icon(\"\(name)\", \"\(literal(markup(tree, root: true)))\") }"
        files[letter, default: []].append(line)
        count += 1
    }
    for (letter, lines) in files {
        let text = "// Generated by cmd/gen from react-icons \(pkgVersion). Do not edit.\n\npackage \(s.leaf)\n\nimport \"icons\"\n\n" + lines.joined(separator: "\n") + "\n"
        try fs.WriteText(fs.Path(dir + "/" + letter + ".vs"), text)
    }
    let doc = """
    // Package \(s.leaf) is \(setName): \(count) icons\(home.isEmpty ? "" : ", from \(home)"), under the \(license)
    // (\(licenseUrl)). Generated by cmd/gen from react-icons \(pkgVersion).
    //
    //     import "icons/\(s.leaf)"
    //
    //     let file = \(s.leaf).\(first).SVG(size: 24)
    //     <icon.Icon icon={\(s.leaf).\(first)} size={16} />    // ui/icon
    package \(s.leaf)

    """
    try fs.WriteText(fs.Path(dir + "/doc.vs"), doc)
    table.append("| [`icons/\(s.leaf)`](\(s.leaf)) | \(setName) | \(count) | [\(license)](\(licenseUrl)) |")
    total += count
    print("\(s.leaf): \(count)")
}

let sets_md = """
<!-- Generated by cmd/gen. -->
| Package | Set | Icons | License |
| :--- | :--- | ---: | :--- |
\(table.joined(separator: "\n"))

\(total) icons, from react-icons \(pkgVersion).

"""
try fs.WriteText(fs.Path(out + "/SETS.md"), sets_md)
print("\(total) icons in \(sets.count) sets")
