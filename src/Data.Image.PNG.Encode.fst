(*
   Data.Image.PNG.Encode — Top-level PNG encoder
   Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later

   Encodes dualis image values to complete PNG byte streams.
   v0.1: FilterNone only, BTYPE=00 (stored), 8-bit color types only.
*)
module Data.Image.PNG.Encode
open Data.Image
open Data.Image.PNG.CRC
open Data.Image.PNG.Filter
open Data.Image.PNG.Deflate
open Data.Image.PNG.Zlib
open Data.Codec
open FStar.List.Tot
open FStar.UInt32
open FStar.UInt8

(* ========================================================================
   SECTION 1: PNG Signature
   ======================================================================== *)

/// The 8-byte PNG magic number: \x89 P N G \r \n \x1a \n
let png_signature : list byte =
  [0x89uy; 0x50uy; 0x4Euy; 0x47uy; 0x0Duy; 0x0Auy; 0x1Auy; 0x0Auy]

/// Lemma: signature is exactly 8 bytes.
let lemma_signature_length () : Lemma
  (ensures List.Tot.length png_signature = 8)
  = assert_norm (List.Tot.length png_signature = 8)

/// Known-answer: the PNG signature is the ISO/IEC 15948:2004 §5.2 eight-byte
/// sequence 89 50 4E 47 0D 0A 1A 0A (0x89 "PNG" CR LF 0x1A LF).
let lemma_png_signature_bytes () : Lemma
  (ensures png_signature == [
     0x89uy; 0x50uy; 0x4Euy; 0x47uy; 0x0Duy; 0x0Auy; 0x1Auy; 0x0Auy ])
  = assert_norm (png_signature == [
      0x89uy; 0x50uy; 0x4Euy; 0x47uy; 0x0Duy; 0x0Auy; 0x1Auy; 0x0Auy ])

(* ========================================================================
   SECTION 2: Chunk Assembly
   ======================================================================== *)

/// Convert a nat value to 4 bytes big-endian.
/// Used for chunk length field and IHDR width/height.
let nat_to_bytes_be4 (n: nat) : list byte =
  [uint_to_t ((n / 16777216) % 256);
   uint_to_t ((n / 65536) % 256);
   uint_to_t ((n / 256) % 256);
   uint_to_t (n % 256)]

/// Convert a UInt32.t to 4 bytes big-endian (for CRC output).
let uint32_to_bytes_be (v: UInt32.t) : list byte =
  let v_int : int = UInt32.v v in
  [uint_to_t ((v_int / 16777216) % 256);
   uint_to_t ((v_int / 65536) % 256);
   uint_to_t ((v_int / 256) % 256);
   uint_to_t (v_int % 256)]

/// Build a PNG chunk:
/// - 4-byte data length (big-endian)
/// - 4-byte chunk type
/// - data bytes
/// - 4-byte CRC32 of (chunk_type + data)
let make_chunk (chunk_type: list byte) (data: list byte) : list byte =
  let length_bytes = nat_to_bytes_be4 (List.Tot.length data) in
  let crc_input = chunk_type @ data in
  let crc = crc32_of_bytes crc_input in
  let crc_bytes = uint32_to_bytes_be crc in
  length_bytes @ chunk_type @ data @ crc_bytes

(* ========================================================================
   SECTION 3: IHDR Chunk
   ======================================================================== *)

/// Map pixel_format to PNG color type byte.
let png_color_type (f: pixel_format) : byte =
  match f with
  | Gray8      -> 0x00uy  (* Grayscale *)
  | RGB8       -> 0x02uy  (* Truecolor *)
  | RGBA8      -> 0x06uy  (* RGBA *)
  | GrayAlpha8 -> 0x04uy  (* Grayscale + Alpha *)
  | Palette8 _ -> 0x03uy  (* Indexed-color *)

/// Create IHDR chunk data (13 bytes):
/// - width (4 bytes big-endian)
/// - height (4 bytes big-endian)
/// - bit depth (1 byte: 8)
/// - color type (1 byte)
/// - compression method (1 byte: 0)
/// - filter method (1 byte: 0)
/// - interlace method (1 byte: 0)
let make_ihdr (img: image{valid_image img}) : list byte =
  let ihdr_type : list byte = [0x49uy; 0x48uy; 0x44uy; 0x52uy] in  (* "IHDR" *)
  let width_bytes = nat_to_bytes_be4 img.width in
  let height_bytes = nat_to_bytes_be4 img.height in
  let bit_depth : byte = 0x08uy in
  let color_type = png_color_type img.format in
  let compression : byte = 0x00uy in
  let filter : byte = 0x00uy in
  let interlace : byte = 0x00uy in
  let ihdr_data = width_bytes @ height_bytes @
    [bit_depth; color_type; compression; filter; interlace] in
  make_chunk ihdr_type ihdr_data

(* ========================================================================
   SECTION 4: Scanline Extraction
   ======================================================================== *)

/// Take the first n bytes from a list. Returns (taken, remaining).
let rec take_bytes (n: nat) (xs: list byte)
  : Tot (list byte & list byte) (decreases n)
  =
  if n = 0 then ([], xs)
  else match xs with
  | [] -> ([], [])
  | h :: t ->
    let (taken, rest) = take_bytes (n - 1) t in
    (h :: taken, rest)

/// Lemma: take_bytes n xs produces result where length(taken) + length(rest) = length(xs).
let rec lemma_take_bytes_length (n: nat) (xs: list byte)
  : Lemma
    (ensures (
      let (taken, rest) = take_bytes n xs in
      List.Tot.length taken + List.Tot.length rest = List.Tot.length xs))
    (decreases n)
  =
  if n = 0 then ()
  else match xs with
  | [] -> ()
  | _ :: t -> lemma_take_bytes_length (n - 1) t

/// Lemma: if [length xs >= n], then [take_bytes n xs] takes exactly [n] bytes.
let rec lemma_take_bytes_n (n: nat) (xs: list byte) : Lemma
  (requires length xs >= n)
  (ensures (match take_bytes n xs with (t, r) -> length t = n /\ length r = length xs - n))
  (decreases n)
  = if n = 0 then ()
    else match xs with
      | h :: t -> lemma_take_bytes_n (n - 1) t

/// Split flat pixel data into scanlines.
/// Each scanline has scanline_len bytes (width * bytes_per_pixel).
let rec split_scanlines (data: list byte) (scanline_len: nat)
  : Tot (list (list byte)) (decreases (List.Tot.length data))
  =
  if scanline_len = 0 then []
  else
    let (line, rest) = take_bytes scanline_len data in
    if List.Tot.length line = scanline_len then (
      lemma_take_bytes_length scanline_len data;
      line :: split_scanlines rest scanline_len
    ) else
      []

(* ========================================================================
   SECTION 5: Filter Application
   ======================================================================== *)

/// Apply FilterNone to a single scanline: prepend 0x00 filter byte.
let filter_scanline_none (scanline: list byte) : list byte =
  filter_byte FilterNone :: scanline

/// Apply FilterNone to all scanlines (concatenated).
let rec filter_all_scanlines (scanlines: list (list byte))
  : Tot (list byte) (decreases scanlines)
  =
  match scanlines with
  | [] -> []
  | line :: rest ->
    filter_scanline_none line @ filter_all_scanlines rest


(* ========================================================================
   SECTION 6: Full PNG Encoder
   ======================================================================== *)

/// Compute the total filtered data length for an image.
/// Each scanline gets a +1 filter byte, so total = height * (width * bpp + 1).
let filtered_data_length (img: image) : nat =
  img.height * (img.width * bytes_per_pixel img.format + 1)

/// [filtered_data_length] equals the actual length of the filtered byte
/// stream: [filter_all_scanlines (split_scanlines data sl)] has length
/// [height * (sl + 1)] when [data] is exactly [height] scanlines of [sl]
/// bytes ([sl > 0]).  Proved by induction on [height].
let rec lemma_filtered_length_eq (data: list byte) (height sl: nat)
  : Lemma
    (requires List.Tot.length data = height * sl /\ sl > 0)
    (ensures
      List.Tot.length (filter_all_scanlines (split_scanlines data sl))
      = height * (sl + 1))
    (decreases height)
  =
  if height = 0 then ()
  else
    let (line, rest) = take_bytes sl data in
    lemma_take_bytes_n sl data;
    lemma_filtered_length_eq rest (height - 1) sl;
    append_length (filter_scanline_none line)
      (filter_all_scanlines (split_scanlines rest sl))

/// The encoder's filtered stream length equals [filtered_data_length img].
let lemma_encode_filtered_length
  (img: image{valid_image img /\ filtered_data_length img < 65536})
  : Lemma
    (ensures
      List.Tot.length
        (filter_all_scanlines
          (split_scanlines img.data (img.width * bytes_per_pixel img.format)))
      = filtered_data_length img /\
      filtered_data_length img < 65536)
  =
  let sl = img.width * bytes_per_pixel img.format in
  lemma_filtered_length_eq img.data img.height sl;
  ()

/// Encode an image as a complete PNG byte stream.
/// v0.1: requires filtered data < 65536 bytes (single deflate stored block limit).
let encode_png (img: image{valid_image img /\ filtered_data_length img < 65536}) : list byte =
  let scanline_len : nat = img.width * bytes_per_pixel img.format in
  let scanlines = split_scanlines img.data scanline_len in
  let filtered = filter_all_scanlines scanlines in
  lemma_encode_filtered_length img;
  let compressed = zlib_wrap filtered in
  let idat_type : list byte = [0x49uy; 0x44uy; 0x41uy; 0x54uy] in  (* "IDAT" *)
  let idat_chunk = make_chunk idat_type compressed in
  let iend_type : list byte = [0x49uy; 0x45uy; 0x4Euy; 0x44uy] in  (* "IEND" *)
  let iend_chunk = make_chunk iend_type [] in
  png_signature @ (make_ihdr img) @ idat_chunk @ iend_chunk

(* ========================================================================
   SECTION 7: Lemmas
   ======================================================================== *)

/// The PNG encoder always produces a non-empty byte stream
/// (at minimum: 8-byte signature + IHDR chunk + IDAT chunk + IEND chunk).
let lemma_png_encode_valid (img: image{valid_image img /\ filtered_data_length img < 65536}) : Lemma
  (ensures encode_png img <> [])
  =
  assert_norm (png_signature <> [])
