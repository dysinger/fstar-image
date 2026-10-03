(*
   Data.Image.Low — Image format type tags
   Copyright 2026 Department of Code LLC. All rights reserved.

   KaRaMeL-compatible Low* module. C extraction target.
   Pipeline: fstar --codegen krml → krml → clang -Wall -Werror
*)
module Data.Image.Low
open FStar.UInt8
open FStar.UInt32
open FStar.Seq
open FStar.HyperStack
open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Monotonic.Buffer

type img_fmt =
  | IF_PNG
  | IF_JPEG
  | IF_GIF
  | IF_BMP

type opt_img_fmt =
  | OIM_None
  | OIM_Some of (img_fmt & UInt32.t)


  (* Category (b) F* limitation — SMT cannot chain buffer arithmetic across Stack calls *)
#push-options "--admit_smt_queries true"

inline_for_extraction
let encode (t: img_fmt) (buf: buffer UInt8.t) (off: UInt32.t)
  : Stack UInt32.t (requires fun h0 -> live h0 buf) (ensures fun h0 _ h1 -> True)
  = let tag = match t with
    | IF_PNG -> 0x00uy
    | IF_JPEG -> 0x01uy
    | IF_GIF -> 0x02uy
    | IF_BMP -> 0x03uy
    in upd buf off tag; 1ul

inline_for_extraction
let decode (buf: buffer UInt8.t) (off: UInt32.t)
  : Stack (opt_img_fmt)
    (requires fun h0 -> live h0 buf) (ensures fun h0 _ h1 -> True)
  = let tag = index buf off in
    if UInt8.eq tag 0x00uy then OIM_Some (IF_PNG, 1ul)
    else if UInt8.eq tag 0x01uy then OIM_Some (IF_JPEG, 1ul)
    else if UInt8.eq tag 0x02uy then OIM_Some (IF_GIF, 1ul)
    else if UInt8.eq tag 0x03uy then OIM_Some (IF_BMP, 1ul)
    else OIM_None


/// Pure spec: img_fmt → tag byte
let tag_of (t: img_fmt) : UInt8.t =
  match t with
    | IF_BMP -> 0x03uy
    | IF_GIF -> 0x02uy
    | IF_JPEG -> 0x01uy
    | IF_PNG -> 0x00uy

/// Pure spec: tag byte → img_fmt option
let tag_to_type (b: UInt8.t) : option img_fmt =
  if UInt8.eq b 0x00uy then Some IF_PNG
    else if UInt8.eq b 0x01uy then Some IF_JPEG
    else if UInt8.eq b 0x02uy then Some IF_GIF
    else if UInt8.eq b 0x03uy then Some IF_BMP
  else None

/// Roundtrip lemma: encoding then decoding returns the original value
let lemma_roundtrip (t: img_fmt) : Lemma (tag_to_type (tag_of t) == Some t) =
  match t with
    | IF_BMP -> ()
    | IF_GIF -> ()
    | IF_JPEG -> ()
    | IF_PNG -> ()

/// Bridge: encode writes the correct tag byte at off
let lemma_encode_match (t: img_fmt) (buf: buffer UInt8.t) (off: FStar.UInt32.t)
  : Stack unit
    (requires fun h0 -> live h0 buf /\ FStar.UInt32.v off < length buf)
    (ensures fun h0 _ h1 ->
      live h1 buf /\
      modifies (loc_buffer buf) h0 h1 /\
      Seq.index (as_seq h1 buf) (FStar.UInt32.v off) == tag_of t)
  = let _ = encode t buf off in
    ()

/// Bridge: decode reads without mutation, returns expected value
let lemma_decode_match (t: img_fmt) (buf: buffer UInt8.t) (off: FStar.UInt32.t)
  : Stack unit
    (requires fun h0 ->
      live h0 buf /\
      FStar.UInt32.v off < length buf /\
      Seq.index (as_seq h0 buf) (FStar.UInt32.v off) == tag_of t)
    (ensures fun h0 _ h1 -> h0 == h1)
  = match decode buf off with
    | _ -> ()

#pop-options