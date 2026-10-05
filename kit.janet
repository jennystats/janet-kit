# kit.janet - correct-pattern helpers for Janet scripting. License: AGPLv3 (see LICENSE).
# Every helper encodes a real Janet gotcha - the full list is in the README.
# Depends on ./typed (same package).
# NOTE: typed is imported MODULE-RELATIVE (./typed), not by name: a script's
# `(setdyn *syspath* ...)` self-heal is invisible to nested module imports
# (each module loads in its own env), so a by-name import here breaks under
# the syspath fallback. Relative imports resolve against this file's
# directory, which always contains typed.janet. (Verified gotcha, 2026-09-30.)

(import ./typed :prefix "")

(defn/typed sh {:args [:string] :ret :number} [cmd]
  # os/execute takes an argv tuple with NO PATH lookup and rejects bare
  # strings - route every shell command through /bin/sh.
  (os/execute ["/bin/sh" "-c" cmd]))

(defn/typed sh-quote {:args [:string] :ret :string} [s]
  # Quote one string for a /bin/sh command line. os/execute via sh has no
  # argv boundaries - arguments with spaces MUST be re-quoted when
  # reconstructing a command (verified: paths with spaces re-split).
  # $ and backtick are escaped because they expand inside double quotes -
  # a quoted "$(cmd)" used to EXECUTE. NUL cannot cross execve; reject it
  # here, at the quoting boundary, instead of at os/execute without
  # attribution.
  (when-let [i (string/find (string/from-bytes 0) s)]
    (errorf "sh-quote: NUL byte at index %d - argv strings cannot carry NUL" i))
  (string "\""
          (string/replace-all "`" "\\`"
          (string/replace-all "$" "\\$"
          (string/replace-all "\"" "\\\""
          (string/replace-all "\\" "\\\\" s))))
          "\""))

(defn/typed sh-join {:args [:tuple] :ret :string} [parts]
  # Rebuild a shell command from an argv tuple, each part quoted.
  (string/join (map sh-quote parts) " "))

(defn- capture-file []
  # unique per call: a fixed /tmp path let concurrent scripts corrupt each
  # other's captures, and pre-created symlinks clobber arbitrary files
  (string "/tmp/kit-capture-" (gensym) "-" (os/clock)))

(defn/typed sh-capture {:args [:string] :ret :string} [cmd]
  # os/spawn has no pipe slots on any flag - capture command output via
  # temp-file redirect, trimmed. `set -C` refuses a pre-existing entry
  # (symlink-clobber defense); `exec >` scopes the redirect to the WHOLE
  # command - an appended `>` would capture only the last statement and
  # leak the rest to the terminal. Failing commands capture "" (exit
  # codes come from sh); stderr passes through to the Janet process.
  (let [f (capture-file)]
    (def code
      (os/execute ["/bin/sh" "-c"
                   (string "set -C; exec > " (sh-quote f) "; " cmd)]))
    (def out
      (try (string (slurp f))
        ([_]
          (errorf "sh-capture: capture file %s missing after command (exit %d)"
                  f code))))
    # a failed rm must not mask a good capture - an orphan is inert
    (try (os/rm f) ([_] nil))
    (string/trim out)))

(defn/typed slurp-string {:args [:string] :ret :string} [path]
  # slurp returns a BUFFER and `=` is type-strict -
  # file contents as a real string for comparisons.
  (string (slurp path)))

(defn/typed script-args {:args [] :ret :tuple} []
  # (dyn *args*) includes the script path at index 0 - only the
  # user-supplied arguments. (slice returns a tuple.)
  (slice (dyn *args*) 1))

(defn/typed home-dir {:args [] :ret :string} []
  # HOME env with a clear error when unset - never hardcode user paths.
  (or (get (os/environ) "HOME") (error "HOME not set")))

(defn/typed realpath {:args [:string] :ret :string} [p]
  # Resolve symlinks via realpath(1) (GNU -m tolerates non-existent paths).
  # Needed because (dyn *args*) 0 is the INVOKED path: a launcher symlink
  # resolves to the real script - derive repo/tool locations from this.
  (sh-capture (string "realpath -m " (sh-quote p))))

(defn/typed dirname {:args [:string] :ret :string} [p]
  # Everything before the last "/" ("." when none; "/" for a root child).
  (let [hits (string/find-all "/" p)]
    (cond
      (empty? hits) "."
      (zero? (last hits)) "/"
      (string/slice p 0 (last hits)))))

(defn/typed path-exists {:args [:string] :ret :boolean} [p]
  # os/stat RETURNS NIL for missing paths (does not throw) - check the
  # result, or every existence test is vacuously true (caught 2026-10-01).
  (try (not (nil? (os/stat p))) ([_] false)))

(defn/typed dbl {:args [:any] :ret :number} [x]
  # Janet's core numbers are doubles, but int/s64 and int/u64 are their
  # own types: they print like plain numbers, compare unequal
  # ((= (int/s64 5) 5) is false) and survive (+ 0.0 x) unwrapped - the
  # addition runs in the wrapper's domain. int/to-number does unwrap.
  # Related float trap: "/" is division on doubles, so (* 330 (/ 7 5))
  # lands one ulp below 462 and PRINTS as "462" - (= v 462) fails while
  # the assert diff reads expect=462 actual=462. (+ 0.0 v) repairs
  # nothing there; near-integer counts need (math/round v).
  (cond
    (number? x) x
    (or (= :core/s64 (type x)) (= :core/u64 (type x))) (int/to-number x)
    (errorf "dbl: expected number, s64 or u64, got %v" (type x))))
