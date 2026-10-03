(*
   Data.Image.QRCode.Types — QR Code Core Types
   Copyright 2026 Department of Code LLC. All rights reserved.

   Core types: version, ecl, encoding_mode, qr_matrix.
*)
module Data.Image.QRCode.Types

open FStar.Mul
open FStar.List.Tot

/// Error correction level (ISO 18004 §7.5.1)
type ecl =
  | L   (* ~7% recovery *)
  | M   (* ~15% recovery *)
  | Q   (* ~25% recovery *)
  | H   (* ~30% recovery *)

/// Encoding mode (ISO 18004 §7.4)
type encoding_mode =
  | Numeric       (* digits 0-9 *)
  | Alphanumeric  (* 0-9, A-Z, space, $%*+-./: *)
  | Byte          (* ISO 8859-1 / raw bytes *)
  | Kanji         (* Shift JIS *)

/// QR version: 1 through 40
type version = v:nat{1 <= v /\ v <= 40}

/// A QR module (single pixel in QR grid). true = dark, false = light
type module_t = bool

/// QR code matrix: a square grid of modules
type qr_matrix = {
  version : version;
  modules : list (list module_t);
}

/// Compute the size (width = height) of a QR matrix for a given version.
/// Formula: 17 + 4 * version modules per side (ISO 18004 §6.3.3)
let matrix_size (v: version) : nat =
  17 + 4 * v + 2 * 4

/// Validate that a qr_matrix is well-formed:
/// - correct number of rows (= size)
/// - each row has correct length (= size)
let valid_matrix (m: qr_matrix) : bool =
  let sz = matrix_size m.version in
  length m.modules = sz &&
  for_all (fun row -> length row = sz) m.modules
