(*
   Data.Image.PNG.Filter — PNG filter algorithms
   Copyright 2026 Department of Code LLC. All rights reserved.

   Implements PNG filter types per ISO/IEC 15948:2004 section 9.
   All five filter types (None/Sub/Up/Average/Paeth) fully verified 0-admit:
   encode transforms, inverse reconstruct transforms, and symbolic roundtrips
   (induction on the row, `bpp > 0`, `length cur = length prev`).
*)
module Data.Image.PNG.Filter

open Data.Codec
open Data.Image
open FStar.List.Tot
open FStar.UInt8

(* ========================================================================
   SECTION 1: Filter Type
   ======================================================================== *)

type filter_type =
  | FilterNone
  | FilterSub
  | FilterUp
  | FilterAverage
  | FilterPaeth

let filter_byte (f: filter_type) : byte =
  match f with
  | FilterNone    -> 0x00uy
  | FilterSub     -> 0x01uy
  | FilterUp      -> 0x02uy
  | FilterAverage -> 0x03uy
  | FilterPaeth   -> 0x04uy

(* ========================================================================
   SECTION 2: Helpers — safe byte indexing + predictors
   ======================================================================== *)

/// Safe byte list indexing: return element [i] (0-based), or `0x00uy` if
/// out of range.
let nth_byte (l: list byte) (i: nat) : byte =
  match List.Tot.nth l i with
  | Some b -> b
  | None   -> 0x00uy

/// [take l n] — the first [n] elements of [l] (truncated if [n > length l]).
let rec take (l: list byte) (n: nat) : Tot (list byte) (decreases n) =
  if n = 0 then [] else match l with [] -> [] | x :: xs -> x :: take xs (n - 1)

/// [drop l n] — [l] with its first [n] elements removed.
let rec drop (l: list byte) (n: nat) : Tot (list byte) (decreases n) =
  if n = 0 then l else match l with [] -> [] | x :: xs -> drop xs (n - 1)

/// Paeth predictor (ISO/IEC 15948:2004 §9, "nearest to a + b - c").
let paeth_predictor (a b c: byte) : byte =
  let v_a = v a in
  let v_b = v b in
  let v_c = v c in
  let p  = v_a + v_b - v_c in
  let pa = abs (p - v_a) in
  let pb = abs (p - v_b) in
  let pc = abs (p - v_c) in
  if pa <= pb && pa <= pc then a
  else if pb <= pc then b
  else c

/// Average predictor: floor((a + b) / 2) as a byte.
let avg_predictor (a b: byte) : byte =
  uint_to_t ((v a + v b) / 2)

(* ========================================================================
   SECTION 3: Filter Encode — filter_scanline
   ======================================================================== *)

(* Each transform consumes [cur] (the unconsumed tail of the row), threads the
   full original row [orig] for left-neighbour lookups, the prior row [prev],
   and [i] the 0-based index of the head of [cur].  Output is built in FORWARD
   order with cons (cons-only — fstar-proofs §14). *)

let rec filter_sub_aux (orig cur prev: list byte) (bpp i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> []
  | x :: xs ->
    let a = if i >= bpp then nth_byte orig (i - bpp) else 0x00uy in
    (sub_mod x a) :: filter_sub_aux orig xs prev bpp (i + 1)

let rec filter_up_aux (orig cur prev: list byte) (bpp i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> []
  | x :: xs ->
    let b = nth_byte prev i in
    (sub_mod x b) :: filter_up_aux orig xs prev bpp (i + 1)

let rec filter_average_aux (orig cur prev: list byte) (bpp i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> []
  | x :: xs ->
    let a = if i >= bpp then nth_byte orig (i - bpp) else 0x00uy in
    let b = nth_byte prev i in
    (sub_mod x (avg_predictor a b)) :: filter_average_aux orig xs prev bpp (i + 1)

let rec filter_paeth_aux (orig cur prev: list byte) (bpp i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> []
  | x :: xs ->
    let a = if i >= bpp then nth_byte orig (i - bpp) else 0x00uy in
    let b = nth_byte prev i in
    let c = if i >= bpp then nth_byte prev (i - bpp) else 0x00uy in
    (sub_mod x (paeth_predictor a b c)) :: filter_paeth_aux orig xs prev bpp (i + 1)

let filter_scanline (f: filter_type) (cur: list byte) (prev: list byte) (bpp: nat)
  : list byte =
  match f with
  | FilterNone ->
    filter_byte FilterNone :: cur
  | FilterSub ->
    filter_byte FilterSub :: filter_sub_aux cur cur prev bpp 0
  | FilterUp ->
    filter_byte FilterUp :: filter_up_aux cur cur prev bpp 0
  | FilterAverage ->
    filter_byte FilterAverage :: filter_average_aux cur cur prev bpp 0
  | FilterPaeth ->
    filter_byte FilterPaeth :: filter_paeth_aux cur cur prev bpp 0

(* ========================================================================
   SECTION 4: Filter Decode — reconstruct_scanline
   ======================================================================== *)

(* Each reconstruct transform consumes [cur] (the unconsumed tail of the
   filtered row) and rebuilds the original row in FORWARD order, threading the
   accumulator [acc] holding the already-reconstructed prefix.  The left
   neighbour [a] is therefore [nth_byte acc (i - bpp)] (a forward index). *)

let rec reconstruct_sub_aux (cur prev: list byte) (bpp: nat) (acc: list byte) (i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> acc
  | x :: xs ->
    let a = if i >= bpp then nth_byte acc (i - bpp) else 0x00uy in
    reconstruct_sub_aux xs prev bpp (acc @ [add_mod x a]) (i + 1)

let rec reconstruct_up_aux (cur prev: list byte) (bpp: nat) (acc: list byte) (i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> acc
  | x :: xs ->
    let b = nth_byte prev i in
    reconstruct_up_aux xs prev bpp (acc @ [add_mod x b]) (i + 1)

let rec reconstruct_average_aux (cur prev: list byte) (bpp: nat) (acc: list byte) (i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> acc
  | x :: xs ->
    let a = if i >= bpp then nth_byte acc (i - bpp) else 0x00uy in
    let b = nth_byte prev i in
    reconstruct_average_aux xs prev bpp (acc @ [add_mod x (avg_predictor a b)]) (i + 1)

let rec reconstruct_paeth_aux (cur prev: list byte) (bpp: nat) (acc: list byte) (i: nat)
  : Tot (list byte) (decreases cur) =
  match cur with
  | [] -> acc
  | x :: xs ->
    let a = if i >= bpp then nth_byte acc (i - bpp) else 0x00uy in
    let b = nth_byte prev i in
    let c = if i >= bpp then nth_byte prev (i - bpp) else 0x00uy in
    reconstruct_paeth_aux xs prev bpp (acc @ [add_mod x (paeth_predictor a b c)]) (i + 1)

let reconstruct_scanline (f: filter_type) (cur: list byte) (prev: list byte) (bpp: nat)
  : option (list byte) =
  match cur with
  | [] -> None
  | fb :: filtered ->
    if fb = filter_byte f then
      match f with
      | FilterNone -> Some filtered
      | FilterSub -> Some (reconstruct_sub_aux filtered prev bpp [] 0)
      | FilterUp -> Some (reconstruct_up_aux filtered prev bpp [] 0)
      | FilterAverage -> Some (reconstruct_average_aux filtered prev bpp [] 0)
      | FilterPaeth -> Some (reconstruct_paeth_aux filtered prev bpp [] 0)
    else None

(* ========================================================================
   SECTION 5: Index / take / drop lemmas
   ======================================================================== *)

/// The wrapping-arithmetic roundtrip identity (FStar.UInt, lifted to [t] via
/// [v_inj]).
let lemma_wrap (a b: byte) : Lemma (add_mod (sub_mod a b) b == a) =
  FStar.UInt.lemma_add_sub_cancel #8 (v a) (v b);
  v_inj (add_mod (sub_mod a b) b) a

let rec lemma_nth_take (l: list byte) (n i: nat)
  : Lemma (requires i < n /\ n <= length l)
          (ensures nth_byte (take l n) i == nth_byte l i)
          (decreases i)
  = if i = 0 then () else lemma_nth_take (tl l) (n - 1) (i - 1)

let rec lemma_drop_all (l: list byte)
  : Lemma (ensures drop l (length l) == []) (decreases l)
  = match l with
    | [] -> ()
    | _ :: tl -> lemma_drop_all tl

let rec lemma_take_all (l: list byte)
  : Lemma (ensures take l (length l) == l) (decreases l)
  = match l with
    | [] -> ()
    | _ :: tl -> lemma_take_all tl

let rec lemma_take_cons (l: list byte) (n: nat)
  : Lemma (requires n < length l)
          (ensures take l (n + 1) == take l n @ [nth_byte l n])
          (decreases n)
  = if n = 0 then () else lemma_take_cons (tl l) (n - 1)

let rec lemma_drop_cons (l: list byte) (n: nat)
  : Lemma (requires n < length l)
          (ensures drop l n == nth_byte l n :: drop l (n + 1))
          (decreases n)
  = if n = 0 then () else lemma_drop_cons (tl l) (n - 1)

(* ========================================================================
   SECTION 6: Roundtrip lemmas (per filter)
   ======================================================================== *)

/// Sub filter roundtrip (induction on the row, `bpp > 0`).
let rec lemma_sub_rt (row prev: list byte) (bpp: nat{bpp > 0}) (i: nat)
  : Lemma (requires length row = length prev /\ i <= length row)
          (ensures reconstruct_sub_aux (filter_sub_aux row (drop row i) prev bpp i)
                      prev bpp (take row i) i == row)
          (decreases (length row - i))
  =
  if i = length row then begin
    lemma_drop_all row;
    lemma_take_all row;
    assert (drop row i == []);
    assert (take row i == row)
  end
  else begin
    let x = nth_byte row i in
    lemma_drop_cons row i;
    if i >= bpp then lemma_nth_take row i (i - bpp);
    lemma_wrap x (if i >= bpp then nth_byte row (i - bpp) else 0x00uy);
    lemma_take_cons row i;
    lemma_sub_rt row prev bpp (i + 1)
  end

/// Up filter roundtrip (induction on the row, `bpp > 0`).
let rec lemma_up_rt (row prev: list byte) (bpp: nat{bpp > 0}) (i: nat)
  : Lemma (requires length row = length prev /\ i <= length row)
          (ensures reconstruct_up_aux (filter_up_aux row (drop row i) prev bpp i)
                      prev bpp (take row i) i == row)
          (decreases (length row - i))
  =
  if i = length row then begin
    lemma_drop_all row;
    lemma_take_all row;
    assert (drop row i == []);
    assert (take row i == row)
  end
  else begin
    let x = nth_byte row i in
    lemma_drop_cons row i;
    lemma_wrap x (nth_byte prev i);
    lemma_take_cons row i;
    lemma_up_rt row prev bpp (i + 1)
  end

/// Average filter roundtrip (induction on the row, `bpp > 0`).
let rec lemma_average_rt (row prev: list byte) (bpp: nat{bpp > 0}) (i: nat)
  : Lemma (requires length row = length prev /\ i <= length row)
          (ensures reconstruct_average_aux (filter_average_aux row (drop row i) prev bpp i)
                      prev bpp (take row i) i == row)
          (decreases (length row - i))
  =
  if i = length row then begin
    lemma_drop_all row;
    lemma_take_all row;
    assert (drop row i == []);
    assert (take row i == row)
  end
  else begin
    let x = nth_byte row i in
    lemma_drop_cons row i;
    if i >= bpp then lemma_nth_take row i (i - bpp);
    lemma_wrap x (avg_predictor (if i >= bpp then nth_byte row (i - bpp) else 0x00uy)
                                (nth_byte prev i));
    lemma_take_cons row i;
    lemma_average_rt row prev bpp (i + 1)
  end

/// Paeth filter roundtrip (induction on the row, `bpp > 0`).
let rec lemma_paeth_rt (row prev: list byte) (bpp: nat{bpp > 0}) (i: nat)
  : Lemma (requires length row = length prev /\ i <= length row)
          (ensures reconstruct_paeth_aux (filter_paeth_aux row (drop row i) prev bpp i)
                      prev bpp (take row i) i == row)
          (decreases (length row - i))
  =
  if i = length row then begin
    lemma_drop_all row;
    lemma_take_all row;
    assert (drop row i == []);
    assert (take row i == row)
  end
  else begin
    let x = nth_byte row i in
    lemma_drop_cons row i;
    if i >= bpp then lemma_nth_take row i (i - bpp);
    lemma_wrap x (paeth_predictor (if i >= bpp then nth_byte row (i - bpp) else 0x00uy)
                                  (nth_byte prev i)
                                  (if i >= bpp then nth_byte prev (i - bpp) else 0x00uy));
    lemma_take_cons row i;
    lemma_paeth_rt row prev bpp (i + 1)
  end

/// The full filter roundtrip for all five filter types.
let lemma_filter_roundtrip (f: filter_type) (cur prev: list byte) (bpp: nat)
  : Lemma
    (requires length cur = length prev /\ bpp > 0)
    (ensures reconstruct_scanline f (filter_scanline f cur prev bpp) prev bpp == Some cur) =
  match f with
  | FilterNone -> ()
  | FilterSub ->
    lemma_sub_rt cur prev bpp 0
  | FilterUp ->
    lemma_up_rt cur prev bpp 0
  | FilterAverage ->
    lemma_average_rt cur prev bpp 0
  | FilterPaeth ->
    lemma_paeth_rt cur prev bpp 0

(* ========================================================================
   SECTION 7: Paeth predictor correctness
   ======================================================================== *)

/// The Paeth predictor returns one of its three inputs (the nearest to the
/// linear estimate a + b - c) — never any other value.
let lemma_paeth_predictor_selects (a b c: byte)
  : Lemma (paeth_predictor a b c == a
           \/ paeth_predictor a b c == b
           \/ paeth_predictor a b c == c) =
  let r = paeth_predictor a b c in
  assert (r == a \/ r == b \/ r == c)

(* ========================================================================
   SECTION 8: RFC known-answer vectors (ISO/IEC 15948:2004 §9)
   ======================================================================== *)

/// Known-answer: the ISO/IEC 15948 §9.2 Sub-filter example on the scanline
/// [1; 2; 3; 4; 5] with bpp = 1.  Each Left-neighbour is the previous raw
/// byte (0 for the first), so every sub is 1: the filtered row is the filter
/// byte 0x01 followed by five 0x01 bytes.
let lemma_filter_sub_sample_row () : Lemma
  (ensures filter_scanline FilterSub [0x01uy; 0x02uy; 0x03uy; 0x04uy; 0x05uy] [] 1
           == [0x01uy; 0x01uy; 0x01uy; 0x01uy; 0x01uy; 0x01uy])
  = assert_norm (filter_scanline FilterSub [0x01uy; 0x02uy; 0x03uy; 0x04uy; 0x05uy] [] 1
                  == [0x01uy; 0x01uy; 0x01uy; 0x01uy; 0x01uy; 0x01uy])

/// Known-answer: the ISO/IEC 15948 §9.3 Up filter on a row with a zero
/// (first) previous row passes the row through unchanged (each byte minus the
/// corresponding previous byte 0 is itself), plus the filter byte 0x02.
let lemma_filter_up_sample_row () : Lemma
  (ensures filter_scanline FilterUp [0x0Auy; 0x0Buy; 0x0Cuy] [0x00uy; 0x00uy; 0x00uy] 1
           == [0x02uy; 0x0Auy; 0x0Buy; 0x0Cuy])
  = assert_norm (filter_scanline FilterUp [0x0Auy; 0x0Buy; 0x0Cuy] [0x00uy; 0x00uy; 0x00uy] 1
                  == [0x02uy; 0x0Auy; 0x0Buy; 0x0Cuy])
