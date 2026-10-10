(* Copyright 2026 Department of Code LLC.
   SPDX-License-Identifier: AGPL-3.0-or-later *)

(**
Data.Image.Test.Integration — Binds all image lemmas, values, and tests.

If any lemma, [fn], or public value is deleted or renamed, F* verification
fails — this guarantees mechanically-enforced coverage of every public
definition in the [Data.Image] package (18 modules), including the three Pulse
leaves and their roundtrip [fn]s.

Uses [--admit_smt_queries true] for integration anchoring only.  Every binding
below is a bare `let _ = f` value reference, so no verification condition is
re-proven here; each lemma is proven without admits in its source module.

@header Data.Image.Test.Integration
*)
module Data.Image.Test.Integration

open Data.Image
open Data.Image.Convert
open Data.Image.PNG.CRC
open Data.Image.PNG.Filter
open Data.Image.PNG.Deflate
open Data.Image.PNG.Zlib
open Data.Image.PNG.Encode
open Data.Image.PNG.Pulse
open Data.Image.Pulse
open Data.Image.QRCode.Types
open Data.Image.QRCode.GF256
open Data.Image.QRCode.ReedSolomon
open Data.Image.QRCode.DataEncoding
open Data.Image.QRCode.LUT
open Data.Image.QRCode.Matrix
open Data.Image.QRCode.Encode
open Data.Image.QRCode.Render
open Data.Image.QRCode.Pulse


#push-options "--admit_smt_queries true"


(* ========================================================================
   Data.Image — image type + ASCII-art codec
   ======================================================================== *)


(** Types and constructors *)


(** [color_space] *)
let _color_space = color_space
(** [pixel_format] *)
let _pixel_format = pixel_format
(** [channels] *)
let _channels = channels
(** [bytes_per_pixel] *)
let _bytes_per_pixel = bytes_per_pixel
(** [image] (record) — anchored via a representative value *)
let _image = (fun (_: image) -> ())
(** [valid_image] *)
let _valid_image = valid_image
(** [make_image] *)
let _make_image = make_image
(** [make_gray8] *)
let _make_gray8 = make_gray8
(** [make_rgba8] *)
let _make_rgba8 = make_rgba8


(** ASCII sentinels and codec *)


(** [ascii_dark] *)
let _ascii_dark = ascii_dark
(** [ascii_light] *)
let _ascii_light = ascii_light
(** [ascii_nl] *)
let _ascii_nl = ascii_nl
(** [threshold] *)
let _threshold = threshold
(** [pixel_cell] *)
let _pixel_cell = pixel_cell
(** [encode_flat] *)
let _encode_flat = encode_flat
(** [encode_ascii] *)
let _encode_ascii = encode_ascii
(** [decode_cell] *)
let _decode_cell = decode_cell
(** [decode_row] *)
let _decode_row = decode_row
(** [decode_rows] *)
let _decode_rows = decode_rows
(** [decode_ascii] *)
let _decode_ascii = decode_ascii


(** ASCII lemmas *)


(** [lemma_encode_ascii_non_gray8] *)
let _lemma_encode_ascii_non_gray8 = lemma_encode_ascii_non_gray8
(** [lemma_ascii_roundtrip_dark] *)
let _lemma_ascii_roundtrip_dark = lemma_ascii_roundtrip_dark
(** [lemma_ascii_roundtrip_light] *)
let _lemma_ascii_roundtrip_light = lemma_ascii_roundtrip_light
(** [lemma_ascii_roundtrip_mixed] *)
let _lemma_ascii_roundtrip_mixed = lemma_ascii_roundtrip_mixed
(** [lemma_ascii_reject_bad_cell] *)
let _lemma_ascii_reject_bad_cell = lemma_ascii_reject_bad_cell
(** [lemma_ascii_reject_dangling] *)
let _lemma_ascii_reject_dangling = lemma_ascii_reject_dangling


(* ========================================================================
   Data.Image.Convert — format conversion
   ======================================================================== *)


(** Converters *)


(** [convert_gray_to_rgb] *)
let _convert_gray_to_rgb = convert_gray_to_rgb
(** [convert_gray_to_rgba] *)
let _convert_gray_to_rgba = convert_gray_to_rgba
(** [convert_rgb_to_rgba] *)
let _convert_rgb_to_rgba = convert_rgb_to_rgba
(** [convert_rgba_to_rgb] *)
let _convert_rgba_to_rgb = convert_rgba_to_rgb


(** Convert helper recursors *)


(** [gray_to_rgb_data] *)
let _gray_to_rgb_data = gray_to_rgb_data
(** [gray_to_rgba_data] *)
let _gray_to_rgba_data = gray_to_rgba_data
(** [rgb_to_rgba_data] *)
let _rgb_to_rgba_data = rgb_to_rgba_data
(** [rgba_to_rgb_data] *)
let _rgba_to_rgb_data = rgba_to_rgb_data


(** Convert lemmas *)


(** [lemma_gray_to_rgb_data_length] *)
let _lemma_gray_to_rgb_data_length = lemma_gray_to_rgb_data_length
(** [lemma_rgba_rgb_roundtrip] *)
let _lemma_rgba_rgb_roundtrip = lemma_rgba_rgb_roundtrip
(** [lemma_gray_rgba_rgb] *)
let _lemma_gray_rgba_rgb = lemma_gray_rgba_rgb
(** [lemma_gray_to_rgb_vector] *)
let _lemma_gray_to_rgb_vector = lemma_gray_to_rgb_vector
(** [lemma_rgb_rgba_rgb_vector] *)
let _lemma_rgb_rgba_rgb_vector = lemma_rgb_rgba_rgb_vector


(* ========================================================================
   Data.Image.PNG.CRC — CRC-32
   ======================================================================== *)


(** Values *)


(** [crc_poly] *)
let _crc_poly = crc_poly
(** [crc32_init] *)
let _crc32_init = crc32_init
(** [crc32_finalize] *)
let _crc32_finalize = crc32_finalize
(** [crc_step] *)
let _crc_step = crc_step
(** [crc_byte_fold] *)
let _crc_byte_fold = crc_byte_fold
(** [crc32_update] *)
let _crc32_update = crc32_update
(** [crc32] *)
let _crc32 = crc32
(** [crc32_of_bytes] *)
let _crc32_of_bytes = crc32_of_bytes


(** CRC lemmas (RFC known-answer vectors) *)


(** [lemma_crc32_empty] *)
let _lemma_crc32_empty = lemma_crc32_empty
(** [lemma_crc32_check_value] *)
let _lemma_crc32_check_value = lemma_crc32_check_value
(** [lemma_crc32_iend] *)
let _lemma_crc32_iend = lemma_crc32_iend
(** [lemma_crc32_table_length] *)
let _lemma_crc32_table_length = lemma_crc32_table_length
(** [lemma_crc32_ref_check_value] *)
let _lemma_crc32_ref_check_value = lemma_crc32_ref_check_value
(** [lemma_crc32_models_agree_check] *)
let _lemma_crc32_models_agree_check = lemma_crc32_models_agree_check


(* ========================================================================
   Data.Image.PNG.Filter — PNG scanline filters (ISO/IEC 15948 §9)
   ======================================================================== *)


(** Filter type and predictor *)


(** [filter_type] *)
let _filter_type = filter_type
(** [filter_byte] *)
let _filter_byte = filter_byte
(** [nth_byte] *)
let _nth_byte = nth_byte
(** [Filter.take] *)
let _filter_take = Data.Image.PNG.Filter.take
(** [Filter.drop] *)
let _filter_drop = Data.Image.PNG.Filter.drop
(** [paeth_predictor] *)
let _paeth_predictor = paeth_predictor
(** [avg_predictor] *)
let _avg_predictor = avg_predictor


(** Filter transforms *)


(** [filter_sub_aux] *)
let _filter_sub_aux = filter_sub_aux
(** [filter_up_aux] *)
let _filter_up_aux = filter_up_aux
(** [filter_average_aux] *)
let _filter_average_aux = filter_average_aux
(** [filter_paeth_aux] *)
let _filter_paeth_aux = filter_paeth_aux
(** [filter_scanline] *)
let _filter_scanline = filter_scanline


(** Reconstructors *)


(** [reconstruct_sub_aux] *)
let _reconstruct_sub_aux = reconstruct_sub_aux
(** [reconstruct_up_aux] *)
let _reconstruct_up_aux = reconstruct_up_aux
(** [reconstruct_average_aux] *)
let _reconstruct_average_aux = reconstruct_average_aux
(** [reconstruct_paeth_aux] *)
let _reconstruct_paeth_aux = reconstruct_paeth_aux
(** [reconstruct_scanline] *)
let _reconstruct_scanline = reconstruct_scanline


(** Filter lemmas *)


(** [lemma_wrap] *)
let _lemma_wrap = lemma_wrap
(** [lemma_nth_take] *)
let _lemma_nth_take = lemma_nth_take
(** [lemma_drop_all] *)
let _lemma_drop_all = lemma_drop_all
(** [Filter.lemma_take_all] *)
let _filter_lemma_take_all = Data.Image.PNG.Filter.lemma_take_all
(** [lemma_take_cons] *)
let _lemma_take_cons = lemma_take_cons
(** [lemma_drop_cons] *)
let _lemma_drop_cons = lemma_drop_cons
(** [lemma_sub_rt] *)
let _lemma_sub_rt = lemma_sub_rt
(** [lemma_up_rt] *)
let _lemma_up_rt = lemma_up_rt
(** [lemma_average_rt] *)
let _lemma_average_rt = lemma_average_rt
(** [lemma_paeth_rt] *)
let _lemma_paeth_rt = lemma_paeth_rt
(** [lemma_filter_roundtrip] *)
let _lemma_filter_roundtrip = lemma_filter_roundtrip
(** [lemma_paeth_predictor_selects] *)
let _lemma_paeth_predictor_selects = lemma_paeth_predictor_selects
(** [lemma_filter_sub_sample_row] *)
let _lemma_filter_sub_sample_row = lemma_filter_sub_sample_row
(** [lemma_filter_up_sample_row] *)
let _lemma_filter_up_sample_row = lemma_filter_up_sample_row
(** [lemma_paeth_predictor_nearest] *)
let _lemma_paeth_predictor_nearest = lemma_paeth_predictor_nearest
(** [lemma_filter_average_sample_row] *)
let _lemma_filter_average_sample_row = lemma_filter_average_sample_row
(** [lemma_filter_paeth_sample_row] *)
let _lemma_filter_paeth_sample_row = lemma_filter_paeth_sample_row


(* ========================================================================
   Data.Image.PNG.Deflate — stored-block framing
   ======================================================================== *)


(** Values *)


(** [nat_to_u16_le] *)
let _nat_to_u16_le = nat_to_u16_le
(** [u16_le_parse] *)
let _u16_le_parse = u16_le_parse
(** [Deflate.take_bytes] *)
let _deflate_take_bytes = Data.Image.PNG.Deflate.take_bytes
(** [deflate_stored_block] *)
let _deflate_stored_block = deflate_stored_block
(** [parse_stored_block] *)
let _parse_stored_block = parse_stored_block


(** Deflate lemmas *)


(** [Deflate.lemma_take_all] *)
let _deflate_lemma_take_all = Data.Image.PNG.Deflate.lemma_take_all
(** [lemma_take_bytes_append] *)
let _lemma_take_bytes_append = lemma_take_bytes_append
(** [lemma_u16_le_roundtrip] *)
let _lemma_u16_le_roundtrip = lemma_u16_le_roundtrip
(** [lemma_u16_le_roundtrip_suffix] *)
let _lemma_u16_le_roundtrip_suffix = lemma_u16_le_roundtrip_suffix
(** [lemma_stored_roundtrip] *)
let _lemma_stored_roundtrip = lemma_stored_roundtrip
(** [lemma_stored_roundtrip_suffix] *)
let _lemma_stored_roundtrip_suffix = lemma_stored_roundtrip_suffix


(* ========================================================================
   Data.Image.PNG.Zlib — zlib wrapper (RFC 1950) + Adler-32
   ======================================================================== *)


(** Values *)


(** [adler32_loop] *)
let _adler32_loop = adler32_loop
(** [adler32] *)
let _adler32 = adler32
(** [Zlib.nat_to_bytes_be4] *)
let _zlib_nat_to_bytes_be4 = Data.Image.PNG.Zlib.nat_to_bytes_be4
(** [parse_u32_be] *)
let _parse_u32_be = parse_u32_be
(** [zlib_wrap] *)
let _zlib_wrap = zlib_wrap
(** [validate_zlib_header] *)
let _validate_zlib_header = validate_zlib_header
(** [zlib_unwrap] *)
let _zlib_unwrap = zlib_unwrap


(** Zlib lemmas *)


(** [lemma_zlib_header_ok] *)
let _lemma_zlib_header_ok = lemma_zlib_header_ok
(** [lemma_adler32_loop_bound] *)
let _lemma_adler32_loop_bound = lemma_adler32_loop_bound
(** [lemma_adler32_bound] *)
let _lemma_adler32_bound = lemma_adler32_bound
(** [lemma_u32_be_roundtrip] *)
let _lemma_u32_be_roundtrip = lemma_u32_be_roundtrip
(** [lemma_u32_be_roundtrip_suffix] *)
let _lemma_u32_be_roundtrip_suffix = lemma_u32_be_roundtrip_suffix
(** [lemma_zlib_roundtrip] *)
let _lemma_zlib_roundtrip = lemma_zlib_roundtrip
(** [lemma_adler32_check_value] *)
let _lemma_adler32_check_value = lemma_adler32_check_value
(** [lemma_zlib_fcheck] *)
let _lemma_zlib_fcheck = lemma_zlib_fcheck


(* ========================================================================
   Data.Image.PNG.Encode — full PNG encoder (ISO/IEC 15948)
   ======================================================================== *)


(** Values *)


(** [png_signature] *)
let _png_signature = png_signature
(** [Encode.nat_to_bytes_be4] *)
let _encode_nat_to_bytes_be4 = Data.Image.PNG.Encode.nat_to_bytes_be4
(** [uint32_to_bytes_be] *)
let _uint32_to_bytes_be = uint32_to_bytes_be
(** [make_chunk] *)
let _make_chunk = make_chunk
(** [png_color_type] *)
let _png_color_type = png_color_type
(** [make_ihdr] *)
let _make_ihdr = make_ihdr
(** [Encode.take_bytes] *)
let _encode_take_bytes = Data.Image.PNG.Encode.take_bytes
(** [split_scanlines] *)
let _split_scanlines = split_scanlines
(** [filter_scanline_none] *)
let _filter_scanline_none = filter_scanline_none
(** [filter_all_scanlines] *)
let _filter_all_scanlines = filter_all_scanlines
(** [filtered_data_length] *)
let _filtered_data_length = filtered_data_length
(** [encode_png] *)
let _encode_png = encode_png


(** Encode lemmas *)


(** [lemma_signature_length] *)
let _lemma_signature_length = lemma_signature_length
(** [lemma_png_signature_bytes] *)
let _lemma_png_signature_bytes = lemma_png_signature_bytes
(** [lemma_take_bytes_length] *)
let _lemma_take_bytes_length = lemma_take_bytes_length
(** [lemma_take_bytes_n] *)
let _lemma_take_bytes_n = lemma_take_bytes_n
(** [lemma_png_encode_valid] *)
let _lemma_png_encode_valid = lemma_png_encode_valid
(** [lemma_filtered_length_eq] *)
let _lemma_filtered_length_eq = lemma_filtered_length_eq
(** [lemma_encode_filtered_length] *)
let _lemma_encode_filtered_length = lemma_encode_filtered_length


(* ========================================================================
   Data.Image.Pulse — image-format tag dispatch
   ======================================================================== *)


(** Tag values *)


(** [Data.Image.Pulse.tag_of] *)
let _img_tag_of = Data.Image.Pulse.tag_of
(** [Data.Image.Pulse.tag_to_type] *)
let _img_tag_to_type = Data.Image.Pulse.tag_to_type
(** [Data.Image.Pulse.lemma_tag_roundtrip] *)
let _img_lemma_tag_roundtrip = Data.Image.Pulse.lemma_tag_roundtrip


(** Pulse roundtrip + leaf fns *)


(** [lemma_pulse_img_fmt_roundtrip] *)
let _lemma_pulse_img_fmt_roundtrip = lemma_pulse_img_fmt_roundtrip
(** [encode_img_fmt] *)
let _encode_img_fmt = encode_img_fmt
(** [decode_img_fmt] *)
let _decode_img_fmt = decode_img_fmt


(* ========================================================================
   Data.Image.PNG.Pulse — png-chunk tag dispatch
   ======================================================================== *)


(** Tag values *)


(** [Data.Image.PNG.Pulse.tag_of] *)
let _png_tag_of = Data.Image.PNG.Pulse.tag_of
(** [Data.Image.PNG.Pulse.tag_to_type] *)
let _png_tag_to_type = Data.Image.PNG.Pulse.tag_to_type
(** [Data.Image.PNG.Pulse.lemma_tag_roundtrip] *)
let _png_lemma_tag_roundtrip = Data.Image.PNG.Pulse.lemma_tag_roundtrip


(** Pulse roundtrip + leaf fns *)


(** [lemma_pulse_png_chunk_roundtrip] *)
let _lemma_pulse_png_chunk_roundtrip = lemma_pulse_png_chunk_roundtrip
(** [encode_png_chunk] *)
let _encode_png_chunk = encode_png_chunk
(** [decode_png_chunk] *)
let _decode_png_chunk = decode_png_chunk


(* ========================================================================
   Data.Image.QRCode.Types — core QR types
   ======================================================================== *)


(** [ecl] *)
let _ecl = ecl
(** [encoding_mode] *)
let _encoding_mode = encoding_mode
(** [version] (refined nat) — anchored via a representative function *)
let _version = (fun (_: version) -> ())
(** [module_t] *)
let _module_t = (fun (_: module_t) -> ())
(** [qr_matrix] (record) *)
let _qr_matrix = (fun (_: qr_matrix) -> ())
(** [matrix_size] *)
let _matrix_size = matrix_size
(** [valid_matrix] *)
let _valid_matrix = valid_matrix


(* ========================================================================
   Data.Image.QRCode.GF256 — GF(2^8) field arithmetic
   ======================================================================== *)


(** Values *)


(** [gf256] *)
let _gf256 = (fun (_: gf256) -> ())
(** [gf_add] *)
let _gf_add = gf_add
(** [nat_xor] *)
let _nat_xor = nat_xor
(** [xor8] *)
let _xor8 = xor8
(** [GF256.pow2] *)
let _gf256_pow2 = Data.Image.QRCode.GF256.pow2
(** [gf_mul_go] *)
let _gf_mul_go = gf_mul_go
(** [red] *)
let _red = red
(** [gf_mul] *)
let _gf_mul = gf_mul
(** [gf_exp_table] *)
let _gf_exp_table = gf_exp_table
(** [gf_log_table] *)
let _gf_log_table = gf_log_table
(** [gf_exp] *)
let _gf_exp = gf_exp
(** [gf_log] *)
let _gf_log = gf_log


(** Field lemmas (add laws, mul zero/identity, known answers) *)


(** [lemma_pow2_succ] *)
let _lemma_pow2_succ = lemma_pow2_succ
(** [lemma_half_lt] *)
let _lemma_half_lt = lemma_half_lt
(** [lemma_xor_comm] *)
let _lemma_xor_comm = lemma_xor_comm
(** [lemma_xor_self] *)
let _lemma_xor_self = lemma_xor_self
(** [lemma_xor_zero] *)
let _lemma_xor_zero = lemma_xor_zero
(** [lemma_xor_assoc] *)
let _lemma_xor_assoc = lemma_xor_assoc
(** [lemma_xor_bounded] *)
let _lemma_xor_bounded = lemma_xor_bounded
(** [lemma_xor8_bounded] *)
let _lemma_xor8_bounded = lemma_xor8_bounded
(** [lemma_xor_zero8] *)
let _lemma_xor_zero8 = lemma_xor_zero8
(** [lemma_gf_mul_go_bounded] *)
let _lemma_gf_mul_go_bounded = lemma_gf_mul_go_bounded
(** [lemma_red_bounded] *)
let _lemma_red_bounded = lemma_red_bounded
(** [lemma_gf_mul_go_linear] *)
let _lemma_gf_mul_go_linear = lemma_gf_mul_go_linear
(** [lemma_gf_add_identity] *)
let _lemma_gf_add_identity = lemma_gf_add_identity
(** [lemma_gf_add_self_zero] *)
let _lemma_gf_add_self_zero = lemma_gf_add_self_zero
(** [lemma_gf_add_comm] *)
let _lemma_gf_add_comm = lemma_gf_add_comm
(** [lemma_gf_add_assoc] *)
let _lemma_gf_add_assoc = lemma_gf_add_assoc
(** [lemma_gf_mul_zero] *)
let _lemma_gf_mul_zero = lemma_gf_mul_zero
(** [lemma_gf_mul_go_one] *)
let _lemma_gf_mul_go_one = lemma_gf_mul_go_one
(** [lemma_gf_mul_identity] *)
let _lemma_gf_mul_identity = lemma_gf_mul_identity
(** [lemma_gf_mul_known_answer] *)
let _lemma_gf_mul_known_answer = lemma_gf_mul_known_answer
(** [lemma_gf_mul_alpha_pow] *)
let _lemma_gf_mul_alpha_pow = lemma_gf_mul_alpha_pow


(** Structural tower lemmas (Phase 6b) — xor/pow2/cancel/trunc/disjoint/
    bits_xor/reduce/clmul/grid/subst *)


(** [lemma_nat_xor_double] *)
let _lemma_nat_xor_double = lemma_nat_xor_double
(** [lemma_xor_bit_even_base] *)
let _lemma_xor_bit_even_base = lemma_xor_bit_even_base
(** [lemma_xor_bit_even] *)
let _lemma_xor_bit_even = lemma_xor_bit_even
(** [lemma_xor_00] *)
let _lemma_xor_00 = lemma_xor_00
(** [lemma_xor_pad] *)
let _lemma_xor_pad = lemma_xor_pad
(** [lemma_cancel_pow2] *)
let _lemma_cancel_pow2 = lemma_cancel_pow2
(** [lemma_xor_trunc_cancel] *)
let _lemma_xor_trunc_cancel = lemma_xor_trunc_cancel
(** [lemma_pow2_mono] *)
let _lemma_pow2_mono = lemma_pow2_mono
(** [lemma_xor_shift_out] *)
let _lemma_xor_shift_out = lemma_xor_shift_out
(** [lemma_xor_trunc_both] *)
let _lemma_xor_trunc_both = lemma_xor_trunc_both
(** [lemma_pow2_pos_succ] *)
let _lemma_pow2_pos_succ = lemma_pow2_pos_succ
(** [lemma_pow2_pos_mono] *)
let _lemma_pow2_pos_mono = lemma_pow2_pos_mono
(** [lemma_pow2_pos_add] *)
let _lemma_pow2_pos_add = lemma_pow2_pos_add
(** [lemma_bit_shift] *)
let _lemma_bit_shift = lemma_bit_shift
(** [lemma_bit_low] *)
let _lemma_bit_low = lemma_bit_low
(** [lemma_xor_disjoint] *)
let _lemma_xor_disjoint = lemma_xor_disjoint
(** [lemma_xor_disjoint_high] *)
let _lemma_xor_disjoint_high = lemma_xor_disjoint_high
(** [lemma_bit_bounded] *)
let _lemma_bit_bounded = lemma_bit_bounded
(** [lemma_bits_sum_mod] *)
let _lemma_bits_sum_mod = lemma_bits_sum_mod
(** [lemma_bits_sum_recover] *)
let _lemma_bits_sum_recover = lemma_bits_sum_recover
(** [lemma_bits_sum_bounded] *)
let _lemma_bits_sum_bounded = lemma_bits_sum_bounded
(** [lemma_xor_disjoint_bit] *)
let _lemma_xor_disjoint_bit = lemma_xor_disjoint_bit
(** [lemma_bits_xor_eq_sum] *)
let _lemma_bits_xor_eq_sum = lemma_bits_xor_eq_sum
(** [lemma_bits_xor_recover] *)
let _lemma_bits_xor_recover = lemma_bits_xor_recover
(** [lemma_reduce_from_drop_high] *)
let _lemma_reduce_from_drop_high = lemma_reduce_from_drop_high
(** [lemma_reduce_double] *)
let _lemma_reduce_double = lemma_reduce_double
(** [lemma_raw_mul_doubles_bound] *)
let _lemma_raw_mul_doubles_bound = lemma_raw_mul_doubles_bound
(** [lemma_raw_mul_go_linear] *)
let _lemma_raw_mul_go_linear = lemma_raw_mul_go_linear
(** [lemma_xor_16_eq_8] *)
let _lemma_xor_16_eq_8 = lemma_xor_16_eq_8
(** [lemma_reduce_id] *)
let _lemma_reduce_id = lemma_reduce_id
(** [lemma_nat_xor_bit] *)
let _lemma_nat_xor_bit = lemma_nat_xor_bit
(** [lemma_select_xor_bool] *)
let _lemma_select_xor_bool = lemma_select_xor_bool
(** [lemma_reduce_step_xor] *)
let _lemma_reduce_step_xor = lemma_reduce_step_xor
(** [lemma_step_xor] *)
let _lemma_step_xor = lemma_step_xor
(** [lemma_reduce_from_base] *)
let _lemma_reduce_from_base = lemma_reduce_from_base
(** [lemma_xor16_middle] *)
let _lemma_xor16_middle = lemma_xor16_middle
(** [lemma_xor16_double_gen] *)
let _lemma_xor16_double_gen = lemma_xor16_double_gen
(** [lemma_raw_mul_go_bilinear] *)
let _lemma_raw_mul_go_bilinear = lemma_raw_mul_go_bilinear
(** [lemma_grid_t_zero] *)
let _lemma_grid_t_zero = lemma_grid_t_zero
(** [lemma_row_append] *)
let _lemma_row_append = lemma_row_append
(** [lemma_grid_swap] *)
let _lemma_grid_swap = lemma_grid_swap
(** [lemma_nat_xor_shl] *)
let _lemma_nat_xor_shl = lemma_nat_xor_shl
(** [lemma_xor16_shl] *)
let _lemma_xor16_shl = lemma_xor16_shl
(** [lemma_bits_xor_bounded] *)
let _lemma_bits_xor_bounded = lemma_bits_xor_bounded
(** [lemma_shl_bits_eq_mul] *)
let _lemma_shl_bits_eq_mul = lemma_shl_bits_eq_mul
(** [lemma_mul_eq_shl_bits] *)
let _lemma_mul_eq_shl_bits = lemma_mul_eq_shl_bits
(** [lemma_fold_xor_scale] *)
let _lemma_fold_xor_scale = lemma_fold_xor_scale
(** [lemma_fold_col_eq_fold_xor] *)
let _lemma_fold_col_eq_fold_xor = lemma_fold_col_eq_fold_xor
(** [lemma_fold_xor_eq_shl_bits] *)
let _lemma_fold_xor_eq_shl_bits = lemma_fold_xor_eq_shl_bits
(** [lemma_xor_scale2] *)
let _lemma_xor_scale2 = lemma_xor_scale2
(** [lemma_fold_col_clmul] *)
let _lemma_fold_col_clmul = lemma_fold_col_clmul
(** [lemma_col_g] *)
let _lemma_col_g = lemma_col_g
(** [lemma_pow2_eq_pow2_pos] *)
let _lemma_pow2_eq_pow2_pos = lemma_pow2_eq_pow2_pos
(** [lemma_xor_zero16] *)
let _lemma_xor_zero16 = lemma_xor_zero16
(** [lemma_grid_t_clmul_bounded] *)
let _lemma_grid_t_clmul_bounded = lemma_grid_t_clmul_bounded
(** [lemma_clmul_go_grid_t] *)
let _lemma_clmul_go_grid_t = lemma_clmul_go_grid_t
(** [lemma_clmul_dsum] *)
let _lemma_clmul_dsum = lemma_clmul_dsum
(** [lemma_col_transpose] *)
let _lemma_col_transpose = lemma_col_transpose
(** [lemma_grid_t_transpose] *)
let _lemma_grid_t_transpose = lemma_grid_t_transpose
(** [lemma_grid_transpose] *)
let _lemma_grid_transpose = lemma_grid_transpose
(** [lemma_clmul_grid_swap] *)
let _lemma_clmul_grid_swap = lemma_clmul_grid_swap
(** [lemma_fold_row_ext] *)
let _lemma_fold_row_ext = lemma_fold_row_ext
(** [lemma_grid_ext] *)
let _lemma_grid_ext = lemma_grid_ext
(** [lemma_dsum_sym] *)
let _lemma_dsum_sym = lemma_dsum_sym
(** [lemma_clmul_sym] *)
let _lemma_clmul_sym = lemma_clmul_sym
(** [lemma_bit_xor_scale] *)
let _lemma_bit_xor_scale = lemma_bit_xor_scale
(** [lemma_subst_hi_xor] *)
let _lemma_subst_hi_xor = lemma_subst_hi_xor
(** [lemma_bits_xor_xor] *)
let _lemma_bits_xor_xor = lemma_bits_xor_xor
(** [lemma_subst_xor] *)
let _lemma_subst_xor = lemma_subst_xor
(** [lemma_bit_zero] *)
let _lemma_bit_zero = lemma_bit_zero
(** [lemma_subst_hi_zero] *)
let _lemma_subst_hi_zero = lemma_subst_hi_zero
(** [lemma_subst_id] *)
let _lemma_subst_id = lemma_subst_id
(** [lemma_subst_hi_bound_tight] *)
let _lemma_subst_hi_bound_tight = lemma_subst_hi_bound_tight
(** [lemma_subst_hi_bound] *)
let _lemma_subst_hi_bound = lemma_subst_hi_bound
(** [lemma_subst_bound] *)
let _lemma_subst_bound = lemma_subst_bound
(** [lemma_subst_lt256] *)
let _lemma_subst_lt256 = lemma_subst_lt256
(** [lemma_reduce_sub_bounded] *)
let _lemma_reduce_sub_bounded = lemma_reduce_sub_bounded
(** [lemma_reduce_sub_id] *)
let _lemma_reduce_sub_id = lemma_reduce_sub_id
(** [lemma_subst_hi_double] *)
let _lemma_subst_hi_double = lemma_subst_hi_double
(** [lemma_reduce_sub_double] *)
let _lemma_reduce_sub_double = lemma_reduce_sub_double
(** [lemma_reduce_sub_xor] *)
let _lemma_reduce_sub_xor = lemma_reduce_sub_xor
(** [lemma_xor16_double_of_xor8] *)
let _lemma_xor16_double_of_xor8 = lemma_xor16_double_of_xor8
(** [lemma_red_xor] *)
let _lemma_red_xor = lemma_red_xor
(** [lemma_bit_pow2_self] *)
let _lemma_bit_pow2_self = lemma_bit_pow2_self
(** [lemma_bit_pow2_lt] *)
let _lemma_bit_pow2_lt = lemma_bit_pow2_lt
(** [lemma_bit_pow2_gt] *)
let _lemma_bit_pow2_gt = lemma_bit_pow2_gt
(** [lemma_bit_pow2] *)
let _lemma_bit_pow2 = lemma_bit_pow2
(** [lemma_xor_zero16_r] *)
let _lemma_xor_zero16_r = lemma_xor_zero16_r
(** [lemma_powj_nsub_bound] *)
let _lemma_powj_nsub_bound = lemma_powj_nsub_bound
(** [lemma_subst_hi_powj_lo] *)
let _lemma_subst_hi_powj_lo = lemma_subst_hi_powj_lo
(** [lemma_subst_hi_powj_hi] *)
let _lemma_subst_hi_powj_hi = lemma_subst_hi_powj_hi
(** [lemma_subst_hi_powj] *)
let _lemma_subst_hi_powj = lemma_subst_hi_powj
(** [lemma_bits_xor_powj_zero_go] *)
let _lemma_bits_xor_powj_zero_go = lemma_bits_xor_powj_zero_go
(** [lemma_bits_xor_powj_zero] *)
let _lemma_bits_xor_powj_zero = lemma_bits_xor_powj_zero
(** [lemma_subst_powj] *)
let _lemma_subst_powj = lemma_subst_powj


(* ========================================================================
   Data.Image.QRCode.ReedSolomon — generator polynomial + ECC
   ======================================================================== *)


(** Values *)


(** [replicate] *)
let _replicate = replicate
(** [poly_mul_x_alpha] *)
let _poly_mul_x_alpha = poly_mul_x_alpha
(** [rs_generator_poly] *)
let _rs_generator_poly = rs_generator_poly
(** [rs_subtract] *)
let _rs_subtract = rs_subtract
(** [poly_div_step] *)
let _poly_div_step = poly_div_step
(** [rs_divide] *)
let _rs_divide = rs_divide
(** [rs_generate_ec] *)
let _rs_generate_ec = rs_generate_ec


(** RS lemmas *)


(** [lemma_poly_mul_x_alpha_length] *)
let _lemma_poly_mul_x_alpha_length = lemma_poly_mul_x_alpha_length
(** [lemma_gen_poly_length] *)
let _lemma_gen_poly_length = lemma_gen_poly_length
(** [lemma_gen_poly_monic] *)
let _lemma_gen_poly_monic = lemma_gen_poly_monic
(** [lemma_replicate_length] *)
let _lemma_replicate_length = lemma_replicate_length
(** [lemma_rs_subtract_length] *)
let _lemma_rs_subtract_length = lemma_rs_subtract_length
(** [lemma_poly_div_step_length] *)
let _lemma_poly_div_step_length = lemma_poly_div_step_length
(** [lemma_rs_divide_length] *)
let _lemma_rs_divide_length = lemma_rs_divide_length
(** [lemma_rs_ec_length] *)
let _lemma_rs_ec_length = lemma_rs_ec_length


(* ========================================================================
   Data.Image.QRCode.DataEncoding — capacity / bit / string encoding
   ======================================================================== *)


(** Values *)


(** [DataEncoding.pow2] *)
let _de_pow2 = Data.Image.QRCode.DataEncoding.pow2
(** [repl] *)
let _repl = repl
(** [byte_count_bits] *)
let _byte_count_bits = byte_count_bits
(** [total_data_codewords] *)
let _total_data_codewords = total_data_codewords
(** [nat_to_bits] *)
let _nat_to_bits = nat_to_bits
(** [byte_to_bits] *)
let _byte_to_bits = byte_to_bits
(** [byte_of_8bits] *)
let _byte_of_8bits = byte_of_8bits
(** [bits_to_nat] *)
let _bits_to_nat = bits_to_nat
(** [bits_to_bytes_b0] *)
let _bits_to_bytes_b0 = bits_to_bytes_b0
(** [bits_to_bytes] *)
let _bits_to_bytes = bits_to_bytes
(** [pad_bytes] *)
let _pad_bytes = pad_bytes
(** [encode_bytes] *)
let _encode_bytes = encode_bytes
(** [string_to_latin1_bytes] *)
let _string_to_latin1_bytes = string_to_latin1_bytes
(** [encode_uri] *)
let _encode_uri = encode_uri


(** DataEncoding lemmas *)


(** [lemma_b0_length] *)
let _lemma_b0_length = lemma_b0_length
(** [lemma_bits_to_bytes_length] *)
let _lemma_bits_to_bytes_length = lemma_bits_to_bytes_length
(** [lemma_bits_to_nat_bounded] *)
let _lemma_bits_to_nat_bounded = lemma_bits_to_nat_bounded
(** [lemma_pad_bytes_length] *)
let _lemma_pad_bytes_length = lemma_pad_bytes_length
(** [lemma_bits_to_nat_roundtrip] *)
let _lemma_bits_to_nat_roundtrip = lemma_bits_to_nat_roundtrip
(** [lemma_pow2_positive] *)
let _lemma_pow2_positive = lemma_pow2_positive
(** [lemma_nat_to_bits_length] *)
let _lemma_nat_to_bits_length = lemma_nat_to_bits_length
(** [lemma_repl_length] *)
let _lemma_repl_length = lemma_repl_length
(** [lemma_byte_count_bits_range] *)
let _lemma_byte_count_bits_range = lemma_byte_count_bits_range
(** [lemma_byte_to_bits_length] *)
let _lemma_byte_to_bits_length = lemma_byte_to_bits_length
(** [lemma_concatMap_byte_to_bits_length] *)
let _lemma_concatMap_byte_to_bits_length = lemma_concatMap_byte_to_bits_length
(** [lemma_byte_of_8bits_roundtrip] *)
let _lemma_byte_of_8bits_roundtrip = lemma_byte_of_8bits_roundtrip
(** [lemma_tdc_adjacent] *)
let _lemma_tdc_adjacent = lemma_tdc_adjacent
(** [lemma_capacity_monotonic] *)
let _lemma_capacity_monotonic = lemma_capacity_monotonic
(** [lemma_tdc_cells] *)
let _lemma_tdc_cells = lemma_tdc_cells
(** [lemma_encode_bytes_length] *)
let _lemma_encode_bytes_length = lemma_encode_bytes_length
(** [lemma_encode_uri_length] *)
let _lemma_encode_uri_length = lemma_encode_uri_length
(** [lemma_string_to_latin1_bytes_length] *)
let _lemma_string_to_latin1_bytes_length = lemma_string_to_latin1_bytes_length
(** [lemma_b1_length] *)
let _lemma_b1_length = lemma_b1_length
(** [lemma_b2_length] *)
let _lemma_b2_length = lemma_b2_length
(** [lemma_b3_length] *)
let _lemma_b3_length = lemma_b3_length
(** [lemma_b4_length] *)
let _lemma_b4_length = lemma_b4_length
(** [lemma_b5_length] *)
let _lemma_b5_length = lemma_b5_length
(** [lemma_b6_length] *)
let _lemma_b6_length = lemma_b6_length
(** [lemma_b7_length] *)
let _lemma_b7_length = lemma_b7_length


(* ========================================================================
   Data.Image.QRCode.LUT — function-module / data-position tables
   ======================================================================== *)


(** [function_module_table_v2] *)
let _function_module_table_v2 = function_module_table_v2
(** [data_position_table_v2] *)
let _data_position_table_v2 = data_position_table_v2
(** [is_function_module_lut] *)
let _is_function_module_lut = is_function_module_lut
(** [is_free_lut] *)
let _is_free_lut = is_free_lut
(** [data_positions] *)
let _data_positions = data_positions
(** [lemma_function_table_square] *)
let _lemma_function_table_square = lemma_function_table_square
(** [lemma_data_position_count] *)
let _lemma_data_position_count = lemma_data_position_count
(** [lemma_function_free_partition] *)
let _lemma_function_free_partition = lemma_function_free_partition


(* ========================================================================
   Data.Image.QRCode.Matrix — placement / mask / render grid
   ======================================================================== *)


(** Values *)


(** [get_module] *)
let _get_module = get_module
(** [set_module] *)
let _set_module = set_module
(** [make_empty_matrix] *)
let _make_empty_matrix = make_empty_matrix
(** [finder_pattern] *)
let _finder_pattern = finder_pattern
(** [place_7x7_pattern] *)
let _place_7x7_pattern = place_7x7_pattern
(** [place_finder_patterns] *)
let _place_finder_patterns = place_finder_patterns
(** [place_timing_patterns] *)
let _place_timing_patterns = place_timing_patterns
(** [alignment_pattern] *)
let _alignment_pattern = alignment_pattern
(** [alignment_positions] *)
let _alignment_positions = alignment_positions
(** [place_alignment_patterns] *)
let _place_alignment_patterns = place_alignment_patterns
(** [place_reserved_areas] *)
let _place_reserved_areas = place_reserved_areas
(** [Matrix.pow2_pos] *)
let _matrix_pow2_pos = Data.Image.QRCode.Matrix.pow2_pos
(** [bytes_to_bits] *)
let _bytes_to_bits = bytes_to_bits
(** [place_data] *)
let _place_data = place_data
(** [mask_condition] *)
let _mask_condition = mask_condition
(** [is_function_module] *)
let _is_function_module = is_function_module
(** [apply_mask] *)
let _apply_mask = apply_mask
(** [mask_penalty] *)
let _mask_penalty = mask_penalty
(** [select_best_mask] *)
let _select_best_mask = select_best_mask


(** Matrix lemmas *)


(** [lemma_finder_pattern_size] *)
let _lemma_finder_pattern_size = lemma_finder_pattern_size
(** [lemma_finder_pattern_corners] *)
let _lemma_finder_pattern_corners = lemma_finder_pattern_corners
(** [lemma_matrix_size] *)
let _lemma_matrix_size = lemma_matrix_size
(** [lemma_alignment_pattern_size] *)
let _lemma_alignment_pattern_size = lemma_alignment_pattern_size
(** [lemma_alignment_pattern_corners] *)
let _lemma_alignment_pattern_corners = lemma_alignment_pattern_corners
(** [lemma_mask0] *)
let _lemma_mask0 = lemma_mask0
(** [lemma_mask1] *)
let _lemma_mask1 = lemma_mask1
(** [lemma_mask2] *)
let _lemma_mask2 = lemma_mask2
(** [lemma_mask3] *)
let _lemma_mask3 = lemma_mask3
(** [lemma_mask4] *)
let _lemma_mask4 = lemma_mask4
(** [lemma_mask5] *)
let _lemma_mask5 = lemma_mask5
(** [lemma_mask6] *)
let _lemma_mask6 = lemma_mask6
(** [lemma_mask7] *)
let _lemma_mask7 = lemma_mask7
(** [lemma_select_best_mask_bounds] *)
let _lemma_select_best_mask_bounds = lemma_select_best_mask_bounds


(* ========================================================================
   Data.Image.QRCode.Encode — format info / BCH / full encoder
   ======================================================================== *)


(** Values *)


(** [ecc_codewords_per_block] *)
let _ecc_codewords_per_block = ecc_codewords_per_block
(** [ecl_indicator] *)
let _ecl_indicator = ecl_indicator
(** [Encode.pow2_pos] *)
let _enc_pow2_pos = Data.Image.QRCode.Encode.pow2_pos
(** [bch_15_5_encode] *)
let _bch_15_5_encode = bch_15_5_encode
(** [format_info] *)
let _format_info = format_info
(** [place_format_info] *)
let _place_format_info = place_format_info
(** [encode_qr_uri] *)
let _encode_qr_uri = encode_qr_uri


(** Encode lemmas (known-answer vectors) *)


(** [lemma_ecc_v1] *)
let _lemma_ecc_v1 = lemma_ecc_v1
(** [lemma_ecc_range] *)
let _lemma_ecc_range = lemma_ecc_range
(** [lemma_ecl_indicator] *)
let _lemma_ecl_indicator = lemma_ecl_indicator
(** [lemma_bch_zero] *)
let _lemma_bch_zero = lemma_bch_zero
(** [lemma_bch_d5] *)
let _lemma_bch_d5 = lemma_bch_d5
(** [lemma_format_info_m0] *)
let _lemma_format_info_m0 = lemma_format_info_m0
(** [lemma_format_info_m3] *)
let _lemma_format_info_m3 = lemma_format_info_m3
(** [lemma_format_info_l0] *)
let _lemma_format_info_l0 = lemma_format_info_l0
(** [lemma_format_info_q0] *)
let _lemma_format_info_q0 = lemma_format_info_q0
(** [lemma_format_info_h0] *)
let _lemma_format_info_h0 = lemma_format_info_h0
(** [lemma_format_info_l7] *)
let _lemma_format_info_l7 = lemma_format_info_l7


(* ========================================================================
   Data.Image.QRCode.Render — matrix → image
   ======================================================================== *)


(** [encode_image] *)
let _encode_image = encode_image


(* ========================================================================
   Data.Image.QRCode.Pulse — qr-mode tag dispatch
   ======================================================================== *)


(** Tag values *)


(** [Data.Image.QRCode.Pulse.tag_of] *)
let _qr_tag_of = Data.Image.QRCode.Pulse.tag_of
(** [Data.Image.QRCode.Pulse.tag_to_type] *)
let _qr_tag_to_type = Data.Image.QRCode.Pulse.tag_to_type
(** [Data.Image.QRCode.Pulse.lemma_tag_roundtrip] *)
let _qr_lemma_tag_roundtrip = Data.Image.QRCode.Pulse.lemma_tag_roundtrip


(** Pulse roundtrip + leaf fns *)


(** [lemma_pulse_qr_mode_roundtrip] *)
let _lemma_pulse_qr_mode_roundtrip = lemma_pulse_qr_mode_roundtrip
(** [encode_qr_mode] *)
let _encode_qr_mode = encode_qr_mode
(** [decode_qr_mode] *)
let _decode_qr_mode = decode_qr_mode


#pop-options
