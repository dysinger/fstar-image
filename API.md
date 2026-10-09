# Data.Image API Reference

## Types

### Data.Image — Pure Spec
| Name | Kind | Description |
|------|------|-------------|
| `color_space` | enum | `Gray` / `RGB` / `RGBA` |
| `pixel_format` | enum | `Gray8` / `RGB8` / `RGBA8` |
| `image` | record | `width` + `height` + `format` + `colorspace` + `data` |
| `filter_type` | enum | `FilterNone` / `FilterSub` / `FilterUp` / `FilterAverage` / `FilterPaeth` |
| `version` | refined nat | QR version `1..40` |
| `ecl` | enum | `L` / `M` / `Q` / `H` error-correction level |
| `qr_matrix` | record | `version` + `modules` |

### Pulse leaves — Extractable enums + result sums
| Name | Kind | Description |
|------|------|-------------|
| `img_fmt` | enum | image-format tag dispatch |
| `png_chunk` | enum | PNG chunk-type tag dispatch |
| `qr_mode` | enum | QR encoding-mode tag dispatch |

## Core image API

| Function | Signature | Description |
|----------|-----------|-------------|
| `channels` | `pixel_format -> nat` | channel count (1/3/4) |
| `bytes_per_pixel` | `pixel_format -> nat` | bytes per pixel |
| `valid_image` | `image -> bool` | `length data = width*height*bpp` |
| `make_image` | `nat -> nat -> pixel_format -> color_space -> list byte -> option image` | validated constructor |
| `make_gray8` / `make_rgba8` | `nat -> nat -> list byte -> option image` | convenience constructors |
| `encode_ascii` | `image -> list byte` | threshold ASCII-art encode |
| `decode_ascii` | `list byte -> nat -> option image` | ASCII-art decode |

## Conversion API (`Data.Image.Convert`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `convert_gray_to_rgb` | `image -> image` | Gray8 → RGB8 |
| `convert_gray_to_rgba` | `image -> image` | Gray8 → RGBA8 |
| `convert_rgb_to_rgba` | `image -> image` | RGB8 → RGBA8 |
| `convert_rgba_to_rgb` | `image -> image` | RGBA8 → RGB8 |

## PNG API

| Function | Signature | Description |
|----------|-----------|-------------|
| `crc32_of_bytes` | `list byte -> UInt32.t` | CRC-32 (reflected `0xEDB88320`) |
| `crc32_ref_of_bytes` | `list byte -> UInt32.t` | independent table-driven reference |
| `adler32` | `list byte -> nat` | Adler-32 (mod 65521) |
| `zlib_wrap` / `zlib_unwrap` | `list byte -> list byte` / `list byte -> option (list byte & list byte)` | RFC 1950 wrap/unwrap |
| `filter_scanline` | `filter_type -> list byte -> list byte -> nat -> list byte` | encode one scanline |
| `reconstruct_scanline` | `filter_type -> list byte -> list byte -> nat -> option (list byte)` | inverse |
| `paeth_predictor` | `byte -> byte -> byte -> byte` | ISO 15948 §9 predictor |

## QR API

| Function | Signature | Description |
|----------|-----------|-------------|
| `matrix_size` | `version -> nat` | `17 + 4·version` |
| `total_data_codewords` | `version -> ecl -> nat` | ISO 18004 Table 7 capacity |
| `encode_uri` | `string -> version -> ecl -> option (list byte & version)` | byte-mode data encode |
| `rs_generate_ec` | `list byte -> nat -> list byte` | Reed–Solomon EC codewords |
| `apply_mask` / `mask_condition` | `qr_matrix -> nat -> qr_matrix` / `nat -> nat -> nat -> bool` | ISO 18004 §8.8 masks |
| `mask_penalty` / `select_best_mask` | `qr_matrix -> nat -> nat` / `qr_matrix -> nat` | penalty scoring + best mask |
| `format_info` | `ecl -> nat -> nat` | BCH(15,5) format info |
| `encode_qr_uri` | `string -> version -> ecl -> option qr_matrix` | full QR encode |

## Pulse leaf functions (`fn`, extractable)

| Function | Module | Description |
|----------|--------|-------------|
| `encode_img_fmt` / `decode_img_fmt` | `Data.Image.Pulse` | image-format tag encode/decode |
| `encode_png_chunk` / `decode_png_chunk` | `Data.Image.PNG.Pulse` | PNG chunk tag encode/decode |
| `encode_qr_mode` / `decode_qr_mode` | `Data.Image.QRCode.Pulse` | QR mode tag encode/decode |

Each `fn` has a roundtrip lemma (`lemma_pulse_*_roundtrip`) proving
encode-then-decode recovers the input.
