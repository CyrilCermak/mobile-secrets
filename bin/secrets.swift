//
//  Autogenerated file by Fastlane-Plugin-Secret
//

import Foundation

class Secrets {
    static let standard = Secrets()
    private let bytes: [[UInt8]] = [[75, 111, 107, 111, 66, 101, 108, 108, 111, 75, 111, 107, 111],
																	 [103, 111, 111, 103, 108, 101, 77, 97, 112, 115],
																	 [122, 93, 88, 94, 112, 86, 93, 94, 92],
																	 [102, 105, 114, 101, 98, 97, 115, 101],
																	 [42, 28, 15, 14, 49, 1, 13, 31, 11],
																	 [97, 109, 97, 122, 111, 110],
																	 [42, 28, 15, 94, 112, 86, 13, 31, 11, 122, 93, 88],
																	 [102, 97, 99, 101, 98, 111, 111, 107],
																	 [32, 0, 0, 0, 32, 0, 0, 0, 0]]

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