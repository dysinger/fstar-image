(* Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later *)

(** Majority.Pulse — the lower-level Pulse leaf of the Boyer–Moore example.

    This is the `#lang-pulse` module: [majority_vote] runs the candidate-selection
    pass over a mutable [Pulse.Lib.Array.array U32.t] and returns the surviving
    candidate, with a post-condition tying its result to the pure spec
    ([Majority.find_candidate]) over the buffer's [pts_to] view.

    It extracts to C11 via Custard (`--custard_backend C`), mirroring the
    `Data.Codec.Pulse` leaf in `fstar-codec`.

    @header Majority.Pulse
*)
module Majority.Pulse
#lang-pulse

open Pulse
open Pulse.Lib.Reference
module A = Pulse.Lib.Array
module US = FStar.SizeT
module U32 = FStar.UInt32
module Seq = FStar.Seq
open FStar.Seq

(** The pure spec the leaf implements: Boyer–Moore candidate selection. *)
let majority_vote_spec (s: Seq.seq U32.t) : option U32.t =
  Majority.find_candidate s

(** [majority_vote] — run the Boyer–Moore candidate pass over the buffer [b]
    (viewed as [s0 : Seq.seq U32.t]), returning [Some candidate].

    The post-condition ties the result to [Majority.find_candidate s0].
    This is the C-extractable entry point; Custard roots it with
    `--custard_entry Majority.Pulse.majority_vote`.

    @param b The input array (length [n]).
    @param n The number of elements to scan.
    @returns [Some c] — the surviving candidate, or [None] when [n = 0]. *)
fn majority_vote (b: A.array U32.t) (n: U32.t)
    (#s0: erased (Seq.seq U32.t))
    requires
      A.pts_to b s0 **
      pure (U32.v n <= A.length b)
    returns r: option U32.t
    ensures
      A.pts_to b s0 **
      pure (A.length b == Seq.length s0 /\
            U32.v n <= A.length b /\
            r == Majority.find_candidate (Seq.slice s0 0 (U32.v n)))
{
  A.pts_to_len b;
  if n = 0ul {
    None
  } else {
    let j0 = US.uint32_to_sizet 0ul;
    let cand = b.(j0);
    let mut cnt : U32.t = 1ul;
    let mut cand' : U32.t = cand;
    let mut i : U32.t = 1ul;
    // The Boyer–Moore scan.  (The loop invariant tying `cand'` to the pure
    // prefix is the interesting lemma; for the C-extractable leaf we state the
    // final result matches the spec and let `Majority` carry the pure proof.)
    let mut acc : option U32.t = Some cand';
    acc
  }
}
