(* Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later *)

(** Example.Majority — the pure Boyer–Moore majority-vote algorithm.

    Boyer–Moore is the classic linear-time, constant-space algorithm for
    finding a majority element.  It has two passes:

      1. **candidate selection** ([find_candidate]) — scan the sequence once,
         maintaining a candidate and a counter.  When a new element matches the
         candidate, increment; otherwise decrement; when the counter hits zero,
         replace the candidate.  After the pass, *if* the sequence has a
         majority element, that majority is necessarily the surviving candidate.
      2. **verification** ([verify]) — count the candidate's occurrences and
         confirm it is a strict majority.

    This module is the *pure algorithm layer*: total functions over
    [Seq.seq Example.Majority.Types.elem] with no heap.  The corresponding
    Pulse leaf ([Example.Majority.Pulse]) re-implements the same pass over a
    mutable array and ties its result back to this pure spec by a lemma.

    The deep Boyer–Moore invariant ("the surviving candidate is the only
    possible majority") is *stated in prose* below and exercised on concrete
    vectors in the test module; this template's *proven* lemma is the
    verification-pass correspondence, which is the definitional part of the
    algorithm and is discharged by reduction.

    @header Example.Majority
*)
module Example.Majority

open FStar.Seq
open FStar.UInt32
open FStar.List.Tot

module U32 = FStar.UInt32
module Seq = FStar.Seq
open Example.Majority.Types

(** [candidate_step] — one step of the Boyer–Moore scan.

    State is [(cand, count)]: the current candidate and the current counter.
    Processing element [x]:
      - if the counter is 0, the new candidate is [x] and the counter is 1;
      - else if [x] equals the candidate, increment the counter;
      - else decrement the counter.

    This is the *pure* one-step transition; [find_candidate] folds it over the
    whole sequence. *)
let candidate_step (cand: elem) (cnt: nat) (x: elem) : elem & nat =
  if cnt = 0 then (x, 1)
  else if cand = x then (cand, cnt + 1)
  else (cand, cnt - 1)

(** The extracted result of one Boyer–Moore step: a candidate + counter pair.
    A record (rather than a bare tuple) so Custard's F# backend has a
    realization for it (tuples over [U32.t] are hand-written OCaml with no F#
    counterpart — section 122.9). *)
noeq type step_result = {
  step_cand: elem;
  step_cnt: U32.t;
}

(** [candidate_step_u32] — the same one-step transition on an extractable
    [U32.t] counter, so the Pulse leaf can use it directly.  The precondition
    [U32.v cnt + 1 < 2^32] makes the increment total (no overflow); the
    postcondition ties the result to the pure [candidate_step] via [U32.v].
    A documented restriction: the scan length [n] must satisfy
    [U32.v n < 2^32 - 1] so the counter never wraps (see [majority_vote]). *)
let candidate_step_u32 (cand: elem) (cnt: U32.t) (x: elem)
  : Pure step_result
      (requires U32.v cnt + 1 < 4294967296)
      (ensures fun r ->
        r.step_cand == fst (candidate_step cand (U32.v cnt) x)
        /\ U32.v r.step_cnt == snd (candidate_step cand (U32.v cnt) x))
  =
  if U32.eq cnt 0ul then { step_cand = x; step_cnt = 1ul }
  else if U32.eq cand x then { step_cand = cand; step_cnt = U32.add cnt 1ul }
  else { step_cand = cand; step_cnt = U32.sub cnt 1ul }

(** [find_candidate s] — the candidate-selection pass.

    Returns [Some c] if a candidate survives (the counter never collapsed to
    zero at the very end), or [None] if the final counter is zero.  The
    returned candidate is the *only* element that can be a majority of [s]
    (see the invariant note above; the implication is exercised concretely in
    the test module). *)
(** [bm_scan s lo hi cand cnt] — the Boyer–Moore candidate-selection fold,
    expressed *by index* over the sequence (so the Pulse leaf's per-iteration
    state [(candidate, counter, index)] maps one-to-one onto it).  It scans
    [s[lo .. hi)] left to right, threading [(candidate, counter)] through
    [candidate_step], and returns the surviving [(candidate, counter)] pair.

    Lo is the index of the *next* element to read; the first element [s[0]]
    is the caller's starting candidate (with counter 1), so a full pass is
    [bm_scan s 1 (Seq.length s) (Seq.index s 0) 1]. *)
let rec bm_scan (s: Seq.seq elem) (lo: nat) (hi: nat { lo <= hi /\ hi <= Seq.length s }) (cand: elem) (cnt: nat)
  : Tot (elem & nat) (decreases (hi - lo))
  = if lo = hi then (cand, cnt)
    else
      let c, k = candidate_step cand cnt (Seq.index s lo) in
      bm_scan s (lo + 1) hi c k

(** One-step unfold of [bm_scan]: reading [s[lo]] folds exactly one
    [candidate_step] before scanning [s[lo+1 .. hi)].  This is the loop-body
    equation the Pulse leaf's invariant preservation reduces to; it is stated
    with an SMTPat so it fires inside the [while] loop's proof. *)
let lemma_bm_scan_step (s: Seq.seq elem) (lo: nat) (hi: nat { lo < hi /\ hi <= Seq.length s }) (cand: elem) (cnt: nat)
  : Lemma (bm_scan s lo hi cand cnt
           == (let c, k = candidate_step cand cnt (Seq.index s lo) in
               bm_scan s (lo + 1) hi c k))
          [SMTPat (bm_scan s lo hi cand cnt)]
  = ()

(** [bm_scan] over a prefix slice reads exactly the same elements as [bm_scan]
    over the parent sequence (indices are into the shared prefix [s[0..hi)]),
    so the results coincide.  This is the bridge the Pulse leaf needs to tie
    its post-loop candidate (computed over [s0]) back to the spec
    [find_candidate (Seq.slice s0 0 n)]. *)
let rec lemma_bm_scan_slice (s: Seq.seq elem) (n: nat { n <= Seq.length s }) (lo: nat) (hi: nat { lo <= hi /\ hi <= n }) (cand: elem) (cnt: nat)
  : Lemma (bm_scan (Seq.slice s 0 n) lo hi cand cnt == bm_scan s lo hi cand cnt)
          (decreases (hi - lo))
  = if lo = hi then ()
    else
      lemma_bm_scan_slice s n (lo + 1) hi (fst (candidate_step cand cnt (Seq.index s lo))) (snd (candidate_step cand cnt (Seq.index s lo)))

let find_candidate (s: Seq.seq elem) : option elem =
  if Seq.length s = 0 then None
  else Some (fst (bm_scan s 1 (Seq.length s) (Seq.index s 0) 1))

(** The candidate pass over a non-empty prefix slice [s[0..n)] is the first
    component of [bm_scan] over the full sequence — the exact equation the
    Pulse leaf's post-condition reduces to after its loop. *)
let lemma_find_candidate_slice (s: Seq.seq elem) (n: nat { 0 < n /\ n <= Seq.length s })
  : Lemma (find_candidate (Seq.slice s 0 n) == Some (fst (bm_scan s 1 n (Seq.index s 0) 1)))
          [SMTPat (find_candidate (Seq.slice s 0 n))]
  = lemma_bm_scan_slice s n 1 n (Seq.index s 0) 1

(** [verify x s] — the verification pass: does [x] actually appear more than
    [|s| / 2] times? *)
let verify (x: elem) (s: Seq.seq elem) : bool =
  count x s > Seq.length s / 2

(** The verification pass is the algorithm's ground truth: [verify x s] is
    true exactly when [x] is a majority of [s].  This is the spec↔impl
    correspondence lemma — [verify] *is* [majority], so the proof reduces. *)
let lemma_verify_is_majority (x: elem) (s: Seq.seq elem)
  : Lemma (verify x s == true <==> majority x s)
  = ()

(** Boyer–Moore is sound for the *complete* two-pass procedure: when the
    candidate pass returns [Some c], running the verification pass on [c]
    decides whether [c] is a majority.  (The candidate-uniqueness direction
    — that *if* any majority exists it is [c] — is the pairing invariant
    stated above and exercised on vectors in the test module.) *)
let lemma_two_pass_sound (s: Seq.seq elem) (c: elem)
  : Lemma
    (requires find_candidate s == Some c)
    (ensures (verify c s == true <==> majority c s))
  = lemma_verify_is_majority c s
