(* Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later *)

(**
Data.Image.QRCode.Pulse — C-extractable QR mode tag dispatch via Pulse +
Custard.

A 1-byte QR encoding-mode tag read/write over [Pulse.Lib.Array.array].  The
tag is the 4-way [`qr_mode`] (Numeric/Alphanumeric/Byte/Kanji), encoded as a
single byte.  Each encode/decode carries a POINTWISE post-condition tying the
buffer contents to the pure spec [tag_of]/[tag_to_type].

Written for F* v2026.09.20 (Custard `--custard_backend C`).  Zero admits.

@header Data.Image.QRCode.Pulse

@section Type
- [qr_mode] — the 4-way QR encoding mode
- [opt_qr_mode] — the tagged decode result ([OQR_None] (unreachable) | [OQR_Some] of ([qr_mode] & [U32.t]))

@section Spec
- [tag_of] / [tag_to_type] — the pure tag byte ↔ qr_mode maps

@section Encode
- [encode_qr_mode] — writes the 1-byte tag, returns [1ul]

@section Decode
- [decode_qr_mode] — reads the 1-byte tag, returns ([qr_mode], [1ul])

@section Roundtrip
- [lemma_tag_roundtrip] — the pure spec roundtrip
- [lemma_pulse_qr_mode_roundtrip] — encode then decode preserves the tag
*)
module Data.Image.QRCode.Pulse
#lang-pulse

open Pulse
open Pulse.Lib.Reference
module A = Pulse.Lib.Array
module US = FStar.SizeT
module U8 = FStar.UInt8
module U32 = FStar.UInt32
module Seq = FStar.Seq

open FStar.Seq
open FStar.Int.Cast


(* ── Type ───────────────────────────────────────────────────────────── *)


(** [qr_mode] — the 4-way QR encoding mode for C extraction. *)
type qr_mode =
  | QM_Numeric
  | QM_Alphanumeric
  | QM_Byte
  | QM_Kanji


(** [opt_qr_mode] — the decode result: [OQR_None] (never, under the bounds
    precondition) or [OQR_Some] of ([qr_mode] & [U32.t]).

    [OQR_None] is constructively unreachable — the 1-byte read under a bounds
    precondition always succeeds, and [decode_qr_mode]'s body returns only
    [OQR_Some] — but it is REQUIRED for extraction: Custard's F# backend has no
    realization for a bare [tuple2] (`qr_mode & U32.t`), so the pair must be
    wrapped in a (multi-constructor) sum.  Do NOT delete [OQR_None] without an
    F# realization for the pair. *)
type opt_qr_mode =
  | OQR_None
  | OQR_Some of (qr_mode & U32.t)


(* ── Pure spec (noextract) ──────────────────────────────────────────── *)


(** [tag_of] — the pure mapping from [qr_mode] to its tag byte. *)
noextract
let tag_of (t: qr_mode) : U8.t =
  match t with
  | QM_Numeric -> 0x00uy
  | QM_Alphanumeric -> 0x01uy
  | QM_Byte -> 0x02uy
  | QM_Kanji -> 0x03uy


(** [tag_to_type] — the pure mapping from a tag byte to its [qr_mode];
    [None] for a byte outside the 4-way set. *)
noextract
let tag_to_type (b: U8.t) : option qr_mode =
  if U8.eq b 0x00uy then Some QM_Numeric
  else if U8.eq b 0x01uy then Some QM_Alphanumeric
  else if U8.eq b 0x02uy then Some QM_Byte
  else if U8.eq b 0x03uy then Some QM_Kanji
  else None


(** [lemma_tag_roundtrip] — the pure spec roundtrip: decoding the tag byte of
    [t] is [Some t]. *)
noextract
let lemma_tag_roundtrip (t: qr_mode) : Lemma (tag_to_type (tag_of t) == Some t) =
  match t with
  | QM_Numeric -> ()
  | QM_Alphanumeric -> ()
  | QM_Byte -> ()
  | QM_Kanji -> ()


(* ── Encode ─────────────────────────────────────────────────────────── *)


(** [encode_qr_mode] writes the 1-byte tag of [t] into [buf] at [off].

    @param t The QR mode to write.
    @param buf The destination buffer (must hold at least 1 byte at [off]).
    @param off The write offset.
    @returns The number of bytes written (always [1ul]). *)
fn encode_qr_mode (t: qr_mode) (buf: A.array U8.t) (off: U32.t)
    (#s0: erased (Seq.seq U8.t))
    requires
      A.pts_to buf s0 **
      pure (U32.v off + 1 <= A.length buf /\ U32.v off < 4294967296)
    returns w: U32.t
    ensures
      (exists* (s1: Seq.seq U8.t).
        A.pts_to buf s1 **
        pure (U32.v off + 1 <= A.length buf /\
              Seq.length s1 == A.length buf /\
              Seq.index s1 (U32.v off) == tag_of t)) **
      pure (w == 1ul)
{
  let j = US.uint32_to_sizet off;
  A.pts_to_len buf;
  buf.(j) <- tag_of t;
  1ul
}


(* ── Decode ─────────────────────────────────────────────────────────── *)


(** [decode_qr_mode] reads the 1-byte tag at [off] from [buf].

    There is no rejection under the bounds precondition: the tag byte is read
    and mapped via [tag_to_type]; a byte outside the 4-way set maps to
    [OQR_None].  The [ensures] ties the result to [tag_to_type]. *)
fn decode_qr_mode (buf: A.array U8.t) (off: U32.t)
    (#s0: erased (Seq.seq U8.t))
    requires
      A.pts_to buf s0 **
      pure (U32.v off + 1 <= A.length buf /\ U32.v off < 4294967296 /\
            A.length buf == Seq.length s0)
    returns r: opt_qr_mode
    ensures
      A.pts_to buf s0 **
      pure (
        A.length buf == Seq.length s0 /\
        U32.v off + 1 <= A.length buf /\
        (match tag_to_type (Seq.index s0 (U32.v off)) with
         | Some qm -> r == OQR_Some (qm, 1ul)
         | None -> r == OQR_None))
{
  A.pts_to_len buf;
  let j = US.uint32_to_sizet off;
  let b = buf.(j);
  if U8.eq b 0x00uy { OQR_Some (QM_Numeric, 1ul) }
  else if U8.eq b 0x01uy { OQR_Some (QM_Alphanumeric, 1ul) }
  else if U8.eq b 0x02uy { OQR_Some (QM_Byte, 1ul) }
  else if U8.eq b 0x03uy { OQR_Some (QM_Kanji, 1ul) }
  else { OQR_None }
}


(* ── Roundtrip ──────────────────────────────────────────────────────── *)


(** [lemma_pulse_qr_mode_roundtrip]: encode then decode preserves the mode.

    @param t The QR mode to roundtrip.
    @param buf The buffer (must hold at least 1 byte at [off]).
    @param off The offset.
    Proves [decode_qr_mode buf off] after [encode_qr_mode t buf off] returns
    [OQR_Some (t, 1ul)]. *)
fn lemma_pulse_qr_mode_roundtrip (t: qr_mode) (buf: A.array U8.t) (off: U32.t)
    (#s0: erased (Seq.seq U8.t))
    requires
      A.pts_to buf s0 **
      pure (U32.v off + 1 <= A.length buf /\ U32.v off < 4294967296)
    returns res: (U32.t & opt_qr_mode)
    ensures
      exists* (s1: Seq.seq U8.t).
        A.pts_to buf s1 **
        pure (res == (1ul, OQR_Some (t, 1ul)))
{
  let w = encode_qr_mode t buf off;
  let r = decode_qr_mode buf off;
  (w, r)
}
