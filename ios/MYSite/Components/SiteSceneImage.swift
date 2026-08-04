import SwiftUI

/// The demo feed's photography.
///
/// This file used to draw its "photos" — six SwiftUI scenes made of paths and
/// rectangles, with Unsplash URLs layered on top and the drawings kept as an
/// offline fallback. Both halves were a problem. The drawings read as clip art
/// next to real branding, and the Unsplash images were stock: a builder can
/// tell within about a second that nobody in the photo has ever met the firm
/// showing it to them.
///
/// These are Steve's own jobs. They ship in the asset catalogue, which means no
/// network call, no loading state, no failure case, and nothing to fall back
/// to — the image is either compiled into the binary or the build is broken.
/// That is why all the `AsyncImage` machinery is gone rather than kept "just in
/// case": there is no case.
enum SiteScene: String, CaseIterable {
  case roofTimbers
  case blockwork
  case brickwork
  case beamLift
  case roofStructure
  case joists
  case timberFrame
  case archFormwork
  case sedumRoof

  /// Maps stored and legacy keys onto a scene.
  ///
  /// Seeded posts are rewritten with the new keys, but a `sceneKey` can also
  /// have been persisted by an older build, so the retired names still resolve
  /// rather than falling through to something arbitrary.
  init(key: String) {
    switch key {
    case "roofTimbers", "scaffold": self = .roofTimbers
    case "blockwork": self = .blockwork
    case "brickwork", "photo.stack": self = .brickwork
    case "beamLift", "digOut", "photo.fill": self = .beamLift
    case "roofStructure": self = .roofStructure
    case "joists": self = .joists
    case "timberFrame", "screed": self = .timberFrame
    case "archFormwork", "hallwayPaint", "photo": self = .archFormwork
    case "sedumRoof", "kitchenFit": self = .sedumRoof
    default: self = .roofTimbers
    }
  }

  /// Asset-catalogue name. Matches the imageset folder exactly.
  var assetName: String {
    switch self {
    case .roofTimbers: return "SiteRoofTimbers"
    case .blockwork: return "SiteBlockwork"
    case .brickwork: return "SiteBrickwork"
    case .beamLift: return "SiteBeamLift"
    case .roofStructure: return "SiteRoofStructure"
    case .joists: return "SiteJoists"
    case .timberFrame: return "SiteTimberFrame"
    case .archFormwork: return "SiteArchFormwork"
    case .sedumRoof: return "SiteSedumRoof"
    }
  }

  /// The watermark burned into the corner, so a demo photo reads like something
  /// captured on site rather than dropped in from a brochure. Sites match the
  /// ones in `SeedData`.
  var stamp: String {
    switch self {
    case .roofTimbers: return "11:40 · CLIFTON"
    case .blockwork: return "08:15 · REDCLIFFE"
    case .brickwork: return "09:32 · CLIFTON"
    case .beamLift: return "07:55 · MARLBOROUGH"
    case .roofStructure: return "13:20 · REDCLIFFE"
    case .joists: return "15:05 · CLIFTON"
    case .timberFrame: return "10:18 · MARLBOROUGH"
    case .archFormwork: return "14:47 · MARLBOROUGH"
    case .sedumRoof: return "16:30 · REDCLIFFE"
    }
  }

  /// Short description, for accessibility and anywhere a caption is wanted.
  var summary: String {
    switch self {
    case .roofTimbers: return "New gable roof timbers against clear sky"
    case .blockwork: return "Blockwork and steels to a rear extension"
    case .brickwork: return "Bricklayer working off the scaffold"
    case .beamLift: return "Steel beam being walked through to the rear"
    case .roofStructure: return "Timber roof structure inside the scaffold"
    case .joists: return "Roof joists hung on galvanised hangers"
    case .timberFrame: return "Oak frame set out ready for lifting"
    case .archFormwork: return "Plywood arch formwork against exposed brick"
    case .sedumRoof: return "Sedum roof with a frameless rooflight"
    }
  }
}

/// A site photograph, plain. Used where the surrounding view supplies its own
/// framing — the demo mode strip, for instance.
///
/// `Color.clear` takes exactly the size the parent proposes and the image is
/// drawn over it. This matters: `.scaledToFill()` reports a layout size larger
/// than the width it was offered, and `.clipped()` clips *drawing*, not layout,
/// so without this the oversized width propagates up and stretches whatever
/// contains it past the screen edge.
struct SiteSceneImage: View {
  let scene: SiteScene

  var body: some View {
    Color.clear
      .overlay {
        Image(scene.assetName)
          .resizable()
          .scaledToFill()
      }
      .clipped()
      .frame(maxWidth: .infinity)
      .accessibilityLabel(scene.summary)
  }
}

/// The same photograph dressed for the feed: a foot gradient so white captions
/// and badges stay legible over a bright sky, and the capture watermark.
struct SitePhotoImage: View {
  let scene: SiteScene

  var body: some View {
    SiteSceneImage(scene: scene)
      .overlay {
        LinearGradient(
          colors: [.black.opacity(0.0), .black.opacity(0.22)],
          startPoint: .center, endPoint: .bottom)
      }
      .overlay(alignment: .bottomLeading) {
        Text(scene.stamp)
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .foregroundStyle(.white.opacity(0.9))
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 4))
          .padding(8)
      }
      .accessibilityLabel(scene.summary)
  }
}

#Preview {
  ScrollView {
    LazyVStack(spacing: 0) {
      ForEach(SiteScene.allCases, id: \.self) { scene in
        SitePhotoImage(scene: scene)
          .aspectRatio(4.0 / 3.0, contentMode: .fit)
      }
    }
  }
}
