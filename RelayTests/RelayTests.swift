import XCTest
@testable import Relay

/// Tests focus on the deterministic, high-value seams: tools and the registry.
/// These are the units most likely to break silently and the easiest to verify
/// without a live model — exactly where automated tests earn their keep.
final class RelayTests: XCTestCase {

    func testCalculatorEvaluatesExpression() async throws {
        let tool = CalculatorTool()
        let result = try await tool.run(arguments: ["expression": .string("12 * (3 + 4)")])
        XCTAssertEqual(result, "84")
    }

    func testCalculatorHandlesMissingArgument() async throws {
        let tool = CalculatorTool()
        let result = try await tool.run(arguments: [:])
        XCTAssertTrue(result.contains("Error"))
    }

    func testRegistryRoutesByName() async {
        let registry = ToolRegistry(tools: [CalculatorTool()])
        let output = await registry.execute(
            name: "calculator",
            inputJSON: #"{"expression":"2+2"}"#
        )
        XCTAssertEqual(output, "4")
    }

    func testRegistryReportsUnknownToolAsText() async {
        let registry = ToolRegistry(tools: [CalculatorTool()])
        let output = await registry.execute(name: "nonexistent", inputJSON: "{}")
        XCTAssertTrue(output.contains("no tool named"))
    }

    func testDateTimeToolReturnsNonEmpty() async throws {
        let tool = DateTimeTool()
        let result = try await tool.run(arguments: [:])
        XCTAssertFalse(result.isEmpty)
    }
}
