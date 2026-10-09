(*
   Data.Image.Convert — Format Conversion
   Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later

   Convert between pixel formats: Gray→RGB, Gray→RGBA, RGB→RGBA, RGBA→RGB.
*)
module Data.Image.Convert
open Data.Image
open Data.Codec
open FStar.List.Tot

(* ========================================================================
   SECTION 1: Declarations
   ======================================================================== *)

val convert_gray_to_rgb (img: image{img.format = Gray8 /\ valid_image img}) : image
val convert_gray_to_rgba (img: image{img.format = Gray8 /\ valid_image img}) : image
val convert_rgb_to_rgba (img: image{img.format = RGB8 /\ valid_image img}) : image
val convert_rgba_to_rgb (img: image{img.format = RGBA8 /\ valid_image img}) : image

(* ========================================================================
   SECTION 2: Gray → RGB (replicate gray across R, G, B)
   ======================================================================== *)

let rec gray_to_rgb_data (data: list byte) : Tot (list byte) (decreases data) =
  match data with
  | [] -> []
  | g :: rest -> g :: g :: g :: gray_to_rgb_data rest

let convert_gray_to_rgb (img: image{img.format = Gray8 /\ valid_image img}) : image =
  {
    width = img.width;
    height = img.height;
    format = RGB8;
    colorspace = img.colorspace;
    data = gray_to_rgb_data img.data;
  }

(* ========================================================================
   SECTION 3: Gray → RGBA (replicate gray across R, G, B + alpha=255)
   ======================================================================== *)

let rec gray_to_rgba_data (data: list byte) : Tot (list byte) (decreases data) =
  match data with
  | [] -> []
  | g :: rest -> g :: g :: g :: 255uy :: gray_to_rgba_data rest

let convert_gray_to_rgba (img: image{img.format = Gray8 /\ valid_image img}) : image =
  {
    width = img.width;
    height = img.height;
    format = RGBA8;
    colorspace = img.colorspace;
    data = gray_to_rgba_data img.data;
  }

(* ========================================================================
   SECTION 4: RGB → RGBA (append alpha=255 to each pixel)
   ======================================================================== *)

let rec rgb_to_rgba_data (data: list byte) : Tot (list byte) (decreases data) =
  match data with
  | [] -> []
  | r :: rest1 ->
    (match rest1 with
     | [] -> []
     | g :: rest2 ->
       (match rest2 with
        | [] -> []
        | b :: rest -> r :: g :: b :: 255uy :: rgb_to_rgba_data rest))

let convert_rgb_to_rgba (img: image{img.format = RGB8 /\ valid_image img}) : image =
  {
    width = img.width;
    height = img.height;
    format = RGBA8;
    colorspace = img.colorspace;
    data = rgb_to_rgba_data img.data;
  }

(* ========================================================================
   SECTION 5: RGBA → RGB (strip alpha channel)
   ======================================================================== *)

let rec rgba_to_rgb_data (data: list byte) : Tot (list byte) (decreases data) =
  match data with
  | [] -> []
  | r :: rest1 ->
    (match rest1 with
     | [] -> []
     | g :: rest2 ->
       (match rest2 with
        | [] -> []
        | b :: rest3 ->
          (match rest3 with
           | [] -> []
           | _ :: rest -> r :: g :: b :: rgba_to_rgb_data rest)))

let convert_rgba_to_rgb (img: image{img.format = RGBA8 /\ valid_image img}) : image =
  {
    width = img.width;
    height = img.height;
    format = RGB8;
    colorspace = img.colorspace;
    data = rgba_to_rgb_data img.data;
  }

(* ========================================================================
   SECTION 6: Correctness Lemmas
   ======================================================================== *)

/// [gray_to_rgb_data] triples the length (1 gray byte -> 3 rgb bytes).
let rec lemma_gray_to_rgb_data_length (data: list byte) : Lemma
  (length (gray_to_rgb_data data) = 3 * length data)
  (decreases data)
  = match data with
    | [] -> ()
    | _ :: tl -> lemma_gray_to_rgb_data_length tl

/// [rgb_to_rgba_data] then [rgba_to_rgb_data] is the identity on well-grouped
/// RGB data (length divisible by 3).
let rec lemma_rgba_rgb_roundtrip (data: list byte) : Lemma
  (requires length data % 3 = 0)
  (ensures rgba_to_rgb_data (rgb_to_rgba_data data) == data)
  (decreases data)
  = match data with
    | [] -> ()
    | r :: rest1 ->
      (match rest1 with
       | g :: rest2 ->
         (match rest2 with
          | b :: rest -> lemma_rgba_rgb_roundtrip rest
          | [] -> ())
       | [] -> ())

/// [gray_to_rgba_data] then extracting R,G,B and dropping alpha recovers the
/// gray data: [rgba_to_rgb_data (gray_to_rgba_data data) == gray_to_rgb_data data].
let rec lemma_gray_rgba_rgb (data: list byte) : Lemma
  (rgba_to_rgb_data (gray_to_rgba_data data) == gray_to_rgb_data data)
  (decreases data)
  = match data with
    | [] -> ()
    | _ :: tl -> lemma_gray_rgba_rgb tl

/// Concrete vector: [gray_to_rgb_data [0x0A; 0x14]] == [0x0A;0x0A;0x0A;0x14;0x14;0x14].
let lemma_gray_to_rgb_vector () : Lemma
  (gray_to_rgb_data [0x0Auy; 0x14uy] == [0x0Auy;0x0Auy;0x0Auy;0x14uy;0x14uy;0x14uy])
  = ()

/// Concrete vector: RGB->RGBA->RGB round-trip of a single pixel.
let lemma_rgb_rgba_rgb_vector () : Lemma
  (rgba_to_rgb_data (rgb_to_rgba_data [0x01uy;0x02uy;0x03uy])
   == [0x01uy;0x02uy;0x03uy])
  = ()
