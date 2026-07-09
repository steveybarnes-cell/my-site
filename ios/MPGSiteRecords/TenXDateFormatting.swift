import Foundation

/// Date-formatting helper expected by the 10x-injected `TenXPreviewSupport`
/// runtime-logging template. The generated preview file references
/// `TenXDateFormatting.iso8601`; providing it here keeps that injected code
/// compiling across project regenerations.
enum TenXDateFormatting {
  /// Shared ISO-8601 formatter used for runtime log timestamps.
  static let iso8601 = ISO8601DateFormatter()
}
