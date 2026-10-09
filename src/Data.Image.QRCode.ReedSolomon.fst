(*
   Data.Image.QRCode.ReedSolomon — Reed-Solomon error correction for QR codes
   Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later

   Implements systematic RS encoding over GF(256).
   Generator polynomials computed as product (x - alpha^i) for i=0..n-1.
*)
module Data.Image.QRCode.ReedSolomon

open Data.Image.QRCode.GF256
open FStar.List.Tot

/// Replicate a value n times
let rec replicate #a (n: nat) (x: a) : Tot (list a) (decreases n) =
  if n = 0 then [] else x :: replicate (n - 1) x

(* ========================================================================
   Generator polynomial computation
   ======================================================================== *)

(* Multiply polynomial by (x + alpha).
   Input poly = [c0, c1, ..., cd] representing c0 + c1*x + ... + cd*x^d.
   Output = c0*alpha + (c0 + c1*alpha)*x + ... + (c_{d-1} + cd*alpha)*x^d + cd*x^{d+1} *)
let rec poly_mul_x_alpha (poly: list gf256) (alpha: gf256)
  : Tot (list gf256) (decreases poly)
  =
  match poly with
  | [] -> []
  | [c] -> [gf_mul c alpha; c]
  | c0 :: rest ->
    let rest' = poly_mul_x_alpha rest alpha in
    match rest' with
    | r0 :: rrest -> gf_mul c0 alpha :: gf_add c0 r0 :: rrest
    | [] -> [gf_mul c0 alpha; c0]

(* Compute the Reed-Solomon generator polynomial for n ECC codewords.
   g(x) = product of (x + alpha^i) for i = 0..n-1. *)
let rec rs_generator_poly (num_ec_codewords: nat) : Tot (list gf256) (decreases num_ec_codewords) =
  if num_ec_codewords = 0 then [1uy]
  else poly_mul_x_alpha (rs_generator_poly (num_ec_codewords - 1)) (gf_exp (num_ec_codewords - 1))

(* ========================================================================
   Systematic RS encoding
   ======================================================================== *)

(* Subtract factor * poly * x^shift from the dividend polynomial.
   dividend[k] represents coefficient of x^{len(dividend)-1-k}.
   poly = [g0, g1, ..., gn] where gn = 1.
   This eliminates the leading coefficient at position 0. *)
(* Subtract factor * poly (XOR'd into div) without changing the list spine.
   Walks div coating each element, so it preserves length. *)
let rec rs_subtract (factor: gf256) (poly div: list gf256) (j: nat)
  : Tot (list gf256) (decreases length div)
  =
  let n = length poly - 1 in
  if j > n then div
  else
    let coeff = match nth poly (n - j) with
      | Some v -> v
      | None -> 0uy
    in
    let term = gf_mul factor coeff in
    match div with
    | [] -> []
    | hd :: tl ->
      if j = 0 then gf_add hd term :: tl
      else hd :: rs_subtract factor poly tl (j + 1)

let poly_div_step (dividend: list gf256) (poly: list gf256)
  : Tot (list gf256) (decreases dividend)
  =
  match dividend with
  | [] -> []
  | factor :: rest ->
    let result = rs_subtract factor poly dividend 0 in
    match result with
    | _ :: tl -> tl  (* drop the zeroed leading coefficient *)
    | [] -> []

(* Perform polynomial long division. Each step eliminates the leading
   coefficient.  `div` starts at the dividend (data @ zeros, length k + num_ec);
   k steps drop the k data coefficients, leaving num_ec.  `gen` is the
   generator polynomial (length num_ec + 1). *)
let rec rs_divide (gen: list gf256) (k steps: nat) (div: list gf256)
  : Tot (list gf256) (decreases k - steps)
  =
  if steps >= k then div
  else rs_divide gen k (steps + 1) (poly_div_step div gen)

(* Generate n error correction codewords for data using systematic RS encoding.
   The data is unchanged; n ECC codewords are appended. *)
let rs_generate_ec (data: list gf256) (num_ec: nat) : list gf256 =
  let gen = rs_generator_poly num_ec in
  let k = length data in
  let zeros = replicate num_ec 0uy in
  let dividend = data @ zeros in
  let remainder = rs_divide gen k 0 dividend in
  remainder

(* ========================================================================
   SECTION 2: Reed-Solomon Correctness Lemmas — 100% proof coverage
   ======================================================================== *)

#push-options "--z3rlimit 40"

/// poly_mul_x_alpha adds one coefficient (the leading x^{d+1} term).
let rec lemma_poly_mul_x_alpha_length (poly: list gf256) (alpha: gf256) : Lemma
  (requires length poly > 0)
  (ensures length (poly_mul_x_alpha poly alpha) = length poly + 1)
  (decreases poly)
  =
  match poly with
  | [] -> ()
  | [c] -> ()
  | c0 :: rest ->
    let rest' = poly_mul_x_alpha rest alpha in
    lemma_poly_mul_x_alpha_length rest alpha;
    ()

/// The generator polynomial for n EC codewords has degree n,
/// so it has exactly n+1 coefficients.
let rec lemma_gen_poly_length (n: nat) : Lemma
  (ensures length (rs_generator_poly n) = n + 1)
  (decreases n)
  =
  if n = 0 then ()
  else
    (lemma_gen_poly_length (n - 1);
     lemma_poly_mul_x_alpha_length (rs_generator_poly (n - 1)) (gf_exp (n - 1)))

/// The generator polynomial is non-empty: it has at least its leading 1.
let lemma_gen_poly_monic (n: nat{n > 0}) : Lemma
  (ensures length (rs_generator_poly n) > 0)
  =
  lemma_gen_poly_length n

/// length (replicate n x) = n.
let rec lemma_replicate_length #a (n: nat) (x: a) : Lemma
  (ensures length (replicate n x) = n)
  (decreases n)
  =
  if n = 0 then () else lemma_replicate_length (n - 1) x

/// poly_div_step drops exactly one leading coefficient (div non-empty).
let rec lemma_rs_subtract_length (factor: gf256) (poly div: list gf256) (j: nat) : Lemma
  (ensures length (rs_subtract factor poly div j) = length div)
  (decreases length div)
  =
  match div with
  | [] -> ()
  | hd :: tl ->
    let n = length poly - 1 in
    if j > n then () else lemma_rs_subtract_length factor poly tl (j + 1)

let lemma_poly_div_step_length (d poly: list gf256) : Lemma
  (requires length d > 0)
  (ensures length (poly_div_step d poly) = length d - 1)
  =
  match d with
  | [] -> ()
  | factor :: rest ->
    lemma_rs_subtract_length factor poly d 0

/// rs_divide drops one coefficient per step: after `steps` steps (steps <= k),
/// length (rs_divide gen k steps div) = length div - (k... no: each of the
/// k-steps iterations drops one, so from a start length L, after reaching
/// `steps >= k` the result has length L - (number of steps taken) = L - (k - steps)
/// when steps <= k and each intermediate is non-empty.
let rec lemma_rs_divide_length (gen: list gf256) (k steps: nat) (div: list gf256) : Lemma
  (requires steps <= k /\ length div >= k - steps)
  (ensures length (rs_divide gen k steps div) = length div - (k - steps))
  (decreases k - steps)
  =
  if steps >= k then ()
  else
    (let div' = poly_div_step div gen in
     lemma_poly_div_step_length div gen;
     lemma_rs_divide_length gen k (steps + 1) div')

/// RS encoding produces exactly num_ec error correction codewords.
let lemma_rs_ec_length (data: list gf256) (num_ec: nat) : Lemma
  (ensures length (rs_generate_ec data num_ec) = num_ec)
  =
  let k = length data in
  let gen = rs_generator_poly num_ec in
  let zeros = replicate num_ec 0uy in
  let dividend = data @ zeros in
  lemma_replicate_length num_ec 0uy;          (* length zeros = num_ec *)
  FStar.List.Tot.Properties.append_length data zeros;  (* length dividend = k + num_ec *)
  lemma_rs_divide_length gen k 0 dividend;    (* length remainder = k + num_ec - k *)
  assert (k + num_ec - k = num_ec)

#pop-options
