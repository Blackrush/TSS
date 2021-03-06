exception Assoc_error of string ;;

let get key delta =
  try
    List.assoc key delta
  with Not_found ->
    raise (Assoc_error ("undefined variable `" ^ key ^ "'"))
;;

let put key value xs =
  let rec aux acc = function
    | [] -> (key, value) :: (List.rev acc)
    | (key', _) :: xs when String.equal key key' -> (key, value) :: (List.rev acc) @ xs
    | x :: xs -> aux (x :: acc) xs
  in

  aux [] xs
;;

let to_string f xs =
  "{" ^
    (String.concat ", " (
      List.map (fun (key, value) -> key ^ ": " ^ (f value))
               xs
    )) ^
  "}"
;;

let keys_to_string xs =
  "[" ^
    (String.concat ", " (
      List.map (fun (key, value) -> key)
               xs
    )) ^
  "]"
;;
