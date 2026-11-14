// swift-tools-version: 6.0
import PackageDescription
import Foundation

// Only headers come from Homebrew; both architectures link macOS system liblzma.
let xzInclude = ProcessInfo.processInfo.environment["INKY_XZ_INCLUDE"]
    ?? ["/opt/homebrew/opt/xz/include", "/usr/local/opt/xz/include"].first {
        FileManager.default.fileExists(atPath: "\($0)/lzma.h")
    }
    ?? "/opt/homebrew/opt/xz/include"

let package = Package(
    name: "inkyImager",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "inkyImager", targets: ["inkyImager"]),
        .executable(name: "inkyImagerHelper", targets: ["inkyImagerHelper"]),
        .executable(name: "inkyMaintenance", targets: ["inkyMaintenance"]),
    ],
    targets: [
        .target(name: "CAuthOpen", publicHeadersPath: "include"),
        .target(name: "CXZ", publicHeadersPath: "include",
                cSettings: [.unsafeFlags(["-I", xzInclude])],
                linkerSettings: [.linkedLibrary("lzma")]),
        .target(name: "ImagerCore", dependencies: ["CXZ", "CAuthOpen"],
                linkerSettings: [.linkedFramework("IOKit")]),
        .executableTarget(name: "inkyImager", dependencies: ["ImagerCore"]),
        .executableTarget(name: "inkyImagerHelper", dependencies: ["ImagerCore"]),
        .executableTarget(name: "inkyMaintenance", dependencies: ["ImagerCore"]),
        .testTarget(name: "ImagerCoreTests", dependencies: ["ImagerCore", "CAuthOpen"]),
    ],
    swiftLanguageModes: [.v5]
)
