# Colophon

A native macOS ebook cover designer. You bring a title, a genre, and optionally some photos, paintings or sketches. Colophon designs a set of finished covers, checks them against store requirements, and exports a file for each storefront.

It's built for people with ideas but no formal design training. The guardrails (golden-section layout, color theory, contrast checks and automatic legibility fixes) keep the output looking like a professional designed it.

## What it does

**Design from a brief.** Enter the title, author and genre, then drop in pictures, or skip them. Colophon generates 8 to 48 complete covers in one batch. They span 15 composition types, including full bleed, title behind the subject, arch window, medallion, golden split, depth cutout, duotone poster, cinematic, two-piece collage, golden grid and pure typography. Each one pairs genre-appropriate typefaces with a palette pulled from your photo, its complementary twist, or a genre mood.

**Text behind the subject.** Vision finds the subject in your photo. One toggle slides the title behind it, magazine style. *Lift Subject* copies the subject onto its own layer so you can blur the background, add depth, or set shapes behind it.

**Cut pieces.** Any image can be cut into a circle, arch, diamond, hexagon or rounded rectangle. Zoom and focus pick which part shows. One photo can become several pieces.

**2,000+ effects.** The library holds more than 2,000 presets in 11 families. Duotones, gradient maps, split-tone grades, film and tone, blur and motion smears, color washes, light leaks, atmosphere, print and halftone, paint and art, and signature looks. Each one previews live on your layer, stacks with others and has its own strength slider.

**Color that makes sense.** The palette is extracted from your photo (k-means in perceptual space). The harmony explorer covers complementary, split, analogous, triadic, tetradic and monochromatic schemes. You also get shades and tints, an "opposite color" picker tuned for type, and a live WCAG contrast readout for the title.

**Blending and smearing.** Pick two colors, then choose Gradient Wash, Mesh Blend, Paint Smear, Watercolor, Smoke or Light Glow. Each lands between your artwork and your type, with a blend mode that mixes rather than covers. There are 17 procedural grounds in all, including Bauhaus shapes, golden blocks, starfield, bokeh, marble, sunburst and halftone, so you can build covers with no photo at all.

**Ideas panel.** Suggestions react to the current cover. For example: "the area behind the title is busy, calm it with a scrim", "tuck the title behind the subject", "use the opposite color", "snap the title to the golden line", "duotone the photo in your palette", "unify with film grain" and "track out the author name". Each one is a single click and a single undo.

**Auto-Polish.** Renders what's actually behind every line of type and fixes the type color, adds shadows, or inserts a soft scrim until it reads.

**Golden ratio throughout.** Layouts sit on golden-section lines. Dragging snaps to golden, thirds, center and margin lines. Guides switch between golden section, thirds, golden spiral and safe area.

**Preflight for stores.** Checks proportions and resolution for Kindle, Google Play Books, Apple Books, Kobo, Barnes & Noble Press, Draft2Digital and IngramSpark. It also checks the contrast of every text line, busy backgrounds, the safe area, and title size in a 160 px search thumbnail. Further checks cover typeface count, light edges that vanish on white store pages, and type covering the focal point. Most issues have a one-click fix.

**Export.** One sRGB JPEG, PNG or TIFF per store at its recommended size, rendered from the full-resolution sources. The layout is stored in normalized coordinates, so a design re-flows to each store's proportions.

**Type finishes.** Gold, silver, rose gold and copper foils, neon, distressed, worn print and chalk. Any line of type can arch up or sag down. The Ideas panel suggests the finish that suits your genre.

**Refine the cutout.** Erase and Restore brushes fix the automatic subject edge, or erase parts of any picture.

**More Like This.** Gives 11 takes on the cover you're editing. Each keeps your layout and edits and explores a new type treatment, palette, opposite accent, photo look, crop or flipped layout.

**Paperback wraparound.**
- **Settings:** choose a trim size (5x8 to 8.5x11), page count and paper; the spine width follows from KDP's per-page thickness.
- **Back cover:** your art continues around from the front, with a pull quote, a blurb (warns if it runs long) and a clear barcode area.
- **Spine:** title and author, from 80 pages up.
- **Output:** a print-ready PDF at 300 DPI with 0.125 in bleed.

**Marketing and ads.**
- **Mockups:** a 3D book (using your real printed spine), phone, tablet, a book-and-phone scene, a social post and a square cover.
- **Ad sizes:** Facebook feed, Instagram/TikTok story, X/Bluesky, Pinterest, BookBub and an Amazon A+ banner. Each lays out the 3D book with your headline and a call-to-action button.

**Series covers.** Type the titles and get matching covers for every book, plus a lineup image.

**Compare.**
- **Side by side:** see your cover next to hearted ideas and real bestsellers you import.
- **Store sizes:** search-result, also-bought and product-page sizes.
- **Checks:** grayscale (e-ink), squint (blur) and dark-page views.

**Material library.** 2,600+ procedural materials, all generated in-app with no stock files.
- **Structures:** 48 families, including marble, granite, terrazzo, wood grain, planks, crumpled paper, linen, denim, leather, watercolor, ink wash, paint pour, grunge, scratches, rust, burned edges, clouds, nebula, aurora, frost, brushed metal, hammered metal, and geometric patterns.
- **Colorways:** 26, among them gold, copper, slate, sage, ocean, midnight and ember. A Cover Palette colorway prints the material in your cover's own colors.
- **Scales:** each material comes in fine and bold.
- **Masks:** every structure is also available as a soft, hard or inverted gray mask.
- **Where to use them:** Add → Material Background…, a Painted Ground's Material style, the title's Fine-Tune Style → Material → Library, and a layer's Mask → Texture, which wears the layer through grunge, paper or brush.

**Everyday polish.**
- **Fonts:** import your own; they're embedded in the project.
- **Editing:** eyedropper, copy/paste text style, align buttons, and photo adjustments (exposure, contrast, saturation, warmth, sharpness, blur).
- **Files:** recent files, and autosave every 45 seconds with crash recovery.
- **App:** light, dark or system appearance, and a keyboard shortcut sheet (Command-/).

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later (to build)

## Build and run

```bash
cd Colophon
swift run                     # quick launch for development
scripts/make-app.sh           # builds build/Colophon.app with icon and file types
open build/Colophon.app
```

Or open `Colophon/Package.swift` in Xcode and press Run.

To ship a signed and notarized build, add these repository secrets. The workflow then signs with your Developer ID and notarizes automatically:
- `MACOS_CERT_P12`: a base64 Developer ID Application certificate
- `MACOS_CERT_PASSWORD`
- `MACOS_SIGN_IDENTITY`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_PASSWORD`: an app-specific password

Every push that touches `Colophon/` also runs the GitHub Actions workflow in `.github/workflows/colophon-macos.yml`. It builds and tests on macOS and uploads a zipped `Colophon.app` as an artifact. The app is ad-hoc signed, so on first launch you need to right-click it and choose Open.

## Using it

1. **Brief.** Enter the title and author, pick a genre, and drop in pictures. Optionally pick a color mood or your own colors.
2. **Design Covers.** Browse the grid. Hover a cover and choose *More with this layout* to explore one composition.
3. **Edit This.** Refine on the canvas. Click to select, drag to move, pull handles to resize, use arrow keys to nudge (Shift for bigger steps). The inspector tabs are:
   - **Layer:** text, typeface, case, tracking, gradient, outline, glow, behind-subject, blending, edges, cut-into-shape and shadow
   - **Effects:** search and apply from the library
   - **Color:** palette, harmony, shades, and two-color blends
   - **Ideas:** contextual suggestions and Auto-Polish
   - **Check:** store preflight and the thumbnail test
   - **Book:** brief, canvas and pictures
4. **Export** (Command-E). Pick the stores and a folder.

Projects save as `.colophon` files (JSON with embedded images).

## Project layout

```
Sources/Colophon/
  App/      App entry, menus, EditorModel (state, undo, rendering, files)
  Model/    CoverDocument, layers, RGBA color science, geometry
  Engine/   Renderer, effects library, generators, typography, Vision,
            composer (archetypes and genre styles), polisher, suggestions, preflight
  UI/       Start, variations, editor, canvas, inspectors, export
Tests/      Color science, effects, typography, rendering, composer, preflight
```

## Notes

Store size guidance changes from time to time. The specs in `Engine/Preflight.swift` reflect each store's published recommendations when this was written; check the store's current help page before a launch. Fonts are the ones that ship with macOS. *All installed* in the font picker also lists any fonts you've added.
