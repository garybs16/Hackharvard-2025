import Foundation
#if canImport(RealityKitContent)
import RealityKitContent
#endif

private func recursiveSearch(in bundle: Bundle, name: String, ext: String) -> URL? {
    guard let root = bundle.resourcePath else { return nil }
    let fm = FileManager.default
    if let enumerator = fm.enumerator(atPath: root) {
        for case let path as String in enumerator {
            if path.hasSuffix("/._") { continue } // skip metadata
            let url = URL(fileURLWithPath: root).appendingPathComponent(path)
            if url.lastPathComponent == "\(name).\(ext)" { return url }
        }
    }
    return nil
}

/// Returns a URL for a demo resource (e.g., "page1Demo") by searching multiple bundles.
/// Search order:
/// 1. Main app bundle (direct lookup)
/// 2. RealityKitContent package bundle (direct lookup, if available)
/// 3. Recursive search in both bundles to handle folder references
/// Logs where the resource was found or that it was missing.
public func urlForDemoPage(named name: String, ext: String = "txt") -> URL? {
    if let url = Bundle.main.url(forResource: name, withExtension: ext) {
        print("[DemoResources] Found \(name).\(ext) in Bundle.main: \(url.lastPathComponent)")
        return url
    }
    #if canImport(RealityKitContent)
    if let url = realityKitContentBundle.url(forResource: name, withExtension: ext) {
        print("[DemoResources] Found \(name).\(ext) in RealityKitContent bundle: \(url.lastPathComponent)")
        return url
    }
    #endif
    // Recursive search (handles blue folder references)
    if let url = recursiveSearch(in: Bundle.main, name: name, ext: ext) {
        print("[DemoResources] Found (recursive) \(name).\(ext) in Bundle.main at: \(url.path)")
        return url
    }
    #if canImport(RealityKitContent)
    if let url = recursiveSearch(in: realityKitContentBundle, name: name, ext: ext) {
        print("[DemoResources] Found (recursive) \(name).\(ext) in RealityKitContent at: \(url.path)")
        return url
    }
    #endif
    print("[DemoResources] Missing \(name).\(ext) in known bundles")
    return nil
}

/// Logs the presence and paths of demo page files for quick device diagnostics.
public func debugLogDemoResourceStatus(pages: ClosedRange<Int> = 1...3) {
    let names = pages.map { "page\($0)Demo" }
    func listTxt(in bundle: Bundle, label: String) {
        let base = bundle.resourcePath ?? "<nil>"
        let fm = FileManager.default
        var found: [String] = []
        if let enumerator = fm.enumerator(atPath: base) {
            for case let path as String in enumerator {
                if path.lowercased().hasSuffix(".txt") { found.append(path) }
            }
        }
        print("[DemoResources] --- \(label) --- root=\(base)\n\tTXT files: \(found)")
        for n in names {
            let direct = bundle.url(forResource: n, withExtension: "txt") != nil
            let recursive = recursiveSearch(in: bundle, name: n, ext: "txt") != nil
            print("[DemoResources] \(label) lookup \(n).txt direct=\(direct) recursive=\(recursive)")
        }
    }
    listTxt(in: Bundle.main, label: "Bundle.main")
    #if canImport(RealityKitContent)
    listTxt(in: realityKitContentBundle, label: "RealityKitContent")
    #endif
}
