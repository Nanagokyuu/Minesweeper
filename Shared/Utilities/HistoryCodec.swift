//
//  HistoryCodec.swift
//  Minesweeper
//
//  On-disk / iCloud-Key-Value-Store envelope for the Rust history JSON.
//
//  A full 50-record hell history is ~2 MB of JSON (each record stores every
//  move for replay), which exceeds the 1 MB NSUbiquitousKeyValueStore quota.
//  The move list is highly repetitive, so zlib brings it down to roughly
//  240 KB.  The "MSH1" magic keeps the format self-describing and lets old
//  uncompressed payloads keep working.
//

import Foundation

enum HistoryCodec {
    /// Leave headroom below the 1 MB per-app KVS total quota.
    static let maxCloudPayloadBytes = 900 * 1024

    private static let magic = Data([0x4D, 0x53, 0x48, 0x31]) // "MSH1"

    /// Returns the bytes to persist.  Small payloads stay raw JSON; large ones
    /// are zlib-compressed behind the magic header.
    static func encode(_ json: Data) -> Data? {
        guard !json.isEmpty else { return Data() }
        // Small histories (the common case) stay raw; compressing a few KB is
        // not worth the CPU on the main thread.
        guard json.count >= 16 * 1024 else { return json }

        do {
            let compressed = try (json as NSData).compressed(using: .zlib) as Data
            guard compressed.count + magic.count < json.count else { return json }

            var payload = magic
            payload.append(compressed)
            return payload
        } catch {
            return nil
        }
    }

    /// Accepts both the compressed envelope and legacy raw JSON.
    static func decode(_ payload: Data) -> Data? {
        guard !payload.isEmpty else { return Data() }
        guard payload.starts(with: magic) else { return payload }

        let body = payload.subdata(in: magic.count..<payload.count)
        do {
            return try (body as NSData).decompressed(using: .zlib) as Data
        } catch {
            return nil
        }
    }
}
