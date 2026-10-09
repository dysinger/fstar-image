# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Renamed the three C leaves `Data.Image.Low` → `Data.Image.Pulse`,
  `Data.Image.PNG.Low` → `Data.Image.PNG.Pulse`,
  `Data.Image.QRCode.Low` → `Data.Image.QRCode.Pulse` (the KaRaMeL `.Low`
  convention is retired; the Pulse/Custard layer is the successor).
- Ported the leaves from KaRaMeL Low\* (`Stack` + `LowStar.Buffer`) to Pulse
  (`fn` + `Pulse.Lib.Array`), 0-admit, extracting to C11 via Custard.
- Rolled F\* forward to `v2026.09.20+lsp` (first stable tag shipping the
  Custard extractor).
- Removed the KaRaMeL/Low\* toolchain and all its targets (`krml`, `native`,
  `rust`, `wasm`) — F\* `v2026.09.20` deleted the `FStar.HyperStack` /
  `LowStar.Buffer` stdlib.
- Wired the ISO 18004 §8.8 penalty-minimizing `select_best_mask` into
  `encode_qr_uri` (replacing the forced mask 0).
- Added independent RFC known-answer vectors: a 256-entry reflected CRC-32
  table (cross-model agreement), the Adler-32 RFC-1950 check value, ISO 15948
  §9.2 Average/Paeth concrete vectors, nonzero-ECL `format_info` vectors, and
  ISO 18004 Table 7 capacity cells.

### Source drift fixes

- Removed `open FStar.Mul` and `Prims.op_Multiply` (both deleted upstream).
- Removed `--split_queries always` from `#push-options` (option deleted).

## [0.1.0] — initial extraction

### Added

- Extracted the `Data.Image` package (core image type + PNG + QR-code codecs)
  out of the original monorepo into a standalone repository built from
  `fstar-nix-flake-template`.
- Source modules:
  - `Data.Image` — the universal image type, color spaces, pixel formats,
    validation and smart constructors, and the ASCII-art codec.
  - `Data.Image.Convert` — image format conversions.
  - `Data.Image.PNG.CRC` / `Deflate` / `Zlib` / `Filter` / `Encode` — PNG
    (ISO/IEC 15948:2004) CRC-32, deflate stored blocks, the RFC 1950 zlib
    wrapper, all five filters (None/Sub/Up/Average/Paeth), and the encoder.
  - `Data.Image.QRCode.Types` / `LUT` / `GF256` / `ReedSolomon` /
    `DataEncoding` / `Matrix` / `Encode` / `Render` — QR code (ISO/IEC 18004)
    types, function/data-position tables, GF(256) arithmetic, Reed–Solomon
    EC, byte-mode data encoding, matrix placement + masks, the encoder, and
    the renderer.
  - `Data.Image.Pulse`, `Data.Image.PNG.Pulse`, `Data.Image.QRCode.Pulse` —
    C-extractable 1-byte tag-dispatch leaves.
- Test module: `Data.Image.Test.Integration`.
- Nix flake targets: `.#checked`, `.#ocaml`, `.#native`, `.#fsharp`.
- Dual licensing: AGPL-3.0-or-later, or a commercial license from the author.

### Notes

- Zero admits / zero magic / zero `assume` across all 18 modules.
