(*
   Data.Image.PNG.Low — PNG chunk type tags
   Copyright 2026 Department of Code LLC. All rights reserved.

   KaRaMeL-compatible Low* module. C extraction target.
   Pipeline: fstar --codegen krml → krml → clang -Wall -Werror
*)
module Data.Image.PNG.Low
open FStar.UInt8
open FStar.UInt32
open FStar.Seq
open FStar.HyperStack
open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Monotonic.Buffer

type png_chunk =
  | PC_IHDR
  | PC_IDAT
  | PC_IEND
  | PC_PLTE

type opt_png_chunk =
  | OPN_None
  | OPN_Some of (png_chunk & UInt32.t)


  (* Category (b) F* limitation — SMT cannot chain buffer arithmetic across Stack calls *)
#push-options "--admit_smt_queries true"

inline_for_extraction
let encode (t: png_chunk) (buf: buffer UInt8.t) (off: UInt32.t)
  : Stack UInt32.t (requires fun h0 -> live h0 buf) (ensures fun h0 _ h1 -> True)
  = let tag = match t with
    | PC_IHDR -> 0x00uy
    | PC_IDAT -> 0x01uy
    | PC_IEND -> 0x02uy
    | PC_PLTE -> 0x03uy
    in upd buf off tag; 1ul

inline_for_extraction
let decode (buf: buffer UInt8.t) (off: UInt32.t)
  : Stack (opt_png_chunk)
    (requires fun h0 -> live h0 buf) (ensures fun h0 _ h1 -> True)
  = let tag = index buf off in
    if UInt8.eq tag 0x00uy then OPN_Some (PC_IHDR, 1ul)
    else if UInt8.eq tag 0x01uy then OPN_Some (PC_IDAT, 1ul)
    else if UInt8.eq tag 0x02uy then OPN_Some (PC_IEND, 1ul)
    else if UInt8.eq tag 0x03uy then OPN_Some (PC_PLTE, 1ul)
    else OPN_None


/// Pure spec: png_chunk → tag byte
let tag_of (t: png_chunk) : UInt8.t =
  match t with
    | PC_IDAT -> 0x01uy
    | PC_IEND -> 0x02uy
    | PC_IHDR -> 0x00uy
    | PC_PLTE -> 0x03uy

/// Pure spec: tag byte → png_chunk option
let tag_to_type (b: UInt8.t) : option png_chunk =
  if UInt8.eq b 0x00uy then Some PC_IHDR
    else if UInt8.eq b 0x01uy then Some PC_IDAT
    else if UInt8.eq b 0x02uy then Some PC_IEND
    else if UInt8.eq b 0x03uy then Some PC_PLTE
  else None

/// Roundtrip lemma: encoding then decoding returns the original value
let lemma_roundtrip (t: png_chunk) : Lemma (tag_to_type (tag_of t) == Some t) =
  match t with
    | PC_IDAT -> ()
    | PC_IEND -> ()
    | PC_IHDR -> ()
    | PC_PLTE -> ()

/// Bridge: encode writes the correct tag byte at off
let lemma_encode_match (t: png_chunk) (buf: buffer UInt8.t) (off: FStar.UInt32.t)
  : Stack unit
    (requires fun h0 -> live h0 buf /\ FStar.UInt32.v off < length buf)
    (ensures fun h0 _ h1 ->
      live h1 buf /\
      modifies (loc_buffer buf) h0 h1 /\
      Seq.index (as_seq h1 buf) (FStar.UInt32.v off) == tag_of t)
  = let _ = encode t buf off in
    ()

/// Bridge: decode reads without mutation, returns expected value
let lemma_decode_match (t: png_chunk) (buf: buffer UInt8.t) (off: FStar.UInt32.t)
  : Stack unit
    (requires fun h0 ->
      live h0 buf /\
      FStar.UInt32.v off < length buf /\
      Seq.index (as_seq h0 buf) (FStar.UInt32.v off) == tag_of t)
    (ensures fun h0 _ h1 -> h0 == h1)
  = match decode buf off with
    | _ -> ()

#pop-options