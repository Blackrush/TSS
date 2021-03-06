type type_ = Boolean
           | Natural
           | Unit
           | Apply of type_ * type_
           | Name of string
           | Record of ((string * type_) list)
           | Variant of ((string * type_) list)
           ;;

let type_of_string = function
  | "Bool" -> Boolean
  | "bool" -> Boolean
  | "Nat" -> Natural
  | "Unit" -> Unit
  | n -> Name n
;;

let rec type_record_equal left right =
  List.for_all (fun (f1, ty1) ->
    List.exists (fun (f2, ty2) ->
      String.equal f1 f2 && type_equal ty1 ty2
    ) left
  ) right

and type_variant_equal left right =
  List.for_all (fun (f1, ty1) ->
    List.exists (fun (f2, ty2) ->
      String.equal f1 f2 && type_equal ty1 ty2
    ) left
  ) right

and type_equal a b =
  match a with
  | Record xs1 ->
    begin match b with
    | Record xs2 -> type_record_equal xs1 xs2
    | _ -> false
    end

  | Variant xs1 ->
    begin match b with
    | Variant xs2 -> type_variant_equal xs1 xs2
    | _ -> false
    end

  | Apply (aa, ab) ->
    begin match b with
    | Apply (ba, bb) -> (type_equal aa ba) && (type_equal ab bb)
    | _ -> false
    end

  | _ ->
    begin match b with
    | Apply _ -> false
    | Record _ -> false
    | Variant _ -> false
    | _ -> a == b
    end
;;

let rec string_of_type = function
  | Boolean -> "Bool"
  | Natural -> "Nat"
  | Unit -> "Unit"
  | Record xs -> Assoc.to_string ~kv:" : " string_of_type xs
  | Variant xs -> Assoc.to_string ~start:"<" ~stop:">" ~kv:" : " ~sep:" | " string_of_type xs
  | Apply (a, b) -> "(" ^ (string_of_type a) ^ " -> " ^ (string_of_type b) ^ ")"
  | Name n -> "^" ^ n
;;

type expression = Variable of string
                | Function of string * type_ * expression
                | NativeFunction of string * type_ * type_ * (((string * expression) list) -> expression -> (((string * expression) list) * expression))
                | DefineRecFunc of string * type_ * expression * expression
                | Application of expression * expression
                | Global of string * expression
                | Local of string * expression * expression
                | Boolean of bool
                | Natural of int
                | Unit
                | Cond of expression * expression * expression
                | Each of expression * expression
                | Record of ((string * expression) list)
                | Proj of expression * string
                | Variant of string * expression * type_
                | Case of expression * (variant list)

and variant = VariantCase of string * string * expression
            | VariantFallthrough of expression
;;

let rec expression_to_string = function
  | Variable var -> var
  | Function (var, ty, body) -> "λ" ^ var ^  " : " ^ (string_of_type ty) ^ ". " ^ (expression_to_string body)
  | NativeFunction (f, ty, rty, _) -> "λx : " ^ (string_of_type ty) ^ ". [native/" ^ f ^ " : " ^ (string_of_type rty) ^ "]"
  | DefineRecFunc (x, ty, t, rest) -> "letrec " ^ x ^ " : " ^ (string_of_type ty) ^ " = " ^ (expression_to_string t) ^ " in " ^ (expression_to_string rest)
  | Application (left, right) -> "(" ^ (expression_to_string left) ^ " " ^ (expression_to_string right) ^ ")"
  | Global (varname, varexpr) -> "let " ^ varname ^ " = " ^ (expression_to_string varexpr) ^ " ;; "
  | Local (varname, varexpr, body) -> "let " ^ varname ^ " = " ^ (expression_to_string varexpr) ^ " in\n" ^ (expression_to_string body)
  | Boolean b -> if b then "true" else "false"
  | Natural n -> string_of_int n
  | Unit -> "unit"
  | Cond (c, t, e) -> "if " ^ (expression_to_string c) ^ " then " ^ (expression_to_string t) ^ " else " ^ (expression_to_string e)
  | Each (a, b) -> (expression_to_string a) ^ " ; " ^ (expression_to_string b)
  | Record xs -> Assoc.to_string expression_to_string xs
  | Proj (self, f) -> (expression_to_string self) ^ "." ^ f
  | Variant (f, t, ty) -> "<" ^ f ^ " = " ^ (expression_to_string t) ^ "> as " ^ (string_of_type ty)

  | Case (t, cases) ->
    "case " ^ (expression_to_string t) ^ " of " ^
      (String.concat " | "
        (List.map
          (function VariantCase (f, x, t2) -> "<" ^ f ^ " = " ^ x ^ "> => " ^ (expression_to_string t2)
                  | VariantFallthrough t2 -> "_ => " ^ (expression_to_string t2))
          cases))
;;

let rec expression_is_value = function
  | Function _ -> true
  | NativeFunction _ -> true
  | Boolean _ -> true
  | Natural _ -> true
  | Unit -> true
  | Record xs -> List.for_all (fun (k, v) -> expression_is_value v) xs
  | Variant (_, t, _) -> expression_is_value t
  | _ -> false
;;

let expression_variable x v t =
  let rec aux = function
  | Variable x' when String.equal x x' -> v
  | (Function (x', ty, _)) as t1 when String.equal x x' -> t1
  | (Global (x', _)) as t1 when String.equal x x' -> t1
  | (Local (x', _, _)) as t1 when String.equal x x' -> t1

  | Function (x', ty, t) -> Function (x', ty, aux t)
  | Application (t1, t2) -> Application (aux t1, aux t2)
  | Global (x', t) -> Global (x', aux t)
  | Local (x', t1, t2) -> Local (x', aux t1, aux t2)
  | Cond (c, t, e) -> Cond (aux c, aux t, aux e)
  | Record xs -> Record (List.map (fun (k, v) -> (k, aux v)) xs)
  | Variant (f, t, ty) -> Variant (f, aux t, ty)
  | Case (t, cases) -> Case (aux t, List.map (function
                                              | VariantCase (f, x, t2) -> VariantCase (f, x, aux t2)
                                              | VariantFallthrough t2 -> VariantFallthrough (aux t2))
                                             cases)
  | Proj (self, f) -> Proj (aux self, f)
  | Each (t1, t2) -> Each (aux t1, aux t2)

  | t -> t
  in

  aux t
;;
