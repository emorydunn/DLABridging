// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let version = "0.9.5"

let package = Package(
    name: "DLABridging",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "DLABridging",
            targets: ["DLABridging"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
		.binaryTarget(name: "DLABridging",
					  url: "https://storage.emory.coffee/lost-cause-photo/DLABridging/\(version)/DLABridging.xcframework.zip",
					  checksum: "4ebc36f21a9ed0911905546124d380ef17fb02e02fea4de3c71775e3d8254bb7")
    ]
)
