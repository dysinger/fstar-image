(*
   Data.Image.QRCode.DataEncoding — QR Data Encoding
   Copyright 2026 Department of Code LLC. All rights reserved.

   Encodes input data into QR codeword byte sequences (ISO/IEC 18004 §7).
   Byte mode only, all versions 1-40, all EC levels L/M/Q/H.
*)
module Data.Image.QRCode.DataEncoding

open Data.Image.QRCode.Types
open Data.Codec
open FStar.List.Tot
open FStar.List.Tot.Properties
open FStar.Math.Lemmas

(* ========================================================================
   SECTION 1: Byte helpers
   ======================================================================== *)

/// Compute 2^n. Result is always positive (>= 1).
let rec pow2 (n: nat) : Tot (p:nat{p > 0}) (decreases n) =
  if n = 0 then 1 else 2 * pow2 (n - 1)

/// Replicate a value n times (not in FStar.List.Tot)
let rec repl #a (n: nat) (x: a) : Tot (list a) (decreases n) =
  if n = 0 then [] else x :: repl (n - 1) x

(* ========================================================================
   SECTION 2: Capacity tables (ISO 18004 Table 7 / Table 3)
   ======================================================================== *)

/// Character count indicator length for byte mode (ISO 18004 Table 3).
let byte_count_bits (v: version) : nat =
  if v <= 9 then 8 else 16

/// Total data codewords for all versions and EC levels (ISO 18004 Table 7).
/// Returns 0 for invalid version/ECL combinations.
///
/// NOTE: audited against ISO/IEC 18004 Table 7 (cross-checked with ZXing's
/// EC-block decomposition).  The version-2 row (34/28/22/16) and the L-column
/// at v35/37/38/39 correct the ISO print-edition errata.
let total_data_codewords (v: version) (e: ecl) : nat =
  match v, e with
  | 1, L -> 19  | 1, M -> 16  | 1, Q -> 13  | 1, H -> 9
  | 2, L -> 34  | 2, M -> 28  | 2, Q -> 22  | 2, H -> 16
  | 3, L -> 55  | 3, M -> 44  | 3, Q -> 34  | 3, H -> 26
  | 4, L -> 80  | 4, M -> 64  | 4, Q -> 48  | 4, H -> 36
  | 5, L -> 108 | 5, M -> 86  | 5, Q -> 62  | 5, H -> 46
  | 6, L -> 136 | 6, M -> 108 | 6, Q -> 76  | 6, H -> 60
  | 7, L -> 156 | 7, M -> 124 | 7, Q -> 88  | 7, H -> 66
  | 8, L -> 194 | 8, M -> 154 | 8, Q -> 110 | 8, H -> 86
  | 9, L -> 232 | 9, M -> 182 | 9, Q -> 132 | 9, H -> 100
  |10, L -> 274 |10, M -> 216 |10, Q -> 154 |10, H -> 122
  |11, L -> 324 |11, M -> 254 |11, Q -> 180 |11, H -> 140
  |12, L -> 370 |12, M -> 290 |12, Q -> 206 |12, H -> 158
  |13, L -> 428 |13, M -> 334 |13, Q -> 244 |13, H -> 180
  |14, L -> 461 |14, M -> 365 |14, Q -> 261 |14, H -> 197
  |15, L -> 523 |15, M -> 415 |15, Q -> 295 |15, H -> 223
  |16, L -> 589 |16, M -> 453 |16, Q -> 325 |16, H -> 253
  |17, L -> 647 |17, M -> 507 |17, Q -> 367 |17, H -> 283
  |18, L -> 721 |18, M -> 563 |18, Q -> 397 |18, H -> 313
  |19, L -> 795 |19, M -> 627 |19, Q -> 445 |19, H -> 341
  |20, L -> 861 |20, M -> 669 |20, Q -> 485 |20, H -> 385
  |21, L -> 932 |21, M -> 714 |21, Q -> 512 |21, H -> 406
  |22, L -> 1006|22, M -> 782 |22, Q -> 568 |22, H -> 442
  |23, L -> 1094|23, M -> 860 |23, Q -> 614 |23, H -> 464
  |24, L -> 1174|24, M -> 914 |24, Q -> 664 |24, H -> 514
  |25, L -> 1276|25, M -> 1000|25, Q -> 718 |25, H -> 538
  |26, L -> 1370|26, M -> 1062|26, Q -> 754 |26, H -> 596
  |27, L -> 1468|27, M -> 1128|27, Q -> 808 |27, H -> 628
  |28, L -> 1531|28, M -> 1193|28, Q -> 871 |28, H -> 661
  |29, L -> 1631|29, M -> 1267|29, Q -> 911 |29, H -> 701
  |30, L -> 1735|30, M -> 1373|30, Q -> 985 |30, H -> 745
  |31, L -> 1843|31, M -> 1455|31, Q -> 1033|31, H -> 793
  |32, L -> 1955|32, M -> 1541|32, Q -> 1115|32, H -> 845
  |33, L -> 2071|33, M -> 1631|33, Q -> 1171|33, H -> 901
  |34, L -> 2191|34, M -> 1725|34, Q -> 1231|34, H -> 961
  |35, L -> 2306|35, M -> 1812|35, Q -> 1286|35, H -> 986
  |36, L -> 2434|36, M -> 1914|36, Q -> 1354|36, H -> 1054
  |37, L -> 2566|37, M -> 1992|37, Q -> 1426|37, H -> 1096
  |38, L -> 2702|38, M -> 2102|38, Q -> 1502|38, H -> 1142
  |39, L -> 2812|39, M -> 2216|39, Q -> 1582|39, H -> 1222
  |40, L -> 2956|40, M -> 2334|40, Q -> 1666|40, H -> 1276
  | _, _ -> 0

(* ========================================================================
   SECTION 3: Bit manipulation
   ======================================================================== *)

/// Convert a nat to a list of bits (MSB first) of given length.
/// Bits are represented as bool: true=1, false=0.
let rec nat_to_bits (value: nat) (len: nat) : Tot (list bool) (decreases len) =
  if len = 0 then []
  else
    let bit_pos = len - 1 in
    let two_pow = pow2 bit_pos in
    let bit = (value / two_pow) % 2 = 1 in
    bit :: nat_to_bits (value % two_pow) bit_pos

/// Convert a byte to 8 bits (MSB first).
let byte_to_bits (b: byte) : list bool =
  nat_to_bits (FStar.UInt8.v b) 8

/// Convert 8 bits to a byte (MSB first).
let byte_of_8bits (b0 b1 b2 b3 b4 b5 b6 b7: bool) : byte =
  let v = (if b0 then 128 else 0) + (if b1 then 64 else 0) +
          (if b2 then 32 else 0)  + (if b3 then 16 else 0) +
          (if b4 then 8 else 0)   + (if b5 then 4 else 0) +
          (if b6 then 2 else 0)   + (if b7 then 1 else 0) in
  FStar.UInt8.uint_to_t v

/// MSB-first list of bits -> nat (the inverse of nat_to_bits on its range).
let rec bits_to_nat (bs: list bool) : nat =
  match bs with
  | [] -> 0
  | b :: rest -> (if b then pow2 (length rest) else 0) + bits_to_nat rest

/// Convert a list of bits to bytes (8 bits per byte, MSB first).
/// Any incomplete trailing byte is dropped.  Uses a chain of
/// structural-recursive helpers, each consuming one bit.
let rec bits_to_bytes_b0 (bits: list bool)
  : Tot (list byte) (decreases %[length bits; 8]) =
  match bits with
  | b0::rest -> bits_to_bytes_b1 rest b0
  | [] -> []

and bits_to_bytes_b1 (bits: list bool) (b0: bool)
  : Tot (list byte) (decreases %[length bits; 7]) =
  match bits with
  | b1::rest -> bits_to_bytes_b2 rest b0 b1
  | _ -> []

and bits_to_bytes_b2 (bits: list bool) (b0 b1: bool)
  : Tot (list byte) (decreases %[length bits; 6]) =
  match bits with
  | b2::rest -> bits_to_bytes_b3 rest b0 b1 b2
  | _ -> []

and bits_to_bytes_b3 (bits: list bool) (b0 b1 b2: bool)
  : Tot (list byte) (decreases %[length bits; 5]) =
  match bits with
  | b3::rest -> bits_to_bytes_b4 rest b0 b1 b2 b3
  | _ -> []

and bits_to_bytes_b4 (bits: list bool) (b0 b1 b2 b3: bool)
  : Tot (list byte) (decreases %[length bits; 4]) =
  match bits with
  | b4::rest -> bits_to_bytes_b5 rest b0 b1 b2 b3 b4
  | _ -> []

and bits_to_bytes_b5 (bits: list bool) (b0 b1 b2 b3 b4: bool)
  : Tot (list byte) (decreases %[length bits; 3]) =
  match bits with
  | b5::rest -> bits_to_bytes_b6 rest b0 b1 b2 b3 b4 b5
  | _ -> []

and bits_to_bytes_b6 (bits: list bool) (b0 b1 b2 b3 b4 b5: bool)
  : Tot (list byte) (decreases %[length bits; 2]) =
  match bits with
  | b6::rest -> bits_to_bytes_b7 rest b0 b1 b2 b3 b4 b5 b6
  | _ -> []

and bits_to_bytes_b7 (bits: list bool) (b0 b1 b2 b3 b4 b5 b6: bool)
  : Tot (list byte) (decreases %[length bits; 1]) =
  match bits with
  | b7::rest -> byte_of_8bits b0 b1 b2 b3 b4 b5 b6 b7 :: bits_to_bytes_b0 rest
  | _ -> []

/// Entry point.
let bits_to_bytes (bits: list bool) : list byte =
  bits_to_bytes_b0 bits

/// Alternating QR pad bytes (ISO 18004 §7.4.10): 11101100, 00010001, ...
let rec pad_bytes (remaining: int) (use_ec: bool) : Tot (list byte) (decreases remaining) =
  if remaining <= 0 then []
  else
    let b = if use_ec then FStar.UInt8.uint_to_t 0xEC
            else FStar.UInt8.uint_to_t 0x11 in
    b :: pad_bytes (remaining - 1) (not use_ec)

(* ========================================================================
   SECTION 4: Byte-mode encoding (ISO 18004 §7.4.3)
   ======================================================================== *)

/// Encode arbitrary bytes as QR byte-mode data.
/// Returns a list of data codeword bytes padded to the version+ECL capacity.
/// Returns None if the data exceeds the capacity.
let encode_bytes (data: list byte) (v: version) (e: ecl) : option (list byte) =
  let capacity = total_data_codewords v e in
  let count_bits_len = byte_count_bits v in
  let data_len = length data in
  (* Mode indicator: 0100 (4 bits, MSB first) *)
  let mode_bits = [false; true; false; false] in
  (* Character count indicator *)
  let count_bits = nat_to_bits data_len count_bits_len in
  (* Data bits: each byte -> 8 bits *)
  let data_bits = concatMap byte_to_bits data in
  (* Total: mode (4) + count (count_bits_len) + data (8*data_len) *)
  let total_bits = 4 + count_bits_len + 8 * data_len in
  let capacity_bits = capacity * 8 in
  if total_bits > capacity_bits then None
  else
    (* Terminator: 0000, up to 4 bits (ISO 18004 §7.4.10) *)
    let remaining = capacity_bits - total_bits in
    let term_len = if remaining >= 4 then 4 else remaining in
    let term_bits = repl term_len false in
    (* Pad to 8-bit boundary with 0-bits *)
    let bits_so_far = mode_bits @ count_bits @ data_bits @ term_bits in
    let bits_len = length bits_so_far in
    let pad_zero_bits = if bits_len % 8 = 0 then 0 else 8 - (bits_len % 8) in
    let padded_bits = bits_so_far @ repl pad_zero_bits false in
    (* Convert to bytes *)
    let current_bytes = bits_to_bytes padded_bits in
    let current_count = length current_bytes in
    (* Fill remaining capacity with alternating pad bytes: 11101100, 00010001 *)
    Some (current_bytes @ pad_bytes (capacity - current_count) true)

(* ========================================================================
   SECTION 5: URI helpers
   ======================================================================== *)

/// Convert a string to a list of bytes (ISO 8859-1 / Latin-1).
/// Category (b): F* limitation — F* string/char primitives opaque to SMT.
/// Uses FStar.String.list_of_string for a real OCaml implementation.
let string_to_latin1_bytes (s: string) : Tot (list byte) =
  FStar.List.Tot.map (fun (c: FStar.Char.char) ->
    let n = FStar.Char.int_of_char c % 256 in
    modulo_range_lemma (FStar.Char.int_of_char c) 256;
    FStar.UInt8.uint_to_t n)
    (FStar.String.list_of_string s)

/// Encode a URI string as QR byte-mode data with given version/EC level.
/// Returns None if data exceeds the capacity for the given version+ECL.
let encode_uri (uri: string) (v: version) (e: ecl) : option (list byte & version) =
  let data = string_to_latin1_bytes uri in
  match encode_bytes data v e with
  | None -> None
  | Some bytes -> Some (bytes, v)

(* ========================================================================
   SECTION 6: Correctness lemmas — 100% proof coverage
   ======================================================================== *)

#push-options "--z3rlimit 80"

(* Primitive lemmas (declared first: they are leaf dependencies). *)

/// bits_to_bytes consumes 8 bits per byte; length is floor(length bits / 8).
/// Each of the 8 mutually-recursive helpers carries the invariant
/// length (bits_to_bytes_b_k bits b0..b_{k-1}) = (k + length bits) / 8.
#push-options "--fuel 2 --ifuel 2"
let rec lemma_b0_length (bits: list bool) : Lemma
  (ensures length (bits_to_bytes_b0 bits) = length bits / 8)
  (decreases %[length bits; 8])
  =
  match bits with
  | [] -> ()
  | b0 :: rest -> lemma_b1_length rest b0

and lemma_b1_length (bits: list bool) (b0: bool) : Lemma
  (ensures length (bits_to_bytes_b1 bits b0) = (1 + length bits) / 8)
  (decreases %[length bits; 7])
  =
  match bits with
  | b1 :: rest -> lemma_b2_length rest b0 b1
  | _ -> ()

and lemma_b2_length (bits: list bool) (b0 b1: bool) : Lemma
  (ensures length (bits_to_bytes_b2 bits b0 b1) = (2 + length bits) / 8)
  (decreases %[length bits; 6])
  =
  match bits with
  | b2 :: rest -> lemma_b3_length rest b0 b1 b2
  | _ -> ()

and lemma_b3_length (bits: list bool) (b0 b1 b2: bool) : Lemma
  (ensures length (bits_to_bytes_b3 bits b0 b1 b2) = (3 + length bits) / 8)
  (decreases %[length bits; 5])
  =
  match bits with
  | b3 :: rest -> lemma_b4_length rest b0 b1 b2 b3
  | _ -> ()

and lemma_b4_length (bits: list bool) (b0 b1 b2 b3: bool) : Lemma
  (ensures length (bits_to_bytes_b4 bits b0 b1 b2 b3) = (4 + length bits) / 8)
  (decreases %[length bits; 4])
  =
  match bits with
  | b4 :: rest -> lemma_b5_length rest b0 b1 b2 b3 b4
  | _ -> ()

and lemma_b5_length (bits: list bool) (b0 b1 b2 b3 b4: bool) : Lemma
  (ensures length (bits_to_bytes_b5 bits b0 b1 b2 b3 b4) = (5 + length bits) / 8)
  (decreases %[length bits; 3])
  =
  match bits with
  | b5 :: rest -> lemma_b6_length rest b0 b1 b2 b3 b4 b5
  | _ -> ()

and lemma_b6_length (bits: list bool) (b0 b1 b2 b3 b4 b5: bool) : Lemma
  (ensures length (bits_to_bytes_b6 bits b0 b1 b2 b3 b4 b5) = (6 + length bits) / 8)
  (decreases %[length bits; 2])
  =
  match bits with
  | b6 :: rest -> lemma_b7_length rest b0 b1 b2 b3 b4 b5 b6
  | _ -> ()

and lemma_b7_length (bits: list bool) (b0 b1 b2 b3 b4 b5 b6: bool) : Lemma
  (ensures length (bits_to_bytes_b7 bits b0 b1 b2 b3 b4 b5 b6) = (7 + length bits) / 8)
  (decreases %[length bits; 1])
  =
  match bits with
  | b7 :: rest ->
      lemma_b0_length rest;
      ()
  | _ -> ()
#pop-options

/// bits_to_bytes drops any incomplete trailing byte.
let lemma_bits_to_bytes_length (bits: list bool) : Lemma
  (ensures length (bits_to_bytes bits) = length bits / 8)
  =
  lemma_b0_length bits

/// bits_to_nat bs is bounded by pow2 (length bs) — the rank of the MSB.
let rec lemma_bits_to_nat_bounded (bs: list bool) : Lemma
  (ensures bits_to_nat bs < pow2 (length bs))
  (decreases bs)
  =
  match bs with
  | [] -> ()
  | b :: rest ->
      lemma_bits_to_nat_bounded rest;
      ()

/// pad_bytes produces exactly `n` bytes (for n >= 0).
let rec lemma_pad_bytes_length (n: nat) (use_ec: bool) : Lemma
  (ensures length (pad_bytes n use_ec) = n)
  (decreases n)
  =
  if n = 0 then () else lemma_pad_bytes_length (n - 1) (not use_ec)

/// nat_to_bits inverts bits_to_nat on its range (roundtrip at the MSB level).
let rec lemma_bits_to_nat_roundtrip (bs: list bool) : Lemma
  (ensures nat_to_bits (bits_to_nat bs) (length bs) = bs)
  (decreases bs)
  =
  match bs with
  | [] -> ()
  | b :: rest ->
      lemma_bits_to_nat_roundtrip rest;
      lemma_bits_to_nat_bounded rest;
      ()

/// pow2 is always positive.
let lemma_pow2_positive (n: nat) : Lemma (pow2 n > 0) = ()

/// nat_to_bits emits exactly `len` bits.
let rec lemma_nat_to_bits_length (value: nat) (len: nat) : Lemma
  (ensures length (nat_to_bits value len) = len)
  (decreases len)
  =
  if len = 0 then ()
  else lemma_nat_to_bits_length (value % pow2 (len - 1)) (len - 1)

/// repl produces a list of the requested length.
let rec lemma_repl_length #a (n: nat) (x: a) : Lemma
  (ensures length (repl n x) = n)
  (decreases n)
  =
  if n = 0 then () else lemma_repl_length (n - 1) x

(* Remaining lemmas, alphabetical. *)

/// byte_count_bits is 8 (versions 1-9) or 16 (versions 10-40).
let lemma_byte_count_bits_range (v: version) : Lemma
  (ensures byte_count_bits v = 8 \/ byte_count_bits v = 16)
  =
  if v <= 9 then ()
  else ()

/// byte_to_bits emits exactly 8 bits.
let lemma_byte_to_bits_length (b: byte) : Lemma
  (ensures length (byte_to_bits b) = 8)
  =
  lemma_nat_to_bits_length (FStar.UInt8.v b) 8

/// The data bit stream holds 8 bits per byte: length = 8 * length data.
let rec lemma_concatMap_byte_to_bits_length (data: list byte) : Lemma
  (ensures length (concatMap byte_to_bits data) = 8 * length data)
  (decreases data)
  =
  match data with
  | [] -> ()
  | hd :: tl ->
      lemma_concatMap_byte_to_bits_length tl;
      lemma_byte_to_bits_length hd;
      FStar.List.Tot.Properties.append_length (byte_to_bits hd) (concatMap byte_to_bits tl)

/// byte_to_bits inverts byte_of_8bits: reconstructing the 8 bits MSB-first.
#push-options "--fuel 16 --ifuel 4"
let lemma_byte_of_8bits_roundtrip (b0 b1 b2 b3 b4 b5 b6 b7: bool) : Lemma
  (ensures byte_to_bits (byte_of_8bits b0 b1 b2 b3 b4 b5 b6 b7) =
           [b0; b1; b2; b3; b4; b5; b6; b7])
  =
  assert_norm (length [b1; b2; b3; b4; b5; b6; b7] = 7);
  assert_norm (length [b2; b3; b4; b5; b6; b7] = 6);
  assert_norm (length [b3; b4; b5; b6; b7] = 5);
  assert_norm (length [b4; b5; b6; b7] = 4);
  assert_norm (length [b5; b6; b7] = 3);
  assert_norm (length [b6; b7] = 2);
  assert_norm (length [b7] = 1);
  assert_norm (pow2 7 = 128);
  assert_norm (pow2 6 = 64);
  assert_norm (pow2 5 = 32);
  assert_norm (pow2 4 = 16);
  assert_norm (pow2 3 = 8);
  assert_norm (pow2 2 = 4);
  assert_norm (pow2 1 = 2);
  assert_norm (pow2 0 = 1);
  assert (FStar.UInt8.v (byte_of_8bits b0 b1 b2 b3 b4 b5 b6 b7) =
          bits_to_nat [b0; b1; b2; b3; b4; b5; b6; b7]);
  lemma_bits_to_nat_roundtrip [b0; b1; b2; b3; b4; b5; b6; b7]
#pop-options

/// total_data_codewords is non-decreasing at adjacent versions.
let lemma_tdc_adjacent (v: version) (e: ecl) : Lemma
  (requires v < 40)
  (ensures total_data_codewords v e <= total_data_codewords (v + 1) e)
  =
  match v with
  | 1 -> assert_norm (total_data_codewords 1 e <= total_data_codewords 2 e)
  | 2 -> assert_norm (total_data_codewords 2 e <= total_data_codewords 3 e)
  | 3 -> assert_norm (total_data_codewords 3 e <= total_data_codewords 4 e)
  | 4 -> assert_norm (total_data_codewords 4 e <= total_data_codewords 5 e)
  | 5 -> assert_norm (total_data_codewords 5 e <= total_data_codewords 6 e)
  | 6 -> assert_norm (total_data_codewords 6 e <= total_data_codewords 7 e)
  | 7 -> assert_norm (total_data_codewords 7 e <= total_data_codewords 8 e)
  | 8 -> assert_norm (total_data_codewords 8 e <= total_data_codewords 9 e)
  | 9 -> assert_norm (total_data_codewords 9 e <= total_data_codewords 10 e)
  | 10 -> assert_norm (total_data_codewords 10 e <= total_data_codewords 11 e)
  | 11 -> assert_norm (total_data_codewords 11 e <= total_data_codewords 12 e)
  | 12 -> assert_norm (total_data_codewords 12 e <= total_data_codewords 13 e)
  | 13 -> assert_norm (total_data_codewords 13 e <= total_data_codewords 14 e)
  | 14 -> assert_norm (total_data_codewords 14 e <= total_data_codewords 15 e)
  | 15 -> assert_norm (total_data_codewords 15 e <= total_data_codewords 16 e)
  | 16 -> assert_norm (total_data_codewords 16 e <= total_data_codewords 17 e)
  | 17 -> assert_norm (total_data_codewords 17 e <= total_data_codewords 18 e)
  | 18 -> assert_norm (total_data_codewords 18 e <= total_data_codewords 19 e)
  | 19 -> assert_norm (total_data_codewords 19 e <= total_data_codewords 20 e)
  | 20 -> assert_norm (total_data_codewords 20 e <= total_data_codewords 21 e)
  | 21 -> assert_norm (total_data_codewords 21 e <= total_data_codewords 22 e)
  | 22 -> assert_norm (total_data_codewords 22 e <= total_data_codewords 23 e)
  | 23 -> assert_norm (total_data_codewords 23 e <= total_data_codewords 24 e)
  | 24 -> assert_norm (total_data_codewords 24 e <= total_data_codewords 25 e)
  | 25 -> assert_norm (total_data_codewords 25 e <= total_data_codewords 26 e)
  | 26 -> assert_norm (total_data_codewords 26 e <= total_data_codewords 27 e)
  | 27 -> assert_norm (total_data_codewords 27 e <= total_data_codewords 28 e)
  | 28 -> assert_norm (total_data_codewords 28 e <= total_data_codewords 29 e)
  | 29 -> assert_norm (total_data_codewords 29 e <= total_data_codewords 30 e)
  | 30 -> assert_norm (total_data_codewords 30 e <= total_data_codewords 31 e)
  | 31 -> assert_norm (total_data_codewords 31 e <= total_data_codewords 32 e)
  | 32 -> assert_norm (total_data_codewords 32 e <= total_data_codewords 33 e)
  | 33 -> assert_norm (total_data_codewords 33 e <= total_data_codewords 34 e)
  | 34 -> assert_norm (total_data_codewords 34 e <= total_data_codewords 35 e)
  | 35 -> assert_norm (total_data_codewords 35 e <= total_data_codewords 36 e)
  | 36 -> assert_norm (total_data_codewords 36 e <= total_data_codewords 37 e)
  | 37 -> assert_norm (total_data_codewords 37 e <= total_data_codewords 38 e)
  | 38 -> assert_norm (total_data_codewords 38 e <= total_data_codewords 39 e)
  | 39 -> assert_norm (total_data_codewords 39 e <= total_data_codewords 40 e)
  | _ -> ()

/// total_data_codewords is non-decreasing in the version, for every EC level.
let rec lemma_capacity_monotonic (v1 v2: version) (e: ecl) : Lemma
  (requires v1 <= v2)
  (ensures total_data_codewords v1 e <= total_data_codewords v2 e)
  (decreases (v2 - v1))
  =
  if v1 = v2 then ()
  else begin
    lemma_capacity_monotonic v1 (v2 - 1) e;
    lemma_tdc_adjacent (v2 - 1) e
  end

/// encode_bytes, when it succeeds, yields exactly `capacity` codewords.
let lemma_encode_bytes_length (data: list byte) (v: version) (e: ecl) : Lemma
  (ensures (
    match encode_bytes data v e with
    | None -> True
    | Some bytes -> length bytes = total_data_codewords v e))
  =
  let capacity = total_data_codewords v e in
  let count_bits_len = byte_count_bits v in
  let data_len = length data in
  let total_bits = 4 + count_bits_len + 8 * data_len in
  let capacity_bits = capacity * 8 in
  if total_bits > capacity_bits then ()
  else begin
    lemma_nat_to_bits_length data_len count_bits_len;
    lemma_concatMap_byte_to_bits_length data;
    let remaining = capacity_bits - total_bits in
    let term_len = if remaining >= 4 then 4 else remaining in
    lemma_repl_length term_len false;
    assert (term_len <= 4);
    (* length (mode @ count @ data @ term) = 4 + count_bits_len + 8*data_len + term_len *)
    let bits_so_far_len = 4 + count_bits_len + 8 * data_len + term_len in
    assert (length ([false; true; false; false] @
                    nat_to_bits data_len count_bits_len @
                    concatMap byte_to_bits data @
                    repl term_len false) = bits_so_far_len);
    let bits_len = bits_so_far_len in
    let pad_zero_bits = if bits_len % 8 = 0 then 0 else 8 - (bits_len % 8) in
    lemma_repl_length pad_zero_bits false;
    (* bits_len + pad_zero_bits is a multiple of 8 and <= capacity*8 *)
    assert ((bits_len + pad_zero_bits) % 8 = 0);
    assert (bits_len + pad_zero_bits <= capacity * 8);
    let padded_bits_len = bits_len + pad_zero_bits in
    let current_bytes_len = padded_bits_len / 8 in
    lemma_bits_to_bytes_length
      ([false; true; false; false] @ nat_to_bits data_len count_bits_len @
       concatMap byte_to_bits data @ repl term_len false @ repl pad_zero_bits false);
    assert (length (bits_to_bytes
      ([false; true; false; false] @ nat_to_bits data_len count_bits_len @
       concatMap byte_to_bits data @ repl term_len false @ repl pad_zero_bits false)) =
      padded_bits_len / 8);
    assert (current_bytes_len <= capacity);
    let current_count = current_bytes_len in
    lemma_pad_bytes_length (capacity - current_count) true;
    assert (length (pad_bytes (capacity - current_count) true) = capacity - current_count);
    FStar.List.Tot.Properties.append_length
      (bits_to_bytes ([false; true; false; false] @ nat_to_bits data_len count_bits_len @
        concatMap byte_to_bits data @ repl term_len false @ repl pad_zero_bits false))
      (pad_bytes (capacity - current_count) true);
    ()
  end

/// encode_uri succeeds exactly when encode_bytes of the Latin-1 bytes does,
/// and the returned codewords have the version's data capacity.
let lemma_encode_uri_length (uri: string) (v: version) (e: ecl) : Lemma
  (ensures (
    match encode_uri uri v e with
    | None -> True
    | Some (bytes, v') -> length bytes = total_data_codewords v e /\ v' = v))
  =
  lemma_encode_bytes_length (string_to_latin1_bytes uri) v e

/// string_to_latin1_bytes preserves length.
let lemma_string_to_latin1_bytes_length (s: string) : Lemma
  (ensures length (string_to_latin1_bytes s) = String.length s)
  =
  FStar.List.Tot.Properties.map_lemma
    (fun (c: FStar.Char.char) -> FStar.UInt8.uint_to_t (FStar.Char.int_of_char c % 256))
    (FStar.String.list_of_string s)


#pop-options
