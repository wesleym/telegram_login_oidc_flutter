// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "telegram_login_oidc_flutter",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "telegram-login-oidc-flutter", targets: ["telegram_login_oidc_flutter"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/TelegramMessenger/telegram-login-ios", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "telegram_login_oidc_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "TelegramLogin", package: "telegram-login-ios"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
