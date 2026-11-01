// Checks an update's signature against the public key inside the app, the same way installed copies will.
// Usage: swift scripts/verify-update.swift <public key> <file> <signature>
import CryptoKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 4,
      let publicKey = Data(base64Encoded: arguments[1]),
      let signature = Data(base64Encoded: arguments[3]),
      let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey),
      let file = try? Data(contentsOf: URL(fileURLWithPath: arguments[2])),
      key.isValidSignature(signature, for: file) else { exit(1) }
