(* semver.sml

   Semantic Versioning 2.0.0 parsing/precedence + npm/node-semver range
   matching, built on the vendored sml-parsec `CharParsec` combinators.

   Pure and deterministic: no FFI, threads, clock or randomness. Identical
   behaviour under MLton and Poly/ML. *)

structure Semver :> SEMVER =
struct
  type version =
    { major : int, minor : int, patch : int
    , prerelease : string list, build : string list }

  exception Semver of string

  (* Parse an all-digit string as a non-negative `int`, bounded to the portable
     signed 32-bit range (2^31 - 1) so the result fits `int` and is identical on
     MLton and Poly/ML, whose default `int` types are fixed-width (32-bit and
     63-bit here). Goes through `IntInf` and returns NONE when the value exceeds
     that range, rather than raising `Overflow` under MLton on an oversized
     version number. *)
  local val maxNat : IntInf.int = 2147483647 (* 2^31 - 1 *) in
    fun natFromDigits s =
      case IntInf.fromString s of
          SOME n => if n >= 0 andalso n <= maxNat then SOME (IntInf.toInt n) else NONE
        | NONE   => NONE
  end

  (* ---- version parsing (CharParsec grammar) --------------------------- *)

  local
    open CharParsec
    infix 1 >>= >>
    infix 4 <$>
    infixr 1 <|>

    fun implode' cs = String.implode cs

    fun isIdentChar c = Char.isAlphaNum c orelse c = #"-"
    fun allDigits s =
      s <> "" andalso List.all Char.isDigit (String.explode s)

    (* a run of digits, returned as a string *)
    val digitsP = implode' <$> many1 digit

    (* a numeric core identifier (major/minor/patch): digits with no leading
       zero unless the value is exactly "0". *)
    val numericCore =
      digitsP >>= (fn s =>
        if String.size s > 1 andalso String.sub (s, 0) = #"0"
        then fail "numeric identifier must not have a leading zero"
        else case natFromDigits s of
               SOME n => return n
             | NONE => fail "numeric identifier out of range")

    (* a single dot-separated prerelease identifier: alphanumerics and
       hyphens; a purely numeric one must not carry a leading zero. *)
    val preIdent =
      (implode' <$> many1 (sat isIdentChar)) >>= (fn s =>
        if allDigits s andalso String.size s > 1 andalso String.sub (s, 0) = #"0"
        then fail "numeric prerelease identifier must not have a leading zero"
        else return s)

    (* a build identifier: alphanumerics and hyphens, leading zeros allowed. *)
    val buildIdent = implode' <$> many1 (sat isIdentChar)

    val preList   = char #"-" >> sepBy1 preIdent (char #".")
    val buildList = char #"+" >> sepBy1 buildIdent (char #".")

    val versionP =
      (* optional leading "v" *)
      (optional (char #"v" <|> char #"V")) >>
      numericCore >>= (fn maj =>
      char #"." >> numericCore >>= (fn min =>
      char #"." >> numericCore >>= (fn pat =>
      option [] preList >>= (fn pre =>
      option [] buildList >>= (fn bld =>
      return { major = maj, minor = min, patch = pat
             , prerelease = pre, build = bld })))))

    (* require all input consumed *)
    val fullP = versionP >>= (fn v => eof >> return v)
  in
    fun parse s =
      case runParser fullP s of
        Ok v => SOME v
      | Err _ => NONE
  end

  fun parseExn s =
    case parse s of
      SOME v => v
    | NONE => raise Semver ("invalid version: " ^ s)

  fun toString {major, minor, patch, prerelease, build} =
    Int.toString major ^ "." ^ Int.toString minor ^ "." ^ Int.toString patch
    ^ (if null prerelease then ""
       else "-" ^ String.concatWith "." prerelease)
    ^ (if null build then ""
       else "+" ^ String.concatWith "." build)

  (* ---- precedence (SemVer spec section 11) ---------------------------- *)

  fun allDigits s =
    s <> "" andalso List.all Char.isDigit (String.explode s)

  (* numeric identifiers compare numerically (use LargeInt to be safe for
     arbitrarily long numeric identifiers); numeric < alphanumeric; otherwise
     ASCII lexical order. *)
  fun compareIdent (x, y) =
    case (allDigits x, allDigits y) of
      (true, true) =>
        (* `LargeInt` is arbitrary precision, so this never overflows; the `_`
           arm is unreachable given `allDigits`, but is handled totally so no
           unchecked `valOf` sits here. *)
        (case (LargeInt.fromString x, LargeInt.fromString y) of
             (SOME a, SOME b) => LargeInt.compare (a, b)
           | _ => String.compare (x, y))
    | (true, false) => LESS
    | (false, true) => GREATER
    | (false, false) => String.compare (x, y)

  (* element-wise; when one list is a proper prefix of the other, the longer
     (larger set of fields) has higher precedence. *)
  fun compareIdList ([], []) = EQUAL
    | compareIdList ([], _ :: _) = LESS
    | compareIdList (_ :: _, []) = GREATER
    | compareIdList (x :: xs, y :: ys) =
        (case compareIdent (x, y) of
           EQUAL => compareIdList (xs, ys)
         | ord => ord)

  (* a version WITHOUT a prerelease outranks the same version WITH one. *)
  fun comparePrerelease ([], []) = EQUAL
    | comparePrerelease ([], _ :: _) = GREATER
    | comparePrerelease (_ :: _, []) = LESS
    | comparePrerelease (a, b) = compareIdList (a, b)

  fun compare (a : version, b : version) =
    case Int.compare (#major a, #major b) of
      EQUAL =>
        (case Int.compare (#minor a, #minor b) of
           EQUAL =>
             (case Int.compare (#patch a, #patch b) of
                EQUAL => comparePrerelease (#prerelease a, #prerelease b)
              | ord => ord)
         | ord => ord)
    | ord => ord

  fun eq  p = compare p = EQUAL
  fun lt  p = compare p = LESS
  fun gt  p = compare p = GREATER
  fun lte p = compare p <> GREATER
  fun gte p = compare p <> LESS

  (* ---- ranges --------------------------------------------------------- *)

  datatype cop = LT | LTE | GT | GTE | EQ
  type comparator = cop * version
  (* a range is a disjunction (||) of conjunctions (space-separated) of
     comparators. *)
  type range = comparator list list

  (* a possibly-partial version with x-range wildcards *)
  datatype part = Wild | Num of int
  type partial =
    { major : part, minor : part, patch : part
    , pre : string list, build : string list }

  fun mkVer (mj, mn, pt, pre) =
    { major = mj, minor = mn, patch = pt, prerelease = pre, build = [] }

  fun partNum Wild = 0
    | partNum (Num n) = n

  (* split a string on the first occurrence of a character *)
  fun splitFirst c s =
    case CharVector.findi (fn (_, x) => x = c) s of
      SOME (i, _) =>
        SOME (String.substring (s, 0, i),
              String.extract (s, i + 1, NONE))
    | NONE => NONE

  (* parse a (possibly partial, possibly wildcard) version descriptor *)
  fun parsePartial raw0 =
    let
      val raw =
        if raw0 <> "" andalso (String.sub (raw0, 0) = #"v"
                               orelse String.sub (raw0, 0) = #"V")
        then String.extract (raw0, 1, NONE)
        else raw0
      val () = if raw = "" then raise Semver "empty version descriptor" else ()
      (* strip build metadata first, then prerelease *)
      val (beforeBuild, build) =
        case splitFirst #"+" raw of
          SOME (a, b) => (a, String.fields (fn c => c = #".") b)
        | NONE => (raw, [])
      val (core, pre) =
        case splitFirst #"-" beforeBuild of
          SOME (a, b) =>
            if b = "" then raise Semver "empty prerelease"
            else (a, String.fields (fn c => c = #".") b)
        | NONE => (beforeBuild, [])
      val fields = String.fields (fn c => c = #".") core
      fun toPart "" = Wild
        | toPart s =
            if s = "x" orelse s = "X" orelse s = "*" then Wild
            else if List.all Char.isDigit (String.explode s) then
              (case natFromDigits s of
                 SOME n => Num n
               | NONE => raise Semver ("number out of range: " ^ s))
            else raise Semver ("bad version field: " ^ s)
      val (mj, mn, pt) =
        case fields of
          [a] => (toPart a, Wild, Wild)
        | [a, b] => (toPart a, toPart b, Wild)
        | [a, b, c] => (toPart a, toPart b, toPart c)
        | _ => raise Semver ("bad version descriptor: " ^ raw0)
    in
      { major = mj, minor = mn, patch = pt, pre = pre, build = build }
    end

  (* bare / `=` descriptor: exact when fully specified, else an x-range. *)
  fun expandEq (p : partial) =
    case #major p of
      Wild => [(GTE, mkVer (0, 0, 0, []))]
    | Num mj =>
        (case #minor p of
           Wild => [(GTE, mkVer (mj, 0, 0, [])),
                    (LT,  mkVer (mj + 1, 0, 0, []))]
         | Num mn =>
             (case #patch p of
                Wild => [(GTE, mkVer (mj, mn, 0, [])),
                         (LT,  mkVer (mj, mn + 1, 0, []))]
              | Num pt => [(EQ, mkVer (mj, mn, pt, #pre p))]))

  fun expandPrimitive (cop, p : partial) =
    case cop of
      EQ => expandEq p
    | _ =>
        (case #major p of
           Wild => [(GTE, mkVer (0, 0, 0, []))]
         | Num mj =>
             let
               val minorWild = (#minor p = Wild)
               val patchWild = (#patch p = Wild)
               val mn = partNum (#minor p)
               val pt = partNum (#patch p)
             in
               case cop of
                 GT =>
                   if minorWild then [(GTE, mkVer (mj + 1, 0, 0, []))]
                   else if patchWild then [(GTE, mkVer (mj, mn + 1, 0, []))]
                   else [(GT, mkVer (mj, mn, pt, #pre p))]
               | GTE =>
                   if minorWild then [(GTE, mkVer (mj, 0, 0, []))]
                   else if patchWild then [(GTE, mkVer (mj, mn, 0, []))]
                   else [(GTE, mkVer (mj, mn, pt, #pre p))]
               | LT =>
                   if minorWild then [(LT, mkVer (mj, 0, 0, []))]
                   else if patchWild then [(LT, mkVer (mj, mn, 0, []))]
                   else [(LT, mkVer (mj, mn, pt, #pre p))]
               | LTE =>
                   if minorWild then [(LT, mkVer (mj + 1, 0, 0, []))]
                   else if patchWild then [(LT, mkVer (mj, mn + 1, 0, []))]
                   else [(LTE, mkVer (mj, mn, pt, #pre p))]
               | EQ => expandEq p (* unreachable *)
             end)

  (* caret: allow changes that do not modify the left-most non-zero element. *)
  fun expandCaret (p : partial) =
    case #major p of
      Wild => [(GTE, mkVer (0, 0, 0, []))]
    | Num mj =>
        let
          val minorWild = (#minor p = Wild)
          val patchWild = (#patch p = Wild)
          val mn = partNum (#minor p)
          val pt = partNum (#patch p)
          val lower = mkVer (mj, mn, pt, #pre p)
          val upper =
            if mj > 0 then mkVer (mj + 1, 0, 0, [])
            else (* major = 0 *)
              if minorWild then mkVer (1, 0, 0, [])
              else if mn > 0 then mkVer (0, mn + 1, 0, [])
              else (* minor = 0 *)
                if patchWild then mkVer (0, 1, 0, [])
                else mkVer (0, 0, pt + 1, [])
        in
          [(GTE, lower), (LT, upper)]
        end

  (* tilde: allow patch-level changes if a minor is specified; minor-level
     changes otherwise. *)
  fun expandTilde (p : partial) =
    case #major p of
      Wild => [(GTE, mkVer (0, 0, 0, []))]
    | Num mj =>
        let
          val minorWild = (#minor p = Wild)
          val mn = partNum (#minor p)
          val pt = partNum (#patch p)
          val lower = mkVer (mj, mn, pt, #pre p)
          val upper =
            if minorWild then mkVer (mj + 1, 0, 0, [])
            else mkVer (mj, mn + 1, 0, [])
        in
          [(GTE, lower), (LT, upper)]
        end

  fun expandHyphenLower (p : partial) =
    case #major p of
      Wild => (GTE, mkVer (0, 0, 0, []))
    | Num mj =>
        if #minor p = Wild then (GTE, mkVer (mj, 0, 0, []))
        else if #patch p = Wild then (GTE, mkVer (mj, partNum (#minor p), 0, []))
        else (GTE, mkVer (mj, partNum (#minor p), partNum (#patch p), #pre p))

  fun expandHyphenUpper (p : partial) =
    case #major p of
      Wild => (LT, mkVer (1000000000, 0, 0, [])) (* practically unbounded *)
    | Num mj =>
        if #minor p = Wild then (LT, mkVer (mj + 1, 0, 0, []))
        else if #patch p = Wild then (LT, mkVer (mj, partNum (#minor p) + 1, 0, []))
        else (LTE, mkVer (mj, partNum (#minor p), partNum (#patch p), #pre p))

  (* parse one whitespace-delimited simple range token into comparators *)
  fun parseSimple tok =
    if tok = "" then [(GTE, mkVer (0, 0, 0, []))]
    else if tok = "*" orelse tok = "x" orelse tok = "X" then
      [(GTE, mkVer (0, 0, 0, []))]
    else
      let val c0 = String.sub (tok, 0) in
        if c0 = #"^" then expandCaret (parsePartial (String.extract (tok, 1, NONE)))
        else if c0 = #"~" then
          (* tolerate the `~>` spelling *)
          let val rest =
                if String.size tok >= 2 andalso String.sub (tok, 1) = #">"
                then String.extract (tok, 2, NONE)
                else String.extract (tok, 1, NONE)
          in expandTilde (parsePartial rest) end
        else if c0 = #">" then
          if String.size tok >= 2 andalso String.sub (tok, 1) = #"=" then
            expandPrimitive (GTE, parsePartial (String.extract (tok, 2, NONE)))
          else expandPrimitive (GT, parsePartial (String.extract (tok, 1, NONE)))
        else if c0 = #"<" then
          if String.size tok >= 2 andalso String.sub (tok, 1) = #"=" then
            expandPrimitive (LTE, parsePartial (String.extract (tok, 2, NONE)))
          else expandPrimitive (LT, parsePartial (String.extract (tok, 1, NONE)))
        else if c0 = #"=" then
          expandPrimitive (EQ, parsePartial (String.extract (tok, 1, NONE)))
        else expandPrimitive (EQ, parsePartial tok)
      end

  fun isSpace c = c = #" " orelse c = #"\t"

  (* parse a single conjunction clause (already split out of a `||` union) *)
  fun parseClause section =
    let val toks = String.tokens isSpace section in
      case toks of
        [a, "-", b] =>
          [expandHyphenLower (parsePartial a),
           expandHyphenUpper (parsePartial b)]
      | [] => [(GTE, mkVer (0, 0, 0, []))]
      | _ =>
          if List.exists (fn t => t = "-") toks then
            raise Semver "malformed hyphen range"
          else List.concat (List.map parseSimple toks)
    end

  (* split a string on the substring "||" *)
  fun splitUnions s =
    let
      val n = String.size s
      fun go (i, start, acc) =
        if i + 1 >= n then
          List.rev (String.substring (s, start, n - start) :: acc)
        else if String.sub (s, i) = #"|" andalso String.sub (s, i + 1) = #"|"
        then go (i + 2, i + 2,
                 String.substring (s, start, i - start) :: acc)
        else go (i + 1, start, acc)
    in
      if n = 0 then [""] else go (0, 0, [])
    end

  fun parseRange str =
    (SOME (List.map parseClause (splitUnions str)))
    handle Semver _ => NONE

  fun parseRangeExn str =
    case parseRange str of
      SOME r => r
    | NONE => raise Semver ("invalid range: " ^ str)

  (* ---- satisfaction --------------------------------------------------- *)

  fun sameTuple (a : version, b : version) =
    #major a = #major b andalso #minor a = #minor b andalso #patch a = #patch b

  fun satComparator (v, (cop, cv)) =
    case cop of
      LT  => compare (v, cv) = LESS
    | LTE => compare (v, cv) <> GREATER
    | GT  => compare (v, cv) = GREATER
    | GTE => compare (v, cv) <> LESS
    | EQ  => compare (v, cv) = EQUAL

  (* node-semver default (includePrerelease = false): a prerelease version
     only satisfies a comparator set if that set pins a prerelease at the
     same major.minor.patch. *)
  fun satClause (v : version, comps) =
    List.all (fn c => satComparator (v, c)) comps
    andalso
    (null (#prerelease v)
     orelse
     List.exists
       (fn (_, cv) =>
          not (null (#prerelease cv)) andalso sameTuple (v, cv))
       comps)

  fun satisfies (v, r : range) =
    List.exists (fn clause => satClause (v, clause)) r

  fun maxSatisfying (vs, r) =
    List.foldl
      (fn (v, acc) =>
         if satisfies (v, r) then
           case acc of
             NONE => SOME v
           | SOME best => if compare (v, best) = GREATER then SOME v else acc
         else acc)
      NONE vs
end
