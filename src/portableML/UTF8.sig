signature UTF8 =
sig

  exception BadUTF8 of string
  val getChar : string -> ((string * int) * string) option
  val lastChar : string -> (string * int) option
  val size : string -> int
  val chr : int -> string (* May raise Chr *)
  val padRight : char -> int -> string -> string
  val substring : string * int * int -> string

  val translate : (string -> string) -> string -> string
end
