(* sml-semver demo: parse a few versions, order them by SemVer precedence,
   and check some npm/node-semver-style ranges. Output is printed and fully
   deterministic. *)

fun line s = print (s ^ "\n")

val () = line "sml-semver demo"
val () = line "==============="

(* ---- parse + toString round-trip ---- *)
val v = Semver.parseExn "1.2.3-beta.2+build.7"
val () = line ("parsed          : " ^ Semver.toString v)
val () = line ("  major/minor/patch = "
               ^ Int.toString (#major v) ^ "/"
               ^ Int.toString (#minor v) ^ "/"
               ^ Int.toString (#patch v))
val () = line ("  prerelease        = " ^ String.concatWith "." (#prerelease v))
val () = line ("  build             = " ^ String.concatWith "." (#build v))

(* ---- precedence: the SemVer spec section 11 example chain ---- *)
val chain =
  [ "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta"
  , "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0" ]
fun insert (x, []) = [x]
  | insert (x, y :: ys) =
      if Semver.lte (Semver.parseExn x, Semver.parseExn y)
      then x :: y :: ys
      else y :: insert (x, ys)
val sorted = List.foldr (fn (x, acc) => insert (x, acc)) [] chain
val () = line ""
val () = line "precedence (sorted ascending, spec 11):"
val () = line ("  " ^ String.concatWith " < " sorted)

(* ---- range matching ---- *)
fun demoRange (rng, versions) =
  ( line ("")
  ; line ("range " ^ rng ^ ":")
  ; List.app
      (fn vs =>
         line ("  " ^ vs ^ "  -> "
               ^ Bool.toString
                   (Semver.satisfies (Semver.parseExn vs, Semver.parseRangeExn rng))))
      versions )

val () = demoRange ("^1.2.3", ["1.2.3", "1.5.0", "2.0.0"])
val () = demoRange ("~1.2.3", ["1.2.3", "1.2.9", "1.3.0"])
val () = demoRange ("1.2.3 - 2.3.4", ["1.2.2", "2.0.0", "2.3.5"])
val () = demoRange (">=1.0.0 <2.0.0 || >=3.0.0", ["1.5.0", "2.5.0", "3.1.0"])

(* ---- maxSatisfying ---- *)
val pool = List.map Semver.parseExn ["1.2.0", "1.2.3", "1.9.9", "2.0.0", "0.9.0"]
val () = line ""
val () =
  line ("maxSatisfying ^1.2.3 over {1.2.0,1.2.3,1.9.9,2.0.0,0.9.0} = "
        ^ (case Semver.maxSatisfying (pool, Semver.parseRangeExn "^1.2.3") of
             SOME w => Semver.toString w
           | NONE => "NONE"))
