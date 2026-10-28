import XCTest
import WebKit

@MainActor
final class URLPolicyFeasibilityTests: XCTestCase, WKNavigationDelegate {
    private var loaded: XCTestExpectation?
    private var decisions = 0

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded?.fulfill()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisions += 1
        decisionHandler(.allow)
    }

    func testIsolatedExplicitLocalCaptureAndSubresourcePolicyGap() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        XCTAssertFalse(configuration.websiteDataStore.isPersistent)
        XCTAssertNil(webView.url)
        XCTAssertEqual(decisions, 0)

        // No sockets or guidebook sites. The custom scheme is a harness-only resource endpoint.
        let handler = ResourceHandler()
        let resourceConfiguration = WKWebViewConfiguration()
        resourceConfiguration.websiteDataStore = .nonPersistent()
        resourceConfiguration.setURLSchemeHandler(handler, forURLScheme: "climbing-notebook-test")
        let preview = WKWebView(frame: .zero, configuration: resourceConfiguration)
        preview.navigationDelegate = self
        let resource = expectation(description: "Image subresource requested")
        handler.requested = resource
        loaded = expectation(description: "Explicit synthetic page load")
        preview.loadHTMLString("""
            <html><body><p>Synthetic climbing notes</p>
            <img src="climbing-notebook-test://fixture/topo.png"></body></html>
            """, baseURL: nil)
        await fulfillment(of: [loaded!, resource], timeout: 15)
        let text = try await preview.evaluateJavaScript("document.body.innerText") as? String
        XCTAssertTrue(text?.contains("Synthetic climbing notes") == true)
        // WKNavigationDelegate did not receive a navigation decision for the image request.
        XCTAssertEqual(handler.requests, 1)
        XCTAssertEqual(decisions, 1)
        preview.stopLoading()
    }
}

private final class ResourceHandler: NSObject, WKURLSchemeHandler {
    var requested: XCTestExpectation?
    var requests = 0

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        requests += 1
        requested?.fulfill()
        let bytes = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=")!
        urlSchemeTask.didReceive(URLResponse(url: urlSchemeTask.request.url!, mimeType: "image/png",
                                            expectedContentLength: bytes.count, textEncodingName: nil))
        urlSchemeTask.didReceive(bytes)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}
