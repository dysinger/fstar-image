(* Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later *)

(** Example.Majority.Pulse — the lower-level Pulse leaf of the Boyer–Moore example.

    This is the `#lang-pulse` module: [majority_vote] runs the candidate-selection
    pass over a mutable [Pulse.Lib.Array.array U32.t] and returns the surviving
    candidate, with a post-condition tying its result to the pure spec
    ([Example.Majority.find_candidate]) over the buffer's [pts_to] view.

    The scan is *read-only* over the buffer: Boyer–Moore candidate selection
    never writes, so the buffer's view is threaded through unchanged ([s == s0]
    throughout) and the `while` loop keeps its per-iteration state (candidate,
    counter, index) in three stack `ref`s.  The invariant ties that state to
    [Example.Majority.bm_scan] over the scanned prefix, which is exactly the
    hoisted pure fold [Example.Majority.find_candidate] performs.

    It extracts to C11 via Custard (`--custard_backend C`), mirroring the
    `Data.Codec.Pulse` leaf in `fstar-codec`.

    @header Example.Majority.Pulse
*)
module Example.Majority.Pulse
#lang-pulse

open Pulse
open Pulse.Lib.Reference
module A = Pulse.Lib.Array
module R = Pulse.Lib.Reference
module US = FStar.SizeT
module U32 = FStar.UInt32
module Seq = FStar.Seq
open FStar.Seq
open Example.Majority.Types

(** The pure spec the leaf implements: Boyer–Moore candidate selection. *)
let majority_vote_spec (s: Seq.seq U32.t) : vote_result =
  vote_result_of_option (Example.Majority.find_candidate s)

(** [majority_vote] — run the Boyer–Moore candidate pass over the buffer [b]
    (viewed as [s0 : Seq.seq U32.t]), returning [Some candidate].

    The post-condition ties the result to [Example.Majority.find_candidate s0].
    This is the C-extractable entry point; Custard roots it with
    `--custard_entry Example.Majority.Pulse.majority_vote`.

    @param b The input array (length at least [n]).
    @param n The number of elements to scan.
    @returns [VR_Majority c] — the surviving candidate, or [VR_NoMajority]
             when [n = 0]. *)
divergent
fn majority_vote (b: A.array U32.t) (n: U32.t)
    (#p: perm)
    (#s0: erased (Seq.seq U32.t))
    requires
      A.pts_to b #p s0 **
      pure (U32.v n <= A.length b /\ U32.v n < 4294967295)
    returns r: vote_result
    ensures
      A.pts_to b #p s0 **
      pure (A.length b == Seq.length s0 /\
            U32.v n <= A.length b /\
            r == vote_result_of_option (Example.Majority.find_candidate (Seq.slice s0 0 (U32.v n))))
{
  A.pts_to_len b;
  if U32.eq n 0ul {
    VR_NoMajority
  } else {
    // b is non-empty: read the first element as the initial candidate.
    let j0 = US.uint32_to_sizet 0ul;
    let cand = b.(j0);
    let mut cand' : U32.t = cand;
    let mut cnt : U32.t = 1ul;
    let mut i : U32.t = 1ul;

    // The Boyer–Moore scan.  The invariant ties `cand'`/`cnt` to the pure
    // [Example.Majority.bm_scan] fold over the scanned prefix, so the final
    // candidate matches [Example.Majority.find_candidate (Seq.slice s0 0 n)].
    while (let vi = !i; U32.lt vi n)
      invariant exists* (s: Seq.seq U32.t) (vi: U32.t) (vc: U32.t) (vcc: U32.t).
        A.pts_to b #p s **
        pts_to i vi **
        pts_to cand' vc **
        pts_to cnt vcc **
        pure (
          Seq.length s == A.length b /\
          Seq.equal s s0 /\
          1 <= U32.v vi /\
          U32.v vi <= U32.v n /\
          U32.v vcc <= U32.v vi /\
          U32.v vcc + 1 < 4294967296 /\
          U32.v n <= A.length b /\
          Example.Majority.bm_scan s0 1 (U32.v n) (Seq.index s0 0) 1
            == Example.Majority.bm_scan s0 (U32.v vi) (U32.v n) vc (U32.v vcc)
        )
    {
      let vi = !i;
      let vc = !cand';
      let vcc = !cnt;
      let j = US.uint32_to_sizet vi;
      let x = b.(j);
      // Apply one candidate_step (the U32 form, proven to agree with the pure
      // [candidate_step] on the projection) and write the new state back.
      let st = Example.Majority.candidate_step_u32 vc vcc x;
      cand' := st.step_cand;
      cnt := st.step_cnt;
      i := U32.add_mod vi 1ul
    };

    let result = !cand';
    VR_Majority result
  }
}
