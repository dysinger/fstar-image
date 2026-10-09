# image — verified PNG + QR-code image codecs

Copyright 2026 Department of Code LLC.
SPDX-License-Identifier: AGPL-3.0-or-later

`Data.Image` is a formally verified image codec library: a universal image
type plus PNG (ISO/IEC 15948:2004) and QR code (ISO/IEC 18004) encoders and
decoders, written in F\* and extracted to C, OCaml, and F# via **Custard**.

## Modules

| Module | Purpose |
|--------|---------|
| `Data.Image` | The `image` record, color spaces, pixel formats, validation + smart constructors, and the ASCII-art codec |
| `Data.Image.Convert` | Image format conversions |
| `Data.Image.PNG.CRC` | CRC-32 (ISO 15948 Annex D), table-free bitwise + independent table-driven reference |
| `Data.Image.PNG.Deflate` | Deflate stored blocks (BTYPE=00) |
| `Data.Image.PNG.Zlib` | RFC 1950 zlib wrapper (CMF/FLG + Adler-32) |
| `Data.Image.PNG.Filter` | All five PNG filters (None/Sub/Up/Average/Paeth), encode + reconstruct, 0-admit roundtrips |
| `Data.Image.PNG.Encode` | PNG encoder |
| `Data.Image.QRCode.Types` | QR types (`version`, `ecl`, `qr_matrix`) |
| `Data.Image.QRCode.LUT` | Function-module + data-position tables |
| `Data.Image.QRCode.GF256` | GF(256) field arithmetic |
| `Data.Image.QRCode.ReedSolomon` | Reed–Solomon error correction |
| `Data.Image.QRCode.DataEncoding` | Byte-mode data encoding (ISO 18004 §7.4.3), capacity tables |
| `Data.Image.QRCode.Matrix` | Matrix placement, the 8 mask patterns, penalty scoring, best-mask selection |
| `Data.Image.QRCode.Encode` | QR encoder (BCH(15,5) format info, ECC) |
| `Data.Image.QRCode.Render` | Matrix → image rendering |
| `Data.Image.Pulse` / `Data.Image.PNG.Pulse` / `Data.Image.QRCode.Pulse` | C/OCaml/F#-extractable Pulse leaves (1-byte tag dispatch) |

## Standard coverage

| Feature | Standard | Notes |
|---------|----------|-------|
| PNG signature + chunk structure | ISO/IEC 15948:2004 §5 | CRC-32 check values (`"123456789"` → `0xCBF43926`, `"IEND"` → `0xAE426082`) |
| Filters (None/Sub/Up/Average/Paeth) | ISO/IEC 15948:2004 §9 | roundtrips proven by induction; §9.2/§9.3 concrete vectors |
| CRC-32 | ISO/IEC 15948 Annex D | reflected poly `0xEDB88320` |
| zlib header | RFC 1950 §2.2 | CMF=0x78, FLG=0x9C; FCHECK divisibility; Adler-32 check value |
| QR matrix size | ISO/IEC 18004 §6.3.3 | `17 + 4·version` |
| Data capacity | ISO/IEC 18004 Table 7 | all 40 versions × L/M/Q/H |
| Data encoding | ISO/IEC 18004 §7.4.3 | byte mode + padding |
| Mask patterns + penalty | ISO/IEC 18004 §8.8 | all 8 masks, N1–N4 penalties, best-mask selection |

## Build

```bash
nix build .#checked   # F* verification gate (0-admit)
nix build .#native    # C11 shared/static lib (default)
nix build .#fsharp    # .NET library
nix build .#ocaml     # OCaml findlib package
nix fmt               # format nix files (treefmt)
nix develop && make check   # dev loop (no nix)
```

The `codec` dependency is injected as a flake input (`github:dysinger/fstar-codec`),
its source as `codec-src` and its pre-verified `.checked` set as `codec-checked`.

## API

See [`API.md`](API.md) for the full public API reference.
