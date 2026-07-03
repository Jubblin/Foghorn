import XCTest
@testable import Online

class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class HTTPProbeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        HTTPProbe.injectSessionForTesting(URLSession(configuration: config))
    }

    override func tearDown() {
        HTTPProbe.injectSessionForTesting(nil)
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testSuccessfulHeadRequest() async {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let result = await HTTPProbe.probe(urlString: "https://example.com", kind: .httpPrimary)
        XCTAssertTrue(result.success)
    }

    func testServerErrorMarksFailure() async {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let result = await HTTPProbe.probe(urlString: "https://example.com", kind: .httpPrimary)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.detail, "HTTP 503")
    }
}
