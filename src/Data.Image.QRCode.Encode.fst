(*
   Data.Image.QRCode.Encode — Top-Level QR Encoding Pipeline
   Copyright 2026 Department of Code LLC. All rights reserved.

   URI → encode_bytes → Reed-Solomon ECC → matrix placement → mask → qr_matrix
   v0.1: ECL=M, mask=0.
*)
module Data.Image.QRCode.Encode
open Data.Image.QRCode.Types
open Data.Image.QRCode.DataEncoding
open Data.Image.QRCode.ReedSolomon
open Data.Image.QRCode.Matrix
open Data.Codec
open FStar.List.Tot

(* ========================================================================
   SECTION 1: ECC Codeword Count per Block (ISO 18004 Table 9, versions 1-4)
   ======================================================================== *)

val ecc_codewords_per_block (v: version) (e: ecl) : nat

/// Number of EC codewords per block for all versions/ECL (ISO 18004 Table 9).
/// For multi-block versions (v>0), this returns EC per single block.
let ecc_codewords_per_block (v: version) (e: ecl) : nat =
  match v, e with
  | 1, L -> 7  | 1, M -> 10 | 1, Q -> 13 | 1, H -> 17
  | 2, L -> 7  | 2, M -> 10 | 2, Q -> 13 | 2, H -> 17
  | 3, L -> 15 | 3, M -> 26 | 3, Q -> 18 | 3, H -> 22
  | 4, L -> 20 | 4, M -> 18 | 4, Q -> 26 | 4, H -> 16
  | 5, L -> 26 | 5, M -> 24 | 5, Q -> 18 | 5, H -> 22
  | 6, L -> 18 | 6, M -> 16 | 6, Q -> 24 | 6, H -> 28
  | 7, L -> 20 | 7, M -> 18 | 7, Q -> 18 | 7, H -> 26
  | 8, L -> 24 | 8, M -> 22 | 8, Q -> 22 | 8, H -> 26
  | 9, L -> 30 | 9, M -> 22 | 9, Q -> 20 | 9, H -> 24
  |10, L -> 18 |10, M -> 26 |10, Q -> 24 |10, H -> 28
  |11, L -> 20 |11, M -> 30 |11, Q -> 28 |11, H -> 24
  |12, L -> 24 |12, M -> 22 |12, Q -> 26 |12, H -> 28
  |13, L -> 26 |13, M -> 22 |13, Q -> 24 |13, H -> 22
  |14, L -> 30 |14, M -> 24 |14, Q -> 20 |14, H -> 24
  |15, L -> 22 |15, M -> 24 |15, Q -> 30 |15, H -> 24
  |16, L -> 24 |16, M -> 28 |16, Q -> 24 |16, H -> 30
  |17, L -> 28 |17, M -> 28 |17, Q -> 28 |17, H -> 28
  |18, L -> 30 |18, M -> 26 |18, Q -> 28 |18, H -> 28
  |19, L -> 28 |19, M -> 26 |19, Q -> 26 |19, H -> 26
  |20, L -> 28 |20, M -> 26 |20, Q -> 30 |20, H -> 28
  |21, L -> 28 |21, M -> 26 |21, Q -> 28 |21, H -> 30
  |22, L -> 28 |22, M -> 28 |22, Q -> 30 |22, H -> 24
  |23, L -> 30 |23, M -> 28 |23, Q -> 30 |23, H -> 30
  |24, L -> 30 |24, M -> 28 |24, Q -> 30 |24, H -> 30
  |25, L -> 26 |25, M -> 28 |25, Q -> 30 |25, H -> 30
  |26, L -> 28 |26, M -> 28 |26, Q -> 28 |26, H -> 30
  |27, L -> 30 |27, M -> 28 |27, Q -> 30 |27, H -> 30
  |28, L -> 30 |28, M -> 28 |28, Q -> 30 |28, H -> 30
  |29, L -> 30 |29, M -> 28 |29, Q -> 30 |29, H -> 30
  |30, L -> 30 |30, M -> 28 |30, Q -> 30 |30, H -> 30
  |31, L -> 30 |31, M -> 28 |31, Q -> 30 |31, H -> 30
  |32, L -> 30 |32, M -> 28 |32, Q -> 30 |32, H -> 30
  |33, L -> 30 |33, M -> 28 |33, Q -> 30 |33, H -> 30
  |34, L -> 30 |34, M -> 28 |34, Q -> 30 |34, H -> 30
  |35, L -> 30 |35, M -> 28 |35, Q -> 30 |35, H -> 30
  |36, L -> 30 |36, M -> 28 |36, Q -> 30 |36, H -> 30
  |37, L -> 30 |37, M -> 28 |37, Q -> 30 |37, H -> 30
  |38, L -> 30 |38, M -> 28 |38, Q -> 30 |38, H -> 30
  |39, L -> 30 |39, M -> 28 |39, Q -> 30 |39, H -> 30
  |40, L -> 30 |40, M -> 28 |40, Q -> 30 |40, H -> 30
  | _, _ -> 0

(* ========================================================================
   SECTION 2: Format Info
   ======================================================================== *)

(* ECL to 2-bit indicator: L=01, M=00, Q=11, H=10 *)
let ecl_indicator (e: ecl) : nat =
  match e with
  | L -> 1 | M -> 0 | Q -> 3 | H -> 2

(* BCH(15,5) encode_spec using generator polynomial x^10 + x^8 + x^5 + x^4 + x^2 + x + 1 (0x537).
   Encodes 5-bit data into 15-bit codeword.
   Algorithm: multiply data by x^10 (shift left 10), divide by generator polynomial,
   the 10-bit remainder appended to the 5 data bits gives the 15-bit codeword. *)
/// Local refined pow2 — the codec's `Data.Codec.Types.pow2` returns `int`,
/// which does not discharge nonzero-divisor / non-negativity refinements.
let rec pow2_pos (n: nat) : Tot (p:nat{p > 0}) (decreases n) =
  if n = 0 then 1 else 2 * pow2_pos (n - 1)

val bch_15_5_encode (data: nat{data < 32}) : nat

let bch_15_5_encode (data: nat{data < 32}) : nat =
  let gen : nat = 0x537 in
  (* Bitwise XOR of two nats, assuming both fit in `bits` bits *)
  let rec nat_xor (a b: nat) (bits: nat) : Tot nat (decreases bits) =
    if bits = 0 then 0
    else
      let a_bit = a % 2 in
      let b_bit = b % 2 in
      let xor_bit = (a_bit + b_bit) % 2 in
      xor_bit + 2 * nat_xor (a / 2) (b / 2) (bits - 1)
  in
  let rec divide (dividend: nat) (pos: nat) : Tot nat (decreases pos) =
    if pos < 10 then dividend % 1024  (* lower 10 bits = remainder *)
    else
      let bit_mask = pow2_pos pos in
      if (dividend / bit_mask) % 2 = 1 then
        let shifted = gen * pow2_pos (pos - 10) in
        divide (nat_xor dividend shifted 15) (pos - 1)
      else
        divide dividend (pos - 1)
  in
  let padded = data * 1024 in  (* data << 10 *)
  divide padded 14

(* Compute 15-bit format info from ECL and mask pattern.
   Combines 2-bit ECL indicator + 3-bit mask into 5-bit data,
   BCH(15,5) encodes it, then XORs with mask pattern 0x5412. *)
val format_info (ecl: ecl) (mask_id: nat{0 <= mask_id /\ mask_id <= 7}) : nat

let format_info (ecl: ecl) (mask_id: nat{0 <= mask_id /\ mask_id <= 7}) : nat =
  let ecl_bits = ecl_indicator ecl in
  let data = ecl_bits * 8 + mask_id in  (* ecl << 3 | mask *)
  let codeword = bch_15_5_encode data in
  (* XOR with mask pattern 101010000010010 (0x5412) *)
  let mask_pattern : nat = 0x5412 in
  let rec nat_xor_fixed (a b: nat) (bits: nat) : Tot nat (decreases bits) =
    if bits = 0 then 0
    else
      let a_bit = a % 2 in
      let b_bit = b % 2 in
      let xor_bit = (a_bit + b_bit) % 2 in
      xor_bit + 2 * nat_xor_fixed (a / 2) (b / 2) (bits - 1)
  in
  nat_xor_fixed codeword mask_pattern 15

(* Place format info bits in QR matrix.
   Places 15 bits in 3 locations around finder patterns. *)
let place_format_info (m: qr_matrix) (e: ecl) (mask_id: nat{0 <= mask_id /\ mask_id <= 7}) : qr_matrix =
  let sz = matrix_size m.version in
  let format = format_info e mask_id in
  let modules = m.modules in
  (* Local pow2 for extracting bits from format info *)
  let rec p2 (n: nat) : Tot (r:nat{r > 0}) (decreases n) =
    if n = 0 then 1 else 2 * p2 (n - 1) in
  let bit (i: nat) : bool =
    let exp = if 14 >= i then 14 - i else 0 in
    (format / p2 exp) % 2 = 1 in
  (* Copy 1: around top-left finder *)
  let off = 4 in
  let tl_coords_and_bits : list ((nat & nat) & nat) =
    [((off+8,off+0),0); ((off+8,off+1),1); ((off+8,off+2),2); ((off+8,off+3),3); ((off+8,off+4),4); ((off+8,off+5),5);
     ((off+8,off+7),6); ((off+8,off+8),7);
     ((off+7,off+8),8); ((off+5,off+8),9); ((off+4,off+8),10);
     ((off+3,off+8),11); ((off+2,off+8),12); ((off+1,off+8),13); ((off+0,off+8),14)] in
  let rec place_tl (mods: list (list bool)) (cbs: list ((nat & nat) & nat))
    : Tot (list (list bool)) (decreases cbs) =
    match cbs with
    | [] -> mods
    | ((r, c), i) :: rest -> place_tl (set_module mods r c (bit i)) rest
  in
  let modules = place_tl modules tl_coords_and_bits in
  (* Copy 2: below top-right finder (col off+8, rows sz-4..sz-4-7, bits 0..7) *)
  let rec place_tr (fuel: nat) (mods: list (list bool)) (i: nat) (r: nat) : Tot (list (list bool)) (decreases fuel) =
    if fuel = 0 then mods
    else if i >= 8 then mods
    else place_tr (fuel - 1) (set_module mods r (off+8) (bit i)) (i + 1) (if r > sz - off - 8 then r - 1 else off)
  in
  let modules = place_tr 8 modules 0 (sz - off - 1) in
  (* Copy 2 cont: right of bottom-left finder (row off+8, cols sz-4..sz-4-7, bits 14..7) *)
  let rec place_bl (fuel: nat) (mods: list (list bool)) (i: nat) (c: nat) : Tot (list (list bool)) (decreases fuel) =
    if fuel = 0 then mods
    else if i >= 8 then mods
    else place_bl (fuel - 1) (set_module mods (off+8) c (bit (if 14 >= i then 14 - i else 0))) (i + 1) (if c > sz - off - 8 then c - 1 else off)
  in
  let modules = place_bl 8 modules 0 (sz - off - 1) in
  { m with modules = modules }

(* ========================================================================
   SECTION 3: Top-Level Encoding
   ======================================================================== *)

val encode_qr_uri (uri: string) (req_v: version) (e: ecl) : option qr_matrix

/// High-level: encode_spec a URI to a QR matrix with given version/EC level.
/// If v=0, auto-selects the smallest version that fits.
let encode_qr_uri (uri: string) (req_v: version) (e: ecl) : option qr_matrix =
  match Data.Image.QRCode.DataEncoding.encode_uri uri req_v e with
  | None -> None
  | Some (data_bytes, selected_v) ->
    let ecc_per_block = ecc_codewords_per_block selected_v e in
    if ecc_per_block = 0 then None
    else
      let ec_bytes = rs_generate_ec data_bytes ecc_per_block in
      let matrix = make_empty_matrix selected_v in
      let matrix = place_finder_patterns matrix in
      let matrix = place_timing_patterns matrix in
      let matrix = place_alignment_patterns matrix in
      let matrix = place_reserved_areas matrix in
      match place_data matrix data_bytes ec_bytes with
      | None -> None
      | Some m ->
        let best_mask = 0 in  (* forced mask 0 for segno comparison *)
        let masked = apply_mask m best_mask in
        let with_format = place_format_info masked e best_mask in
        Some with_format
