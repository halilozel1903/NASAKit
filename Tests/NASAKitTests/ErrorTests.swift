import Foundation
import Testing
@testable import NASAKit

@Suite("Errors and rate limits")
struct ErrorTests {
    @Test func rateLimitHeadersAreSurfaced() async throws {
        let stub = StubbedClient { _ in try .json("apod-image", headers: rateLimitHeaders(limit: 30, remaining: 27)) }
        #expect(stub.client.lastRateLimit == nil)

        _ = try await stub.client.apod()

        let limit = try #require(stub.client.lastRateLimit)
        #expect(limit.limit == 30)
        #expect(limit.remaining == 27)
        #expect(limit.isExhausted == false)
        #expect(limit.description == "27 of 30 requests left")
    }

    @Test func overRateLimit() async throws {
        let body = #"{"error":{"code":"OVER_RATE_LIMIT","message":"You have exceeded your rate limit. Try again later or contact us at https://api.nasa.gov:443/contact/ for assistance"}}"#
        let stub = StubbedClient { _ in .status(429, body: body, headers: rateLimitHeaders(limit: 30, remaining: 0)) }

        await #expect(throws: NASAError.rateLimited(NASARateLimit(limit: 30, remaining: 0))) {
            _ = try await stub.client.apod()
        }
        #expect(stub.client.lastRateLimit?.isExhausted == true)
    }

    @Test func invalidKey() async throws {
        let body = #"{"error":{"code":"API_KEY_INVALID","message":"An invalid api_key was supplied. Get one at https://api.nasa.gov:443"}}"#
        let stub = StubbedClient { _ in .status(403, body: body) }

        do {
            _ = try await stub.client.neo(id: "2000433")
            Issue.record("Expected an error")
        } catch let error as NASAError {
            guard case let .apiKeyRejected(code, message) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(code == "API_KEY_INVALID")
            #expect(message?.hasPrefix("An invalid api_key was supplied") == true)
        }
    }

    @Test func apodBadRequestKeepsTheServersMessage() async throws {
        let body = #"{"code":400,"msg":"Date must be between Jun 16, 1995 and Oct 13, 2026.","service_version":"v1"}"#
        let stub = StubbedClient { _ in .status(400, body: body) }

        await #expect(throws: NASAError.badRequest(message: "Date must be between Jun 16, 1995 and Oct 13, 2026.")) {
            _ = try await stub.client.apod(date: CalendarDate(year: 2030, month: 1, day: 1))
        }
    }

    @Test func neoNotFound() async throws {
        let body = #"{"code":404,"http_error":"NOT_FOUND","error_message":"Asteroid not found"}"#
        let stub = StubbedClient { _ in .status(404, body: body) }

        do {
            _ = try await stub.client.neo(id: "1")
            Issue.record("Expected an error")
        } catch let error as NASAError {
            guard case let .notFound(url) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(url.path == "/neo/rest/v1/neo/1")
        }
    }

    @Test func libraryErrorReason() async throws {
        let body = #"{"reason":"Invalid page_size: must be a positive integer."}"#
        let stub = StubbedClient { _ in .status(400, body: body) }

        await #expect(throws: NASAError.badRequest(message: "Invalid page_size: must be a positive integer.")) {
            _ = try await stub.client.searchMedia("nebula")
        }
    }

    @Test func serverErrorWithoutBody() async throws {
        let stub = StubbedClient { _ in .status(503) }

        await #expect(throws: NASAError.http(statusCode: 503, message: nil)) {
            _ = try await stub.client.epicImages()
        }
    }

    @Test func transportError() async throws {
        let stub = StubbedClient { _ in throw URLError(.badServerResponse) }

        do {
            _ = try await stub.client.searchMedia("apollo")
            Issue.record("Expected an error")
        } catch let error as NASAError {
            guard case let .transport(urlError) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(urlError.code == .badServerResponse)
        }
    }

    @Test func decodingErrorNamesTheType() async throws {
        let stub = StubbedClient { _ in StubResponse(status: 200, headers: [:], body: Data(#"{"title":"No date"}"#.utf8)) }

        do {
            _ = try await stub.client.apod()
            Issue.record("Expected an error")
        } catch let error as NASAError {
            guard case let .decoding(type, description) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(type == "APODEntry")
            #expect(description.contains("date"))
        }
    }

    @Test func keylessHostsDoNotChangeTheRateLimit() async throws {
        let stub = StubbedClient { request in
            if request.url?.host?.hasPrefix("api.") == true {
                return try .json("apod-image", headers: rateLimitHeaders(limit: 1000, remaining: 998))
            }
            // A keyless host that happens to send the header is ignored.
            return try .json("media-search", headers: rateLimitHeaders(limit: 5, remaining: 1))
        }

        _ = try await stub.client.apod()
        _ = try await stub.client.searchMedia("nebula")

        #expect(stub.client.lastRateLimit == NASARateLimit(limit: 1000, remaining: 998))
    }

    @Test func rateLimitFromHeaders() throws {
        let url = try #require(URL(string: "https://api.nasa.gov/planetary/apod"))
        let lowercase = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["x-ratelimit-limit": "1000", "x-ratelimit-remaining": "999"]
        ))
        #expect(NASARateLimit(response: lowercase) == NASARateLimit(limit: 1000, remaining: 999))

        let none = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [:]))
        #expect(NASARateLimit(response: none) == nil)
    }

    @Test func errorsDescribeThemselves() {
        let rateLimited = NASAError.rateLimited(NASARateLimit(limit: 30, remaining: 0))
        #expect(rateLimited.errorDescription?.contains("30") == true)
        let argument = NASAError.invalidArgument("Pages start at 1.")
        #expect(argument.errorDescription == "Pages start at 1.")
    }
}
