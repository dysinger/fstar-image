(*
   Data.Image.QRCode.Render — QR Matrix → Image Conversion
   Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later

   Converts QR matrices to Gray8 images for PNG/JPEG output.
*)
module Data.Image.QRCode.Render
open Data.Image.QRCode.Types
open Data.Image.QRCode.Matrix
open Data.Image
open Data.Codec
open FStar.List.Tot

(* ========================================================================
   SECTION 1: QR Matrix → Gray8 Image Codec
   ======================================================================== *)

val encode_image (m: qr_matrix) (scale: nat) : option image

let encode_image (m: qr_matrix) (scale: nat) : option image =
  if scale = 0 then None
  else
    let mat_size = matrix_size m.version in
    let img_size = mat_size * scale in
    if img_size = 0 then None
    else
      let dark : byte = FStar.UInt8.uint_to_t 0x00 in
      let light : byte = FStar.UInt8.uint_to_t 0xFF in
      let module_at (row: nat) (col: nat) : byte =
        let qr_row = row / scale in
        let qr_col = col / scale in
        if qr_row >= mat_size || qr_col >= mat_size then light
        else if get_module m.modules qr_row qr_col then dark
        else light
      in
      let rec build_row (fuel: nat) (row: nat) (col: nat) (acc: list byte) : Tot (list byte) (decreases fuel) =
        if fuel = 0 then List.Tot.rev acc
        else if col >= img_size then List.Tot.rev acc
        else build_row (fuel - 1) row (col + 1) (module_at row col :: acc)
      in
      let rec build_rows (fuel: nat) (row: nat) (acc: list byte) : Tot (list byte) (decreases fuel) =
        if fuel = 0 then acc
        else if row >= img_size then acc
        else
          let row_data = build_row img_size row 0 [] in
          build_rows (fuel - 1) (row + 1) (acc @ row_data)
      in
      let data = build_rows img_size 0 [] in
      make_gray8 img_size img_size data
