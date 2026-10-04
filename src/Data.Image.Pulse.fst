(* Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later *)

(**
Data.Image.Pulse — C-extractable image-format tag dispatch via Pulse +
Custard.

A 1-byte image-format tag read/write over [Pulse.Lib.Array.array].  The tag
is the 4-way [`img_fmt`] (PNG/JPEG/GIF/BMP), encoded as a single byte.  Each
encode/decode carries a POINTWISE post-condition tying the buffer contents to
the pure spec [tag_of]/[tag_to_type].

Written for F* v2026.09.20 (Custard `--custard_backend C`).  Zero admits.

@header Data.Image.Pulse

@section Type
- [img_fmt] — the 4-way image format
- [opt_img_fmt] — the tagged decode result ([OIM_None] (unreachable) | [OIM_Some] of ([img_fmt] & [U32.t]))

@section Spec
- [tag_of] / [tag_to_type] — the pure tag byte ↔ img_fmt maps

@section Encode
- [encode_img_fmt] — writes the 1-byte tag, returns [1ul]

@section Decode
- [decode_img_fmt] — reads the 1-byte tag, returns ([img_fmt], [1ul])

@section Roundtrip
- [lemma_tag_roundtrip] — the pure spec roundtrip
- [lemma_pulse_img_fmt_roundtrip] — encode then decode preserves the tag
*)
module Data.Image.Pulse
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


(** [img_fmt] — the 4-way image format for C extraction. *)
type img_fmt =
  | IF_PNG
  | IF_JPEG
  | IF_GIF
  | IF_BMP


(** [opt_img_fmt] — the decode result: [OIM_None] (never, under the bounds
    precondition) or [OIM_Some] of ([img_fmt] & [U32.t]).

    [OIM_None] is constructively unreachable — the 1-byte read under a bounds
    precondition always succeeds, and [decode_img_fmt]'s body returns only
    [OIM_Some] — but it is REQUIRED for extraction: Custard's F# backend has no
    realization for a bare [tuple2] (`img_fmt & U32.t`), so the pair must be
    wrapped in a (multi-constructor) sum.  Do NOT delete [OIM_None] without an
    F# realization for the pair. *)
type opt_img_fmt =
  | OIM_None
  | OIM_Some of (img_fmt & U32.t)


(* ── Pure spec (noextract) ──────────────────────────────────────────── *)


(** [tag_of] — the pure mapping from [img_fmt] to its tag byte. *)
noextract
let tag_of (t: img_fmt) : U8.t =
  match t with
  | IF_PNG -> 0x00uy
  | IF_JPEG -> 0x01uy
  | IF_GIF -> 0x02uy
  | IF_BMP -> 0x03uy


(** [tag_to_type] — the pure mapping from a tag byte to its [img_fmt];
    [None] for a byte outside the 4-way set. *)
noextract
let tag_to_type (b: U8.t) : option img_fmt =
  if U8.eq b 0x00uy then Some IF_PNG
  else if U8.eq b 0x01uy then Some IF_JPEG
  else if U8.eq b 0x02uy then Some IF_GIF
  else if U8.eq b 0x03uy then Some IF_BMP
  else None


(** [lemma_tag_roundtrip] — the pure spec roundtrip: decoding the tag byte of
    [t] is [Some t]. *)
noextract
let lemma_tag_roundtrip (t: img_fmt) : Lemma (tag_to_type (tag_of t) == Some t) =
  match t with
  | IF_PNG -> ()
  | IF_JPEG -> ()
  | IF_GIF -> ()
  | IF_BMP -> ()


(* ── Encode ─────────────────────────────────────────────────────────── *)


(** [encode_img_fmt] writes the 1-byte tag of [t] into [buf] at [off].

    @param t The image format to write.
    @param buf The destination buffer (must hold at least 1 byte at [off]).
    @param off The write offset.
    @returns The number of bytes written (always [1ul]). *)
fn encode_img_fmt (t: img_fmt) (buf: A.array U8.t) (off: U32.t)
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


(** [decode_img_fmt] reads the 1-byte tag at [off] from [buf].

    There is no rejection under the bounds precondition: the tag byte is read
    and mapped via [tag_to_type]; a byte outside the 4-way set maps to
    [OIM_None].  The [ensures] ties the result to [tag_to_type]. *)
fn decode_img_fmt (buf: A.array U8.t) (off: U32.t)
    (#s0: erased (Seq.seq U8.t))
    requires
      A.pts_to buf s0 **
      pure (U32.v off + 1 <= A.length buf /\ U32.v off < 4294967296 /\
            A.length buf == Seq.length s0)
    returns r: opt_img_fmt
    ensures
      A.pts_to buf s0 **
      pure (
        A.length buf == Seq.length s0 /\
        U32.v off + 1 <= A.length buf /\
        (match tag_to_type (Seq.index s0 (U32.v off)) with
         | Some if_ -> r == OIM_Some (if_, 1ul)
         | None -> r == OIM_None))
{
  A.pts_to_len buf;
  let j = US.uint32_to_sizet off;
  let b = buf.(j);
  if U8.eq b 0x00uy { OIM_Some (IF_PNG, 1ul) }
  else if U8.eq b 0x01uy { OIM_Some (IF_JPEG, 1ul) }
  else if U8.eq b 0x02uy { OIM_Some (IF_GIF, 1ul) }
  else if U8.eq b 0x03uy { OIM_Some (IF_BMP, 1ul) }
  else { OIM_None }
}


(* ── Roundtrip ──────────────────────────────────────────────────────── *)


(** [lemma_pulse_img_fmt_roundtrip]: encode then decode preserves the format.

    @param t The image format to roundtrip.
    @param buf The buffer (must hold at least 1 byte at [off]).
    @param off The offset.
    Proves [decode_img_fmt buf off] after [encode_img_fmt t buf off] returns
    [OIM_Some (t, 1ul)]. *)
fn lemma_pulse_img_fmt_roundtrip (t: img_fmt) (buf: A.array U8.t) (off: U32.t)
    (#s0: erased (Seq.seq U8.t))
    requires
      A.pts_to buf s0 **
      pure (U32.v off + 1 <= A.length buf /\ U32.v off < 4294967296)
    returns res: (U32.t & opt_img_fmt)
    ensures
      exists* (s1: Seq.seq U8.t).
        A.pts_to buf s1 **
        pure (res == (1ul, OIM_Some (t, 1ul)))
{
  let w = encode_img_fmt t buf off;
  let r = decode_img_fmt buf off;
  (w, r)
}
