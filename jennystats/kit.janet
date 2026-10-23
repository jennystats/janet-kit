# jennystats/kit.janet - correct-pattern helpers for Janet scripting. License: AGPLv3 (see LICENSE).
# Every helper encodes a real Janet gotcha - the full list is in the README.
# Depends on ./typed (same package).
# NOTE: typed is imported MODULE-RELATIVE (./typed), not by name: a script's
# `(setdyn *syspath* ...)` self-heal is invisible to nested module imports
# (each module loads in its own env), so a by-name import here breaks under
# the syspath fallback. Relative imports resolve against this file's
# directory, which always contains typed.janet. (Verified gotcha, 2026-09-30.)

(import ./typed :prefix "")

(put (curenv) :doc
     "Correct-pattern helpers for Janet scripting: shell execution (sh,
sh-capture, with quoting via sh-quote and sh-join), command-line
arguments (script-args), files and paths (slurp-string, realpath,
dirname, home-dir, path-exists), and numeric coercion (dbl). Every
helper encodes a real Janet gotcha - the README carries the full list.")

(defn/typed sh {:args [:string] :ret :number} [cmd]
  "Run a shell command through /bin/sh; returns the exit code.
  os/execute takes an argv tuple, does no PATH lookup and rejects
  bare strings - never a single command string."
  # os/execute takes an argv tuple with NO PATH lookup and rejects bare
  # strings - route every shell command through /bin/sh.
  (os/execute ["/bin/sh" "-c" cmd]))

(defn/typed sh-quote {:args [:string] :ret :string} [s]
  "Quote one string for a /bin/sh command line: double quotes,
  backslashes, $ and backtick are escaped ($ and backtick expand
  inside double quotes). NUL bytes error at the quoting boundary with
  the byte index - argv strings cannot carry NUL."
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
  "Rebuild a shell command from an argv tuple, each part quoted -
  space-joining unquoted parts re-splits paths that contain spaces."
  # Rebuild a shell command from an argv tuple, each part quoted.
  (string/join (map sh-quote parts) " "))

(defn- capture-file []
  # unique per call: a fixed /tmp path let concurrent scripts corrupt each
  # other's captures, and pre-created symlinks clobber arbitrary files
  (string "/tmp/kit-capture-" (gensym) "-" (os/clock)))

(defn/typed sh-capture {:args [:string] :ret :string} [cmd]
  "Run a shell command and return its trimmed stdout. os/spawn has no
  pipe slots, so output is captured via a unique noclobber temp file.
  A failing command captures \"\" (exit codes come from sh); stderr
  passes through to the Janet process."
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
  "File contents as a real string - slurp returns a buffer and `=` is
  type-strict, so buffer contents never compare equal to a string
  literal."
  # slurp returns a BUFFER and `=` is type-strict -
  # file contents as a real string for comparisons.
  (string (slurp path)))

(defn/typed script-args {:args [] :ret :tuple} []
  "The user-supplied command-line arguments only - (dyn *args*)
  carries the script path at index 0. Returns a tuple."
  # (dyn *args*) includes the script path at index 0 - only the
  # user-supplied arguments. (slice returns a tuple.)
  (slice (dyn *args*) 1))

(defn/typed home-dir {:args [] :ret :string} []
  "The HOME environment value, or a clear error when unset - never
  hardcode user paths."
  # HOME env with a clear error when unset - never hardcode user paths.
  (or (get (os/environ) "HOME") (error "HOME not set")))

(defn/typed realpath {:args [:string] :ret :string} [p]
  "Resolve a path through realpath(1); -m tolerates non-existent
  paths. Needed because *args* index 0 is the invoked path - a
  launcher symlink resolves to the real script."
  # Resolve symlinks via realpath(1) (GNU -m tolerates non-existent paths).
  # Needed because (dyn *args*) 0 is the INVOKED path: a launcher symlink
  # resolves to the real script - derive repo/tool locations from this.
  (sh-capture (string "realpath -m " (sh-quote p))))

(defn/typed dirname {:args [:string] :ret :string} [p]
  "Everything before the last \"/\" of a path: \".\" when there is
  none, \"/\" for a root child."
  # Everything before the last "/" ("." when none; "/" for a root child).
  (let [hits (string/find-all "/" p)]
    (cond
      (empty? hits) "."
      (zero? (last hits)) "/"
      (string/slice p 0 (last hits)))))

(defn/typed path-exists {:args [:string] :ret :boolean} [p]
  "True when the path exists. os/stat returns nil for missing paths
  instead of throwing - an existence check built on try alone is
  vacuously true for every path."
  # os/stat RETURNS NIL for missing paths (does not throw) - check the
  # result, or every existence test is vacuously true (caught 2026-10-01).
  (try (not (nil? (os/stat p))) ([_] false)))

(defn/typed dbl {:args [:any] :ret :number} [x]
  "Coerce a number, int/s64 or int/u64 box to a plain double.
  int/to-number does the unwrap - the boxes print like numbers but
  compare unequal ((= (int/s64 5) 5) is false). Errors on anything
  else."
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
