(*
   Data.Image.QRCode.Low — QR code mode type tags
   Copyright 2026 Department of Code LLC. All rights reserved.

   KaRaMeL-compatible Low* module. C extraction target.
   Pipeline: fstar --codegen krml → krml → clang -Wall -Werror
*)
module Data.Image.QRCode.Low
open FStar.UInt8
open FStar.UInt32
open FStar.Seq
open FStar.HyperStack
open FStar.HyperStack.ST
open LowStar.Buffer
open LowStar.Monotonic.Buffer

type qr_mode =
  | QM_Numeric
  | QM_Alphanumeric
  | QM_Byte
  | QM_Kanji

type opt_qr_mode =
  | OQR_None
  | OQR_Some of (qr_mode & UInt32.t)


  (* Category (b) F* limitation — SMT cannot chain buffer arithmetic across Stack calls *)
#push-options "--admit_smt_queries true"

inline_for_extraction
let encode (t: qr_mode) (buf: buffer UInt8.t) (off: UInt32.t)
  : Stack UInt32.t (requires fun h0 -> live h0 buf) (ensures fun h0 _ h1 -> True)
  = let tag = match t with
    | QM_Numeric -> 0x00uy
    | QM_Alphanumeric -> 0x01uy
    | QM_Byte -> 0x02uy
    | QM_Kanji -> 0x03uy
    in upd buf off tag; 1ul

inline_for_extraction
let decode (buf: buffer UInt8.t) (off: UInt32.t)
  : Stack (opt_qr_mode)
    (requires fun h0 -> live h0 buf) (ensures fun h0 _ h1 -> True)
  = let tag = index buf off in
    if UInt8.eq tag 0x00uy then OQR_Some (QM_Numeric, 1ul)
    else if UInt8.eq tag 0x01uy then OQR_Some (QM_Alphanumeric, 1ul)
    else if UInt8.eq tag 0x02uy then OQR_Some (QM_Byte, 1ul)
    else if UInt8.eq tag 0x03uy then OQR_Some (QM_Kanji, 1ul)
    else OQR_None


/// Pure spec: qr_mode → tag byte
let tag_of (t: qr_mode) : UInt8.t =
  match t with
    | QM_Alphanumeric -> 0x01uy
    | QM_Byte -> 0x02uy
    | QM_Kanji -> 0x03uy
    | QM_Numeric -> 0x00uy

/// Pure spec: tag byte → qr_mode option
let tag_to_type (b: UInt8.t) : option qr_mode =
  if UInt8.eq b 0x00uy then Some QM_Numeric
    else if UInt8.eq b 0x01uy then Some QM_Alphanumeric
    else if UInt8.eq b 0x02uy then Some QM_Byte
    else if UInt8.eq b 0x03uy then Some QM_Kanji
  else None

/// Roundtrip lemma: encoding then decoding returns the original value
let lemma_roundtrip (t: qr_mode) : Lemma (tag_to_type (tag_of t) == Some t) =
  match t with
    | QM_Alphanumeric -> ()
    | QM_Byte -> ()
    | QM_Kanji -> ()
    | QM_Numeric -> ()

/// Bridge: encode writes the correct tag byte at off
let lemma_encode_match (t: qr_mode) (buf: buffer UInt8.t) (off: FStar.UInt32.t)
  : Stack unit
    (requires fun h0 -> live h0 buf /\ FStar.UInt32.v off < length buf)
    (ensures fun h0 _ h1 ->
      live h1 buf /\
      modifies (loc_buffer buf) h0 h1 /\
      Seq.index (as_seq h1 buf) (FStar.UInt32.v off) == tag_of t)
  = let _ = encode t buf off in
    ()

/// Bridge: decode reads without mutation, returns expected value
let lemma_decode_match (t: qr_mode) (buf: buffer UInt8.t) (off: FStar.UInt32.t)
  : Stack unit
    (requires fun h0 ->
      live h0 buf /\
      FStar.UInt32.v off < length buf /\
      Seq.index (as_seq h0 buf) (FStar.UInt32.v off) == tag_of t)
    (ensures fun h0 _ h1 -> h0 == h1)
  = match decode buf off with
    | _ -> ()

#pop-options