//
//  Autogenerated file by Mobile Secrets
//

import Foundation

class Secrets {
    static let standard = Secrets()
    /* SECRET BYTES */

    private init() {}

    func string(forKey key: String) -> String? {
        guard let index = bytes.firstIndex(where: { String(data: Data($0), encoding: .utf8) == key }),
            let value = decrypt(bytes[index + 1]) else { return nil }
        return String(data: Data(value), encoding: .utf8)
    }

    private func decrypt(_ input: [UInt8]) -> [UInt8]? {
        let key = bytes[0]
        guard !key.isEmpty else { return nil }
        var output = [UInt8]()
        for byte in input.enumerated() {
            output.append(byte.element ^ key[byte.offset % key.count])
        }
        return output
    }
}
