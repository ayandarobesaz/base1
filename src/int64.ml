open! Import
open! Stdlib.Int64

module T = struct
  type t = int64 [@@deriving_inline globalize, hash, sexp, sexp_grammar]

  let (globalize : (t[@ocaml.local]) -> t) = (globalize_int64 : (t[@ocaml.local]) -> t)

  let (hash_fold_t : Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state) =
    hash_fold_int64

  and (hash : t -> Ppx_hash_lib.Std.Hash.hash_value) =
    let func = hash_int64 in
    fun x -> func x
  ;;

  let t_of_sexp = (int64_of_sexp : Sexplib0.Sexp.t -> t)
  let sexp_of_t = (sexp_of_int64 : t -> Sexplib0.Sexp.t)
  let (t_sexp_grammar : t Sexplib0.Sexp_grammar.t) = int64_sexp_grammar

  [@@@end]

  let hashable : t Hashable.t = { hash; compare; sexp_of_t }
  let compare = Int64_replace_polymorphic_compare.compare
  let to_string = to_string
  let of_string = of_string
  let of_string_opt = of_string_opt
end

include T
include Comparator.Make (T)

let num_bits = 64
let float_lower_bound = Float0.lower_bound_for_int num_bits
let float_upper_bound = Float0.upper_bound_for_int num_bits
let float_of_bits = float_of_bits

external bits_of_float
  :  (float[@local_opt])
  -> (int64[@local_opt])
  = "caml_int64_bits_of_float" "caml_int64_bits_of_float_unboxed"
  [@@unboxed] [@@noalloc]

let shift_right_logical = shift_right_logical
let shift_right = shift_right
let shift_left = shift_left
let bit_not = lognot
let bit_xor = logxor
let bit_or = logor
let bit_and = logand
let min_value = min_int
let max_value = max_int
let abs = abs
let pred = pred
let succ = succ
let pow = Int_math.Private.int64_pow
let rem = rem
let neg = neg
let minus_one = minus_one
let one = one
let zero = zero
let to_float = to_float
let of_float_unchecked = Stdlib.Int64.of_float

let of_float f =
  if Float_replace_polymorphic_compare.( >= ) f float_lower_bound
     && Float_replace_polymorphic_compare.( <= ) f float_upper_bound
  then Stdlib.Int64.of_float f
  else
    Printf.invalid_argf
      "Int64.of_float: argument (%f) is out of range or NaN"
      (Float0.box f)
      ()
;;

let ( ** ) b e = pow b e

external bswap64 : (t[@local_opt]) -> (t[@local_opt]) = "%bswap_int64"

let[@inline always] bswap16 x = Stdlib.Int64.shift_right_logical (bswap64 x) 48

let[@inline always] bswap32 x =
  (* This is strictly better than coercing to an int32 to perform byteswap. Coercing
     from an int32 will add unnecessary shift operations to sign extend the number
     appropriately.
  *)
  Stdlib.Int64.shift_right_logical (bswap64 x) 32
;;

let[@inline always] bswap48 x = Stdlib.Int64.shift_right_logical (bswap64 x) 16

include Comparable.With_zero (struct
  include T

  let zero = zero
end)

(* Open replace_polymorphic_compare after including functor instantiations so they do not
   shadow its definitions. This is here so that efficient versions of the comparison
   functions are available within this module. *)
open Int64_replace_polymorphic_compare

let invariant (_ : t) = ()
let between t ~low ~high = low <= t && t <= high
let clamp_unchecked t ~min:min_ ~max:max_ = min t max_ |> max min_

let clamp_exn t ~min ~max =
  assert (min <= max);
  clamp_unchecked t ~min ~max
;;

let clamp t ~min ~max =
  if min > max
  then
    Or_error.error_s
      (Sexp.message
         "clamp requires [min <= max]"
         [ "min", T.sexp_of_t min; "max", T.sexp_of_t max ])
  else Ok (clamp_unchecked t ~min ~max)
;;

let incr r = r := add !r one
let decr r = r := sub !r one

external of_int64 : (t[@local_opt]) -> (t[@local_opt]) = "%identity"

let of_int64_exn = of_int64
let to_int64 t = t
let popcount = Popcount.int64_popcount

module Conv = Int_conversions

external to_int_trunc : (t[@local_opt]) -> int = "%int64_to_int"
external to_int32_trunc : (int64[@local_opt]) -> (int32[@local_opt]) = "%int64_to_int32"

external to_nativeint_trunc
  :  (int64[@local_opt])
  -> (nativeint[@local_opt])
  = "%int64_to_nativeint"

external of_int : (int[@local_opt]) -> (int64[@local_opt]) = "%int64_of_int"
external of_int32 : (int32[@local_opt]) -> (int64[@local_opt]) = "%int64_of_int32"

let of_int_exn = of_int
let to_int = Conv.int64_to_int
let to_int_exn = Conv.int64_to_int_exn
let of_int32_exn = of_int32
let to_int32 = Conv.int64_to_int32
let to_int32_exn = Conv.int64_to_int32_exn

external of_nativeint : (nativeint[@local_opt]) -> (t[@local_opt]) = "%int64_of_nativeint"

let of_nativeint_exn = of_nativeint
let to_nativeint = Conv.int64_to_nativeint
let to_nativeint_exn = Conv.int64_to_nativeint_exn

module Pow2 = struct
  open! Import
  open Int64_replace_polymorphic_compare

  let raise_s = Error.raise_s

  let non_positive_argument () =
    Printf.invalid_argf "argument must be strictly positive" ()
  ;;

  let ( lor ) = Stdlib.Int64.logor
  let ( lsr ) = Stdlib.Int64.shift_right_logical
  let ( land ) = Stdlib.Int64.logand

  (** "ceiling power of 2" - Least power of 2 greater than or equal to x. *)
  let ceil_pow2 x =
    if x <= Stdlib.Int64.zero then non_positive_argument ();
    let x = Stdlib.Int64.pred x in
    let x = x lor (x lsr 1) in
    let x = x lor (x lsr 2) in
    let x = x lor (x lsr 4) in
    let x = x lor (x lsr 8) in
    let x = x lor (x lsr 16) in
    let x = x lor (x lsr 32) in
    Stdlib.Int64.succ x
  ;;

  (** "floor power of 2" - Largest power of 2 less than or equal to x. *)
  let floor_pow2 x =
    if x <= Stdlib.Int64.zero then non_positive_argument ();
    let x = x lor (x lsr 1) in
    let x = x lor (x lsr 2) in
    let x = x lor (x lsr 4) in
    let x = x lor (x lsr 8) in
    let x = x lor (x lsr 16) in
    let x = x lor (x lsr 32) in
    Stdlib.Int64.sub x (x lsr 1)
  ;;

  let is_pow2 x =
    if x <= Stdlib.Int64.zero then non_positive_argument ();
    x land Stdlib.Int64.pred x = Stdlib.Int64.zero
  ;;

  (* C stubs for int clz and ctz to use the CLZ/BSR/CTZ/BSF instruction where possible *)
  external clz
    :  (int64[@unboxed])
    -> (int[@untagged])
    = "Base_int_math_int64_clz" "Base_int_math_int64_clz_unboxed"
    [@@noalloc]

  external ctz
    :  (int64[@unboxed])
    -> (int[@untagged])
    = "Base_int_math_int64_ctz" "Base_int_math_int64_ctz_unboxed"
    [@@noalloc]

  (** Hacker's Delight Second Edition p106 *)
  let floor_log2 i =
    if i <= Stdlib.Int64.zero
    then
      raise_s
        (Sexp.message "[Int64.floor_log2] got invalid input" [ "", sexp_of_int64 i ]);
    num_bits - 1 - clz i
  ;;

  (** Hacker's Delight Second Edition p106 *)
  let ceil_log2 i =
    if Poly.( <= ) i Stdlib.Int64.zero
    then
      raise_s (Sexp.message "[Int64.ceil_log2] got invalid input" [ "", sexp_of_int64 i ]);
    if Stdlib.Int64.equal i Stdlib.Int64.one
    then 0
    else num_bits - clz (Stdlib.Int64.pred i)
  ;;
end

include Pow2
include Conv.Make (T)

include Conv.Make_hex (struct
  type t = int64 [@@deriving_inline compare ~localize, hash]

  let compare__local =
    (compare_int64__local : (t[@ocaml.local]) -> (t[@ocaml.local]) -> int)
  ;;

  let compare = (fun a b -> compare__local a b : t -> t -> int)

  let (hash_fold_t : Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state) =
    hash_fold_int64

  and (hash : t -> Ppx_hash_lib.Std.Hash.hash_value) =
    let func = hash_int64 in
    fun x -> func x
  ;;

  [@@@end]

  let zero = zero
  let neg = neg
  let ( < ) = ( < )
  let to_string i = Printf.sprintf "%Lx" i
  let of_string s = Stdlib.Scanf.sscanf s "%Lx" Fn.id
  let module_name = "Base.Int64.Hex"
end)

include Pretty_printer.Register (struct
  type nonrec t = t

  let to_string = to_string
  let module_name = "Base.Int64"
end)

module Pre_O = struct
  external ( + ) : (t[@local_opt]) -> (t[@local_opt]) -> (t[@local_opt]) = "%int64_add"
  external ( - ) : (t[@local_opt]) -> (t[@local_opt]) -> (t[@local_opt]) = "%int64_sub"
  external ( * ) : (t[@local_opt]) -> (t[@local_opt]) -> (t[@local_opt]) = "%int64_mul"
  external ( / ) : (t[@local_opt]) -> (t[@local_opt]) -> (t[@local_opt]) = "%int64_div"
  external ( ~- ) : (t[@local_opt]) -> (t[@local_opt]) = "%int64_neg"

  let ( ** ) = ( ** )

  include Int64_replace_polymorphic_compare

  let abs = abs

  external neg : (t[@local_opt]) -> (t[@local_opt]) = "%int64_neg"

  let zero = zero
  let of_int_exn = of_int_exn
end

module O = struct
  include Pre_O

  include Int_math.Make (struct
    type nonrec t = t

    include Pre_O

    let rem = rem
    let to_float = to_float
    let of_float = of_float
    let of_string = T.of_string
    let to_string = T.to_string
  end)

  external ( land ) : (t[@local_opt]) -> (t[@local_opt]) -> (t[@local_opt]) = "%int64_and"
  external ( lor ) : (t[@local_opt]) -> (t[@local_opt]) -> (t[@local_opt]) = "%int64_or"
  external ( lxor ) : (t[@local_opt]) -> (t[@local_opt]) -> (t[@local_opt]) = "%int64_xor"

  let lnot = bit_not

  external ( lsl )
    :  (t[@local_opt])
    -> (int[@local_opt])
    -> (t[@local_opt])
    = "%int64_lsl"

  external ( asr )
    :  (t[@local_opt])
    -> (int[@local_opt])
    -> (t[@local_opt])
    = "%int64_asr"

  external ( lsr )
    :  (t[@local_opt])
    -> (int[@local_opt])
    -> (t[@local_opt])
    = "%int64_lsr"
end

include O

(* [Int64] and [Int64.O] agree value-wise *)

(* Include type-specific [Replace_polymorphic_compare] at the end, after
   including functor application that could shadow its definitions. This is
   here so that efficient versions of the comparison functions are exported by
   this module. *)
include Int64_replace_polymorphic_compare
