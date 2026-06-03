import Foundation

/// Evaluates an arithmetic expression. A clean example of a deterministic tool:
/// the model is bad at exact math, so it delegates instead of hallucinating.
struct CalculatorTool: AgentTool {
    let name = "calculator"
    let description = "Evaluate a basic arithmetic expression, e.g. '12 * (3 + 4)'."
    var inputSchema: JSONSchema {
        JSONSchema(
            properties: [
                "expression": .init(
                    type: "string",
                    description: "The arithmetic expression to evaluate."
                )
            ],
            required: ["expression"]
        )
    }

    func run(arguments: [String: JSONValue]) async throws -> String {
        guard let expr = arguments["expression"]?.stringValue else {
            return "Error: missing 'expression'."
        }
        // NSExpression handles +, -, *, /, and parentheses safely.
        let sanitized = expr.replacingOccurrences(of: "×", with: "*")
                            .replacingOccurrences(of: "÷", with: "/")
        let expression = NSExpression(format: sanitized)
        guard let value = expression.expressionValue(with: nil, context: nil) as? NSNumber else {
            return "Error: couldn't evaluate '\(expr)'."
        }
        return value.stringValue
    }
}
