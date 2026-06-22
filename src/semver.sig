(* semver.sig

   Semantic Versioning 2.0.0 (https://semver.org) in pure Standard ML:
   version parsing, precedence comparison (spec section 11), and
   npm/node-semver-style range/constraint matching.

   Parsing is built on the vendored sml-parsec `CharParsec` combinators.

   A `version` is `major.minor.patch` with optional dot-separated
   `prerelease` and `build` identifier lists. Per the spec, build metadata
   is IGNORED when determining precedence; two versions that differ only in
   build metadata compare EQUAL. Numeric prerelease identifiers compare
   numerically, alphanumeric ones lexically (ASCII), numeric identifiers
   always rank below alphanumeric ones, and a version WITH a prerelease has
   LOWER precedence than the same version without one. *)

signature SEMVER =
sig
  (* A parsed SemVer version. `prerelease` and `build` are the dot-separated
     identifier lists ([] when absent), each identifier kept as a string. *)
  type version =
    { major : int, minor : int, patch : int
    , prerelease : string list, build : string list }

  (* Raised by `parseExn` / `parseRangeExn` on malformed input. *)
  exception Semver of string

  (* Parse a strict SemVer 2.0.0 string; NONE on malformed input. A leading
     "v" is tolerated. Numeric core identifiers reject leading zeros. *)
  val parse        : string -> version option
  val parseExn     : string -> version

  (* Canonical rendering; `toString o parseExn` round-trips a valid string
     (modulo a tolerated leading "v"). *)
  val toString     : version -> string

  (* Precedence per SemVer spec section 11. Build metadata is ignored. *)
  val compare      : version * version -> order

  val eq  : version * version -> bool
  val lt  : version * version -> bool
  val gt  : version * version -> bool
  val lte : version * version -> bool
  val gte : version * version -> bool

  (* A parsed range / constraint set (a disjunction of conjunctions of
     comparators), opaque to callers. *)
  type range

  (* Parse an npm/node-semver range string; NONE on malformed input.
     Supports: `^1.2.3`, `~1.2`, `>=1.0.0`, `>1`, `<2.0.0`, `<=1.2`,
     `=1.2.3`, `1.x` / `1.2.*` x-ranges, `*` (any), the empty string (any),
     hyphen ranges `1.2.3 - 2.3.4`, space-separated intersections, and
     `||` unions. *)
  val parseRange    : string -> range option
  val parseRangeExn : string -> range

  (* True iff `version` satisfies `range` under node-semver semantics
     (prerelease versions only satisfy a comparator set that itself pins a
     prerelease at the same major.minor.patch). *)
  val satisfies     : version * range -> bool

  (* The highest version (by `compare`) in the list that satisfies the
     range, or NONE if none do. *)
  val maxSatisfying : version list * range -> version option
end
