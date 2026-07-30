import Foundation

enum MathOperation: String, Decodable {
    case add, subtract, multiply, divide

    var symbol: String {
        switch self {
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "*"
        case .divide: return "/"
        }
    }
}

// The backend sends operands + operation rather than a rendered question plus a
// separate answer key (see PublicMathProblem in the backend's schemas.py) — `answer`
// and `question` below are computed locally from the same two numbers, so instant
// on-device checking keeps working with nothing meaningfully hidden or exposed beyond
// what's needed to render the problem in the first place.
struct MathProblem: Decodable {
    let leftOperand: Int
    let rightOperand: Int
    let operation: MathOperation

    var answer: Int {
        switch operation {
        case .add: return leftOperand + rightOperand
        case .subtract: return leftOperand - rightOperand
        case .multiply: return leftOperand * rightOperand
        case .divide: return rightOperand != 0 ? leftOperand / rightOperand : 0
        }
    }

    var question: String {
        "\(leftOperand) \(operation.symbol) \(rightOperand)"
    }
}
