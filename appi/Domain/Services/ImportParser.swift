import Foundation

protocol ImportParser: Sendable {
    func canParse(_ data: Data) -> Bool
    func parse(_ data: Data) throws -> ImportResult
}
