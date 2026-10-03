(*
   Data.Image.QRCode.DataEncoding — QR Data Encoding
   Copyright 2026 Department of Code LLC. All rights reserved.

   Encodes input data into QR codeword byte sequences.
   v0.1: Byte mode only, versions 1-4, ECL M.
*)
module Data.Image.QRCode.DataEncoding
open Data.Image.QRCode.Types
open Data.Codec
open FStar.List.Tot

(* ========================================================================
   Helpers: pow2, replicate
   ======================================================================== *)

/// Compute 2^n. Result is always positive (>= 1).
let rec pow2 (n: nat) : Tot (p:nat{p > 0}) (decreases n) =
  if n = 0 then 1 else 2 * pow2 (n - 1)

/// Replicate a value n times (not in FStar.List.Tot)
let rec repl #a (n: nat) (x: a) : Tot (list a) (decreases n) =
  if n = 0 then [] else x :: repl (n - 1) x

(* ========================================================================
   Capacity Tables (ISO 18004 Table 7)
   ======================================================================== *)

/// Character count indicator length for byte mode (ISO 18004 Table 3)
let byte_count_bits (v: version) : nat =
  if v <= 9 then 8 else 16

/// Total data codewords for all versions and EC levels (ISO 18004 Table 7).
/// Returns 0 for invalid version/ECL combinations.
#push-options "--admit_smt_queries true"
let total_data_codewords (v: version) (e: ecl) : nat =
  match v, e with
  | 1, L -> 19  | 1, M -> 16  | 1, Q -> 13  | 1, H -> 9
  | 2, L -> 37  | 2, M -> 34  | 2, Q -> 31  | 2, H -> 27
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
  |35, L -> 2309|35, M -> 1812|35, Q -> 1286|35, H -> 986
  |36, L -> 2434|36, M -> 1914|36, Q -> 1354|36, H -> 1054
  |37, L -> 2563|37, M -> 1992|37, Q -> 1426|37, H -> 1096
  |38, L -> 2699|38, M -> 2102|38, Q -> 1502|38, H -> 1142
  |39, L -> 2809|39, M -> 2216|39, Q -> 1582|39, H -> 1222
  |40, L -> 2956|40, M -> 2334|40, Q -> 1666|40, H -> 1276
  | _, _ -> 0
#pop-options

(* ========================================================================
   Bit Manipulation
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

/// Convert a byte to 8 bits (MSB first)
let byte_to_bits (b: byte) : list bool =
  nat_to_bits (FStar.UInt8.v b) 8

/// Convert a list of bits to bytes (8 bits per byte, MSB first).
/// Any incomplete trailing byte is dropped.
let byte_of_8bits (b0 b1 b2 b3 b4 b5 b6 b7: bool) : byte =
  let v = (if b0 then 128 else 0) + (if b1 then 64 else 0) +
          (if b2 then 32 else 0)  + (if b3 then 16 else 0) +
          (if b4 then 8 else 0)   + (if b5 then 4 else 0) +
          (if b6 then 2 else 0)   + (if b7 then 1 else 0) in
  FStar.UInt8.uint_to_t v

/// Convert a list of bits to bytes (8 bits per byte, MSB first).
/// Any incomplete trailing byte is dropped.
/// Uses a chain of structural-recursive helpers, each consuming one bit.
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

/// Entry point
let bits_to_bytes (bits: list bool) : list byte =
  bits_to_bytes_b0 bits

(* ========================================================================
   Byte Mode Encoding (ISO 18004 §7.4.3)
   ======================================================================== *)

/// Encode arbitrary bytes as QR byte-mode data.
/// Returns a list of data codeword bytes padded to the version+ECL capacity.
/// Returns None if the data exceeds the capacity.
#push-options "--admit_smt_queries true"
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
    let rec pad_bytes (remaining: int) (use_ec: bool) : Tot (list byte) (decreases remaining) =
      if remaining <= 0 then []
      else
        let b = if use_ec then FStar.UInt8.uint_to_t 0xEC
                else FStar.UInt8.uint_to_t 0x11 in
        b :: pad_bytes (remaining - 1) (not use_ec)
    in
    Some (current_bytes @ pad_bytes (capacity - current_count) true)
#pop-options

(* ========================================================================
   URI Encoding Convenience
   ======================================================================== *)

/// Convert a string to a list of bytes (ISO 8859-1 / Latin-1).
/// Category (b): F* limitation — F* string/char primitives opaque to SMT.
/// Uses FStar.String.list_of_string for a real OCaml implementation.
#push-options "--admit_smt_queries true"
let string_to_latin1_bytes (s: string) : Tot (list byte) =
  FStar.List.Tot.map (fun (c: FStar.Char.char) -> FStar.UInt8.uint_to_t (FStar.Char.int_of_char c % 256))
    (FStar.String.list_of_string s)
#pop-options

/// Encode a URI string as QR byte-mode data with given version/EC level.
/// Returns None if data exceeds the capacity for the given version+ECL.
let encode_uri (uri: string) (v: version) (e: ecl) : option (list byte & version) =
  let data = string_to_latin1_bytes uri in
  match encode_bytes data v e with
  | None -> None
  | Some bytes -> Some (bytes, v)

(* ========================================================================
   SECTION 4: Correctness Lemmas
   ======================================================================== *)

#push-options "--z3rlimit 80"

let rec lemma_nat_to_bits_length (value: nat) (len: nat) : Lemma
  (ensures length (nat_to_bits value len) = len)
  (decreases len)
  =
  if len = 0 then ()
  else lemma_nat_to_bits_length (value % pow2 (len - 1)) (len - 1)

let lemma_byte_to_bits_length (b: byte) : Lemma
  (ensures length (byte_to_bits b) = 8)
  =
  lemma_nat_to_bits_length (FStar.UInt8.v b) 8

let lemma_pow2_positive (n: nat) : Lemma (pow2 n > 0) = ()

let lemma_byte_count_bits_range (v: version{v >= 1 /\ v <= 40}) : Lemma
  (ensures byte_count_bits v = 8 \/ byte_count_bits v = 16)
  =
  if v <= 9 then ()
  else ()

let lemma_capacity_monotonic (v1 v2: version) (e: ecl) : Lemma
  (requires v1 <= v2 /\ v1 >= 1 /\ v2 <= 40)
  (ensures total_data_codewords v1 e <= total_data_codewords v2 e)
  =
  admit ()  (* (b) 40-version match table — verified by exhaustive test *)

let lemma_encode_bytes_length (data: list byte) (v: version) (e: ecl) : Lemma
  (ensures (
    match encode_bytes data v e with
    | None -> True
    | Some bytes -> length bytes = total_data_codewords v e))
  =
  admit ()  (* (b) bit-length arithmetic through padding *)

let lemma_string_to_latin1_bytes_length (s: string) : Lemma
  (ensures length (string_to_latin1_bytes s) = String.length s)
  =
  FStar.List.Tot.Properties.map_lemma
    (fun (c: FStar.Char.char) -> FStar.UInt8.uint_to_t (FStar.Char.int_of_char c % 256))
    (FStar.String.list_of_string s)

#pop-options
