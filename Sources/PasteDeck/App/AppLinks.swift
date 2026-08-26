import Foundation

enum AppLinks {
    static let repository = URL(string: "https://github.com/jeffusion/PasteDeck")!
    static let issues = repository.appendingPathComponent("issues")
}
