open Format
open Lexing

let usage = "usage: ./minimlc file.ml"

let spec = []
  
let file =
    let file = ref None in
    let set_file s =
      if not (Filename.check_suffix s ".ml") then
        raise (Arg.Bad "no .ml extension");
      file := Some s
    in
    Arg.parse spec set_file usage;
    match !file with Some f -> f | None -> Arg.usage spec usage; exit 1

let report (b,e) =
  let l = b.pos_lnum in
  let fc = b.pos_cnum - b.pos_bol + 1 in
  let lc = e.pos_cnum - b.pos_bol + 1 in
  eprintf "File \"%s\", line %d, characters %d-%d:\n" file l fc lc


let () =
  let c  = open_in file in
  let lb = Lexing.from_channel c in
  try
    let prog = Parser.program Lexer.token lb
    in
    close_in c;
    let progclj = Mini2clj.translate_program prog in
    let progimp = Clj2imp.translate_program progclj in
    let output_file = (Filename.chop_suffix file ".ml") ^ ".imp" in
    let out = open_out output_file in
    Imppp.pp_program progimp out;
    close_out out;
    exit 0
  with
  | Parser.Error ->
     report (lexeme_start_p lb, lexeme_end_p lb);
     eprintf "syntax error@.";
     exit 1
  | e ->
     eprintf "Anomaly: %s\n@." (Printexc.to_string e);
     exit 2
