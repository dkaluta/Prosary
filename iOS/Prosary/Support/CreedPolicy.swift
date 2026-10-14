import Foundation

/// Authored content owns this policy. An untagged imported recension remains untouched.
struct CreedPolicy: Decodable, Equatable {
  enum Filioque: String, Decodable { case absent, bracketed, unbracketed }
  let apostlesCreed: Bool
  let filioque: Filioque
}
