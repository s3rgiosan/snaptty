// snaptty agent: puts new screenshots on the clipboard as file paths, so Cmd+V
// in a terminal pastes the path. The PNG data rides along on the same
// clipboard entry for apps that paste images.
//
// Two sources:
// - Spotlight: files macOS tags as screen captures (kMDItemIsScreenCapture),
//   wherever they are saved.
// - The clipboard: image-only content (the Ctrl screenshot shortcuts, images
//   copied in Preview, ...) is saved to the cache folder and its path is added.
//   Clipboards that already carry text, a URL or a file reference are left alone.
//
// Usage: snaptty-agent <cache-dir> [--no-clipboard]
import AppKit

let arguments = CommandLine.arguments.dropFirst()
let cacheDir = URL(fileURLWithPath: arguments.first ?? NSTemporaryDirectory())
let watchClipboard = !arguments.contains("--no-clipboard")

let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60
let textTypes: Set<NSPasteboard.PasteboardType> = [.string, .fileURL, .URL, .html, .rtf]
let shellSpecial = Set(" \\'\"()&;<>|*?$`!#{}[]~")

let pasteboard = NSPasteboard.general
var lastChangeCount = pasteboard.changeCount
var handledPaths = Set<String>()

let fileFormatter = DateFormatter()
fileFormatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
let logFormatter = DateFormatter()
logFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

setvbuf(stdout, nil, _IOLBF, 0)

func log(_ message: String) {
  print("\(logFormatter.string(from: Date())) \(message)")
}

// Backslash-escape shell-special characters, the same form a terminal
// produces when a file is dropped onto it.
func escapePath(_ path: String) -> String {
  var escaped = ""
  for character in path {
    if shellSpecial.contains(character) {
      escaped.append("\\")
    }
    escaped.append(character)
  }
  return escaped
}

func setClipboard(png: Data?, text: String) {
  pasteboard.clearContents()
  if let png = png {
    pasteboard.setData(png, forType: .png)
  }
  pasteboard.setString(text, forType: .string)
  lastChangeCount = pasteboard.changeCount
}

// MARK: - Screenshot files

func handleScreenshot(at path: String) {
  let name = (path as NSString).lastPathComponent
  guard !name.hasPrefix("."), !handledPaths.contains(path) else { return }
  guard FileManager.default.fileExists(atPath: path) else { return }
  handledPaths.insert(path)

  // Reading a file in a protected folder (Desktop, Documents, Downloads)
  // asks for access once; without it the path alone is copied.
  let png = path.lowercased().hasSuffix(".png")
    ? try? Data(contentsOf: URL(fileURLWithPath: path))
    : nil
  setClipboard(png: png, text: escapePath(path))
  log("copied \(path)\(png == nil ? " (path only)" : "")")
}

// Spotlight leaves out files in protected folders (Desktop, Documents,
// Downloads) until the agent has access to them. Listing the screenshot save
// folder once at startup asks for that access.
let saveFolder = UserDefaults(suiteName: "com.apple.screencapture")?
  .string(forKey: "location")
  .map { ($0 as NSString).expandingTildeInPath }
  ?? (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")
if (try? FileManager.default.contentsOfDirectory(atPath: saveFolder)) == nil {
  log("no access to \(saveFolder); screenshots saved there are not detected")
}

let query = NSMetadataQuery()
query.predicate = NSPredicate(
  format: "kMDItemIsScreenCapture == 1 AND kMDItemFSCreationDate >= %@",
  Date() as NSDate)
query.searchScopes = [NSMetadataQueryLocalComputerScope]

NotificationCenter.default.addObserver(
  forName: .NSMetadataQueryDidUpdate, object: query, queue: .main
) { notification in
  let added = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
  let changed = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] ?? []
  let newest = (added + changed)
    .compactMap { item -> (String, Date)? in
      guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { return nil }
      let created = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? .distantPast
      return (path, created)
    }
    .filter { !handledPaths.contains($0.0) }
    .max { $0.1 < $1.1 }
  if let (path, _) = newest {
    handleScreenshot(at: path)
  }
}

query.start()

// MARK: - Clipboard images

func clipboardPNG() -> Data? {
  if let png = pasteboard.data(forType: .png) {
    return png
  }
  guard let tiff = pasteboard.data(forType: .tiff),
        let bitmap = NSBitmapImageRep(data: tiff) else {
    return nil
  }
  return bitmap.representation(using: .png, properties: [:])
}

func pruneCache() {
  let files = (try? FileManager.default.contentsOfDirectory(
    at: cacheDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
  for file in files where file.pathExtension == "png" {
    let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
      .contentModificationDate ?? Date()
    if Date().timeIntervalSince(modified) > maxCacheAge {
      try? FileManager.default.removeItem(at: file)
    }
  }
}

func handleClipboardChange() {
  let types = Set(pasteboard.types ?? [])
  guard types.contains(.png) || types.contains(.tiff) else { return }
  guard types.isDisjoint(with: textTypes) else { return }
  guard let png = clipboardPNG() else { return }

  try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
  let file = cacheDir.appendingPathComponent("clipboard-\(fileFormatter.string(from: Date())).png")
  guard (try? png.write(to: file)) != nil else { return }

  setClipboard(png: png, text: escapePath(file.path))
  log("copied \(file.path)")
  pruneCache()
}

if watchClipboard {
  Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
    guard pasteboard.changeCount != lastChangeCount else { return }
    lastChangeCount = pasteboard.changeCount
    handleClipboardChange()
  }
}

log("watching screenshots\(watchClipboard ? " and the clipboard" : "")")
RunLoop.main.run()
