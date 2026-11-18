// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacDFUDiagnostics",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "MacDFUDiagnostics", targets: ["MacDFUDiagnostics"]),
        .executable(name: "macdfu-vdm-helper", targets: ["MacDFUVDMHelper"])
    ],
    targets: [
        .target(
            name: "CHPMBridge",
            path: "Sources/CHPMBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .executableTarget(
            name: "MacDFUVDMHelper",
            dependencies: ["CHPMBridge"],
            path: "Sources/MacDFUVDMHelper"
        ),
        .executableTarget(
            name: "MacDFUDiagnostics",
            dependencies: ["CHPMBridge"],
            path: "Sources/MacDFUDiagnostics",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
