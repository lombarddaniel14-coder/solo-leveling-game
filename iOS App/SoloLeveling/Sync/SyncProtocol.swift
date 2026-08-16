import Foundation
import Compression

/// Implements the offline "SLSYNC1" pairing protocol. This MUST stay identical
/// to the desktop bridge (SL Sync Bridge.html) so the two interoperate.
///
/// Payload build (sender):
///   1. body  = UTF-8 bytes of compact save JSON.
///   2. flag  = 'R' (raw) or 'D' (DEFLATE-raw / RFC1951). 'R' is the mandatory,
///              guaranteed-interop default; 'D' is an optional size win with
///              graceful fallback to 'R'.
///   3. b64   = base64(body-or-compressed).
///   4. split b64 into chunks of <= 700 chars. total = number of chunks.
///   5. frame = "SLSYNC1|" + sessionId + "|" + index + "|" + total + "|"
///              + flag + "|" + chunkData   (index 0-based).
///
/// Manual code fallback: the whole b64 with a one-line header
/// "SLSYNC1R:" or "SLSYNC1D:".
public enum SyncProtocol {

    public static let framePrefix = "SLSYNC1"
    public static let manualPrefixRaw = "SLSYNC1R:"
    public static let manualPrefixDeflate = "SLSYNC1D:"
    public static let maxChunk = 700

    // MARK: - Session id

    /// Short random session id, stable for one payload.
    public static func newSessionId() -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    // MARK: - Build (sender)

    public struct BuiltPayload {
        public let frames: [String]  // animated-QR frames
        public let manualCode: String // full header + b64 for copy/paste
        public let flag: Character
        public let sessionId: String
        public let total: Int
    }

    /// Builds frames + manual code from a JSON string. Tries DEFLATE ('D') and
    /// falls back to raw ('R') if compression is unavailable or not smaller.
    public static func build(fromJSON json: String,
                             preferCompression: Bool = true) -> BuiltPayload {
        let bodyData = Data(json.utf8)
        var flag: Character = "R"
        var payloadData = bodyData

        if preferCompression, let deflated = deflateRaw(bodyData),
           deflated.count < bodyData.count {
            flag = "D"
            payloadData = deflated
        }

        let b64 = payloadData.base64EncodedString()
        let sessionId = newSessionId()
        let chunks = splitIntoChunks(b64, size: maxChunk)
        let total = chunks.count

        let frames = chunks.enumerated().map { (idx, chunk) in
            "\(framePrefix)|\(sessionId)|\(idx)|\(total)|\(flag)|\(chunk)"
        }

        let manualPrefix = (flag == "D") ? manualPrefixDeflate : manualPrefixRaw
        let manualCode = manualPrefix + b64

        return BuiltPayload(frames: frames, manualCode: manualCode,
                            flag: flag, sessionId: sessionId, total: total)
    }

    private static func splitIntoChunks(_ s: String, size: Int) -> [String] {
        guard !s.isEmpty else { return [""] }
        var result: [String] = []
        var idx = s.startIndex
        while idx < s.endIndex {
            let end = s.index(idx, offsetBy: size, limitedBy: s.endIndex) ?? s.endIndex
            result.append(String(s[idx..<end]))
            idx = end
        }
        return result
    }

    // MARK: - Parse a single frame (receiver)

    public struct Frame {
        public let sessionId: String
        public let index: Int
        public let total: Int
        public let flag: Character
        public let chunk: String
    }

    /// Parses one scanned QR string into a Frame, or nil if it isn't SLSYNC1.
    public static func parseFrame(_ raw: String) -> Frame? {
        // Split into at most 6 pieces; the chunk itself never contains '|'
        // (base64 alphabet excludes it), so a plain split is safe.
        let parts = raw.split(separator: "|", maxSplits: 5,
                              omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 6, parts[0] == framePrefix else { return nil }
        guard let index = Int(parts[2]), let total = Int(parts[3]),
              let flagChar = parts[4].first else { return nil }
        return Frame(sessionId: parts[1], index: index, total: total,
                     flag: flagChar, chunk: parts[5])
    }

    // MARK: - Reassembler (receiver)

    /// Collects unique frames for a session and reassembles the payload once all
    /// indices are present.
    public final class Reassembler {
        public private(set) var sessionId: String?
        public private(set) var total: Int = 0
        public private(set) var flag: Character = "R"
        private var chunks: [Int: String] = [:]

        public init() {}

        public var collectedCount: Int { chunks.count }

        public var isComplete: Bool {
            total > 0 && chunks.count == total
        }

        /// Feeds one scanned string. Returns true if it was an accepted new
        /// frame for the active session.
        @discardableResult
        public func ingest(_ raw: String) -> Bool {
            guard let frame = parseFrame(raw) else { return false }

            // New session? reset if it differs from the one in progress.
            if sessionId == nil || sessionId != frame.sessionId {
                // Only switch sessions if we haven't finished the current one.
                if !isComplete {
                    sessionId = frame.sessionId
                    total = frame.total
                    flag = frame.flag
                    chunks = [:]
                } else {
                    return false
                }
            }
            guard frame.index >= 0, frame.index < total else { return false }
            let isNew = chunks[frame.index] == nil
            chunks[frame.index] = frame.chunk
            return isNew
        }

        public func reset() {
            sessionId = nil
            total = 0
            flag = "R"
            chunks = [:]
        }

        /// Reassembles the full JSON string once complete. Throws on any decode
        /// or inflate failure.
        public func assembleJSON() throws -> String {
            guard isComplete else {
                throw SyncError.incomplete(collected: chunks.count, total: total)
            }
            let b64 = (0..<total).map { chunks[$0] ?? "" }.joined()
            return try SyncProtocol.decodePayload(b64: b64, flag: flag)
        }
    }

    // MARK: - Manual code decode

    /// Decodes a manually pasted "SLSYNC1R:"/"SLSYNC1D:" code into JSON.
    public static func decodeManualCode(_ code: String) throws -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(manualPrefixDeflate) {
            let b64 = String(trimmed.dropFirst(manualPrefixDeflate.count))
            return try decodePayload(b64: b64, flag: "D")
        } else if trimmed.hasPrefix(manualPrefixRaw) {
            let b64 = String(trimmed.dropFirst(manualPrefixRaw.count))
            return try decodePayload(b64: b64, flag: "R")
        }
        // Tolerate a bare JSON paste (no header).
        if trimmed.hasPrefix("{") {
            return trimmed
        }
        throw SyncError.badHeader
    }

    /// base64-decode → (optionally inflate) → UTF-8 JSON string.
    public static func decodePayload(b64: String, flag: Character) throws -> String {
        guard let data = Data(base64Encoded: b64) else {
            throw SyncError.badBase64
        }
        let jsonData: Data
        if flag == "D" {
            guard let inflated = inflateRaw(data) else {
                throw SyncError.inflateFailed
            }
            jsonData = inflated
        } else {
            jsonData = data
        }
        guard let json = String(data: jsonData, encoding: .utf8) else {
            throw SyncError.badUTF8
        }
        return json
    }

    // MARK: - DEFLATE-raw (RFC1951) via Compression framework

    /// Compresses to raw DEFLATE. Apple's COMPRESSION_ZLIB emits raw DEFLATE
    /// (no zlib header), which matches JS `CompressionStream('deflate-raw')`.
    public static func deflateRaw(_ input: Data) -> Data? {
        perform(input, operation: COMPRESSION_STREAM_ENCODE)
    }

    /// Inflates raw DEFLATE data.
    public static func inflateRaw(_ input: Data) -> Data? {
        perform(input, operation: COMPRESSION_STREAM_DECODE)
    }

    private static func perform(_ input: Data,
                                operation: compression_stream_operation) -> Data? {
        guard !input.isEmpty else { return Data() }

        var stream = compression_stream()
        let status = compression_stream_init(&stream, operation, COMPRESSION_ZLIB)
        guard status == COMPRESSION_STATUS_OK else { return nil }
        defer { compression_stream_destroy(&stream) }

        let bufferSize = 32_768
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }

        var output = Data()

        let result: Data? = input.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) -> Data? in
            guard let baseAddress = rawPtr.baseAddress else { return nil }
            stream.src_ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
            stream.src_size = input.count

            let flags = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)

            repeat {
                stream.dst_ptr = destinationBuffer
                stream.dst_size = bufferSize

                let s = compression_stream_process(&stream, flags)
                switch s {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let produced = bufferSize - stream.dst_size
                    if produced > 0 {
                        output.append(destinationBuffer, count: produced)
                    }
                    if s == COMPRESSION_STATUS_END { return output }
                case COMPRESSION_STATUS_ERROR:
                    return nil
                default:
                    return nil
                }
            } while true
        }
        return result
    }

    // MARK: - Errors

    public enum SyncError: LocalizedError {
        case incomplete(collected: Int, total: Int)
        case badHeader
        case badBase64
        case inflateFailed
        case badUTF8

        public var errorDescription: String? {
            switch self {
            case .incomplete(let c, let t): return "Incomplete: \(c)/\(t) frames."
            case .badHeader: return "Unrecognized code header (expected SLSYNC1R:/SLSYNC1D:)."
            case .badBase64: return "Payload is not valid base64."
            case .inflateFailed: return "Could not decompress the payload."
            case .badUTF8: return "Payload is not valid UTF-8 JSON."
            }
        }
    }
}
