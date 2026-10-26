import XCTest
import SwiftUI
@testable import Blipz

/// Opt-in hosted-window diagnostic, not a normal app lifecycle test. Xcode 26.0.1 /
/// iOS 26 can abort in isolated deinit during this XCTest window's teardown; the
/// normal SwiftUI cover flow is verified separately. See docs/V1_VERIFICATION.md.
/// Never supplies mock production data or creates a live test user.
final class DailyRevealLiveVerificationTests: XCTestCase {
    @MainActor
    func testIncompleteDailyRevealGateAndScreenshot() async throws {
        guard ProcessInfo.processInfo.environment["BLIPZ_LIVE_WINDOW_DIAGNOSTIC"] == "1" else {
            throw XCTSkip("Known hosted-window runtime limitation; enable BLIPZ_LIVE_WINDOW_DIAGNOSTIC explicitly to investigate")
        }
        guard Config.apiBaseURL.host == "127.0.0.1" else {
            throw XCTSkip("Live visual checks are local Debug only")
        }
        var request = URLRequest(url: Config.apiBaseURL.appendingPathComponent("health"))
        request.timeoutInterval = 3
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw XCTSkip("Local backend is unavailable")
        }
        guard (try? await AuthManager.shared.currentAccessToken()) != nil else {
            throw XCTSkip("An existing signed simulator session is required; this diagnostic does not create users")
        }
        let profile: UserProfile = try await APIClient.shared.get("users/me")
        guard !profile.dailyGamesComplete else {
            throw XCTSkip("Actual day is complete; incomplete-gate check is inapplicable")
        }
        let context = DailyRevealContext(profile: profile, date: BlipzDay.key())
        let model = DailyRevealViewModel()
        await model.load(for: context)
        XCTAssertNil(model.profile)
        XCTAssertNil(model.review)
        XCTAssertNil(model.imageURL)
        XCTAssertNil(model.globalRank)
        XCTAssertEqual(model.errorMessage, "Finish all three games to open your Daily Reveal.")

        let coordinator = DailyRevealCoordinator()
        coordinator.show(profile: profile)
        XCTAssertNil(coordinator.presentation)

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: DailyRevealView(context: context, viewModel: model))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousWindow?.makeKey() }
        try await Task.sleep(for: .milliseconds(800))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Live Daily Reveal incomplete gate — not a completed-result screenshot"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
