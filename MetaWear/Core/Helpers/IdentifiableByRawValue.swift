//  © 2021 Ryan Ferrell. github.com/importRyan


import Foundation

public protocol IdentifiableByRawValue: RawRepresentable, Identifiable {
    var id: RawValue { get }
}

public extension IdentifiableByRawValue {
     var id: RawValue { rawValue }
}
