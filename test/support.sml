(* support.sml -- shared helpers and canonical SemVer / node-semver vectors. *)

structure Support =
struct
  structure S = Semver

  fun parseExn s = S.parseExn s
  fun rangeExn s = S.parseRangeExn s

  fun orderToString LESS = "LESS"
    | orderToString EQUAL = "EQUAL"
    | orderToString GREATER = "GREATER"

  (* The SemVer 2.0.0 spec section 11 precedence example chain:
       1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta
       < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0           *)
  val precedenceChain =
    [ "1.0.0-alpha"
    , "1.0.0-alpha.1"
    , "1.0.0-alpha.beta"
    , "1.0.0-beta"
    , "1.0.0-beta.2"
    , "1.0.0-beta.11"
    , "1.0.0-rc.1"
    , "1.0.0" ]

  (* node-semver caret / tilde / x-range expansion examples:
       (range, satisfying versions, non-satisfying versions). *)
  val rangeTruth :
    (string * string list * string list) list =
    [ ("^1.2.3",  ["1.2.3", "1.2.4", "1.9.9"],        ["1.2.2", "2.0.0", "0.9.9"])
    , ("^0.2.3",  ["0.2.3", "0.2.9"],                 ["0.3.0", "0.2.2", "1.0.0"])
    , ("^0.0.3",  ["0.0.3"],                          ["0.0.4", "0.1.0"])
    , ("^1.2",    ["1.2.0", "1.5.0", "1.9.9"],        ["1.1.9", "2.0.0"])
    , ("^1",      ["1.0.0", "1.9.9"],                 ["0.9.9", "2.0.0"])
    , ("~1.2.3",  ["1.2.3", "1.2.9"],                 ["1.3.0", "1.2.2"])
    , ("~1.2",    ["1.2.0", "1.2.9"],                 ["1.3.0", "1.1.9"])
    , ("~1",      ["1.0.0", "1.9.9"],                 ["2.0.0", "0.9.9"])
    , ("1.x",     ["1.0.0", "1.9.9"],                 ["2.0.0", "0.9.9"])
    , ("1.2.x",   ["1.2.0", "1.2.9"],                 ["1.3.0", "1.1.9"])
    , ("*",       ["0.0.0", "1.2.3", "99.0.0"],       [])
    , (">=1.2.0 <2.0.0", ["1.2.0", "1.9.9"],          ["1.1.9", "2.0.0"])
    , ("1.2.3 - 2.3.4",  ["1.2.3", "2.0.0", "2.3.4"], ["1.2.2", "2.3.5"])
    , ("1.2.3 - 2.3",    ["1.2.3", "2.3.9"],          ["2.4.0"])
    , ("1.2 - 2",        ["1.2.0", "2.9.9"],          ["1.1.9", "3.0.0"])
    , ("1.2.3 || >=2.0.0", ["1.2.3", "2.0.0", "9.9.9"], ["1.2.4", "1.9.9"]) ]
end
