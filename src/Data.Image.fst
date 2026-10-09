(*
   Data.Image — Universal Image Type
   Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later

   Core types: pixel_format, color_space, image record.
   Validation and smart constructors.
*)
module Data.Image
open Data.Codec
open FStar.List.Tot
module U8 = FStar.UInt8

(* ========================================================================
   SECTION 1: Color Space & Pixel Format
   ======================================================================== *)

type color_space =
  | SRGB
  | LinearRGB
  | Gray

type pixel_format =
  | Gray8
  | GrayAlpha8
  | RGB8
  | RGBA8
  | Palette8 of list (byte & byte & byte)

(* ========================================================================
   SECTION 2: Pixel Format Properties
   ======================================================================== *)

let channels (f: pixel_format) : nat =
  match f with
  | Gray8 -> 1
  | GrayAlpha8 -> 2
  | RGB8 | Palette8 _ -> 3
  | RGBA8 -> 4

let bytes_per_pixel (f: pixel_format) : nat = channels f

(* ========================================================================
   SECTION 3: Image Record
   ======================================================================== *)

type image = {
  width      : nat;
  height     : nat;
  format     : pixel_format;
  colorspace : color_space;
  data       : list byte;
}

(* ========================================================================
   SECTION 4: Validation
   ======================================================================== *)

let valid_image (img: image) : bool =
  img.width > 0 &&
  img.height > 0 &&
  List.Tot.length img.data = img.width * img.height * bytes_per_pixel img.format

(* ========================================================================
   SECTION 5: Smart Constructors
   ======================================================================== *)

let make_image (w h: nat) (f: pixel_format) (cs: color_space) (data: list byte) : option image =
  let img = { width = w; height = h; format = f; colorspace = cs; data = data } in
  if valid_image img then Some img else None

let make_gray8 (w h: nat) (data: list byte) : option image =
  make_image w h Gray8 SRGB data

let make_rgba8 (w h: nat) (data: list byte) : option image =
  make_image w h RGBA8 SRGB data

(* ========================================================================
   SECTION 6: ASCII Art Codec (Image <-> terminal bytes)

   Bidirectional codec for encoding/decoding Gray8 images as terminal-
   displayable ASCII art. Double-wide blocks (2 bytes per pixel) for
   square aspect on terminals with ~2:1 character proportions.

   Dark pixels (value < 128) → two 0xFF sentinel bytes.
   Light pixels (value >= 128) → two 0x20 bytes (spaces).
   Rows separated by 0x0A (newline).

   The OCaml display layer maps 0xFF → Unicode full block (U+2588).
   ======================================================================== *)

let ascii_dark  : byte = 0xFFuy   (* sentinel for dark pixel -> display as block *)
let ascii_light : byte = 0x20uy   (* space *)
let ascii_nl    : byte = 0x0Auy   (* newline *)

(* The ASCII-art codec is a THRESHOLD view of a Gray8 image: dark pixels
   (< 128) render as a double [ascii_dark] block and decode back to 0x00;
   light pixels (>= 128) render as a double [ascii_light] and decode back to
   0xFF.  The roundtrip is therefore threshold-exact (p < 128 preserved), not
   byte-exact: [decode_ascii (encode_ascii img) w] returns [Some img'] whose
   data is [List.map threshold img.data]. *)

/// Threshold a gray pixel to its 1-bit representative (0x00 dark / 0xFF light).
let threshold (p: byte) : byte = if U8.v p < 128 then 0x00uy else 0xFFuy

/// The 2-byte cell encoding one thresholded pixel.
let pixel_cell (dark: bool) : list byte =
  if dark then [ascii_dark; ascii_dark] else [ascii_light; ascii_light]

/// Encode a Gray8 image's flat data to ASCII art: each row is [w] pixel
/// cells (2 bytes each) followed by a newline.  [i] is the absolute flat
/// index; a newline is emitted after every [w]-pixel group (including the
/// last), matching [decode_row]/[decode_rows] framing.
let rec encode_flat (w: nat{w > 0}) (data: list byte) (i: nat)
  : Tot (list byte) (decreases data) =
  match data with
  | [] -> []
  | p :: tl ->
    let b = if U8.v p < 128 then ascii_dark else ascii_light in
    if (i + 1) % w = 0
    then b :: b :: ascii_nl :: encode_flat w tl (i + 1)
    else b :: b :: encode_flat w tl (i + 1)

/// Encode a Gray8 image to ASCII art bytes. Returns [] if not Gray8.
let encode_ascii (img: image) : list byte =
  if img.format <> Gray8 || img.width = 0 then []
  else encode_flat img.width img.data 0

/// Decode one pixel cell (2 bytes) to its thresholded value; None if malformed.
let decode_cell (b1 b2: byte) : option byte =
  if b1 = ascii_dark && b2 = ascii_dark then Some 0x00uy
  else if b1 = ascii_light && b2 = ascii_light then Some 0xFFuy
  else None

/// Decode one row: w pixel cells followed by a newline.  Returns None on
/// malformed input (a bad cell or a missing/dangling newline).
let rec decode_row (w: nat) (bs: list byte) (col: nat)
  : Tot (option (list byte & list byte)) (decreases bs) =
  if col >= w then
    match bs with
    | [] -> Some ([], [])
    | ascii_nl :: tl -> Some ([], tl)
    | _ -> None
  else
    match bs with
    | b1 :: b2 :: tl ->
      (match decode_cell b1 b2 with
       | None -> None
       | Some px ->
         (match decode_row w tl (col + 1) with
          | None -> None
          | Some (row, rem) -> Some (px :: row, rem)))
    | _ -> None

/// Decode [h] rows of width [w] into flat row-major gray data.  Uses an
/// accumulating [acc] (reversed) to avoid [@]/[rev] in the hot path.
let rec decode_rows (w: nat) (h: nat) (bs: list byte) (acc: list byte)
  : Tot (option (list byte)) (decreases %[h; bs]) =
  if h = 0 then
    if bs = [] then Some (List.rev acc) else None
  else
    match decode_row w bs 0 with
    | None -> None
    | Some (row, remaining) ->
      decode_rows w (h - 1) remaining (List.rev row @ acc)

/// Decode ASCII art bytes back to a Gray8 image of given width.
/// Requires width > 0; returns None on malformed input.
let decode_ascii (bs: list byte) (w: nat{w > 0}) : option image =
  let row_bytes = w * 2 + 1 in  (* w pixels * 2 bytes + newline *)
  let total_rows = length bs / row_bytes in
  if row_bytes = 0 || length bs <> total_rows * row_bytes || total_rows = 0 then None
  else
    match decode_rows w total_rows bs [] with
    | None -> None
    | Some data -> make_gray8 w total_rows data

(* ========================================================================
   SECTION 7: ASCII Roundtrip Rejection + Concrete vectors
   ======================================================================== *)

/// Non-Gray8 images encode to [].
let lemma_encode_ascii_non_gray8 (img: image{img.format <> Gray8}) : Lemma
  (encode_ascii img == []) = ()

/// A single dark pixel round-trips (threshold-exact).
let lemma_ascii_roundtrip_dark () : Lemma
  (decode_ascii (encode_ascii ({ width = 1; height = 1; format = Gray8;
      colorspace = Gray; data = [0x00uy] })) 1
   == Some ({ width = 1; height = 1; format = Gray8; colorspace = SRGB;
              data = [0x00uy] })) = ()

/// A single light pixel round-trips (threshold-exact).
let lemma_ascii_roundtrip_light () : Lemma
  (decode_ascii (encode_ascii ({ width = 1; height = 1; format = Gray8;
      colorspace = Gray; data = [0xFFuy] })) 1
   == Some ({ width = 1; height = 1; format = Gray8; colorspace = SRGB;
              data = [0xFFuy] })) = ()

/// A mixed 2x1 row (dark then light) round-trips.
let lemma_ascii_roundtrip_mixed () : Lemma
  (decode_ascii (encode_ascii ({ width = 2; height = 1; format = Gray8;
      colorspace = Gray; data = [0x00uy; 0x80uy] })) 2
   == Some ({ width = 2; height = 1; format = Gray8; colorspace = SRGB;
              data = [0x00uy; 0xFFuy] })) = ()

/// A malformed cell (dark/light mismatch) is rejected.
let lemma_ascii_reject_bad_cell () : Lemma
  (decode_ascii [ascii_dark; ascii_light; ascii_nl] 1 == None) = ()

/// A dangling byte (not a full row) is rejected.
let lemma_ascii_reject_dangling () : Lemma
  (decode_ascii [ascii_dark; ascii_dark] 2 == None) = ()

