@preconcurrency import Foundation

/// Canonical MessagePack encoder for Algorand transactions
/// Ensures alphabetically sorted keys as required by Algorand protocol
public struct MessagePackWriter {
    private var data = Data()

    public init() {}

    /// Encodes a dictionary with canonical key ordering
    /// - Throws: `AlgorandError.encodingError` if the map is too large
    public mutating func write(map: [String: MessagePackValue]) throws -> Data {
        // Sort keys alphabetically (canonical ordering)
        let sortedKeys = map.keys.sorted()

        // Write map header
        let count = sortedKeys.count
        if count <= 15 {
            data.append(0x80 + UInt8(count)) // fixmap
        } else if count <= 0xFFFF {
            data.append(0xDE) // map16
            data.append(UInt8((count >> 8) & 0xFF))
            data.append(UInt8(count & 0xFF))
        } else {
            throw AlgorandError.encodingError("Map too large: \(count) entries exceeds maximum of 65535")
        }

        // Write key-value pairs in alphabetical order
        for key in sortedKeys {
            guard let value = map[key] else { continue }
            writeString(key)
            try writeValue(value)
        }

        return data
    }

    private mutating func writeValue(_ value: MessagePackValue) throws {
        switch value {
        case .uint(let val):
            writeUInt(val)
        case .string(let val):
            writeString(val)
        case .binary(let val):
            writeBinary(val)
        case .map(let val):
            var writer = MessagePackWriter()
            data.append(try writer.write(map: val))
        case .array(let val):
            try writeArray(val)
        case .bool(let val):
            writeBool(val)
        }
    }

    private mutating func writeBool(_ value: Bool) {
        if value {
            data.append(0xC3) // true
        } else {
            data.append(0xC2) // false
        }
    }

    private mutating func writeUInt(_ value: UInt64) {
        if value <= 0x7F {
            data.append(UInt8(value)) // positive fixint
        } else if value <= 0xFF {
            data.append(0xCC) // uint8
            data.append(UInt8(value))
        } else if value <= 0xFFFF {
            data.append(0xCD) // uint16
            data.append(UInt8((value >> 8) & 0xFF))
            data.append(UInt8(value & 0xFF))
        } else if value <= 0xFFFFFFFF {
            data.append(0xCE) // uint32
            data.append(contentsOf: withUnsafeBytes(of: UInt32(value).bigEndian) { Data($0) })
        } else {
            data.append(0xCF) // uint64
            data.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Data($0) })
        }
    }

    private mutating func writeString(_ value: String) {
        let utf8 = Data(value.utf8)
        let count = utf8.count

        if count <= 31 {
            data.append(0xA0 + UInt8(count)) // fixstr
        } else if count <= 0xFF {
            data.append(0xD9) // str8
            data.append(UInt8(count))
        } else if count <= 0xFFFF {
            data.append(0xDA) // str16
            data.append(UInt8((count >> 8) & 0xFF))
            data.append(UInt8(count & 0xFF))
        } else {
            data.append(0xDB) // str32
            data.append(contentsOf: withUnsafeBytes(of: UInt32(count).bigEndian) { Data($0) })
        }

        data.append(utf8)
    }

    private mutating func writeBinary(_ value: Data) {
        let count = value.count

        if count <= 0xFF {
            data.append(0xC4) // bin8
            data.append(UInt8(count))
        } else if count <= 0xFFFF {
            data.append(0xC5) // bin16
            data.append(UInt8((count >> 8) & 0xFF))
            data.append(UInt8(count & 0xFF))
        } else {
            data.append(0xC6) // bin32
            data.append(contentsOf: withUnsafeBytes(of: UInt32(count).bigEndian) { Data($0) })
        }

        data.append(value)
    }

    private mutating func writeArray(_ value: [MessagePackValue]) throws {
        let count = value.count

        if count <= 15 {
            data.append(0x90 + UInt8(count)) // fixarray
        } else if count <= 0xFFFF {
            data.append(0xDC) // array16
            data.append(UInt8((count >> 8) & 0xFF))
            data.append(UInt8(count & 0xFF))
        } else {
            data.append(0xDD) // array32
            data.append(contentsOf: withUnsafeBytes(of: UInt32(count).bigEndian) { Data($0) })
        }

        for element in value {
            try writeValue(element)
        }
    }
}

/// MessagePack value types
public enum MessagePackValue {
    case uint(UInt64)
    case string(String)
    case binary(Data)
    case map([String: MessagePackValue])
    case array([MessagePackValue])
    case bool(Bool)
}
