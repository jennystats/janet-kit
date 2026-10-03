(import ../kit :prefix "")

(def FIXTURE "/tmp/janet-kit-smoke.txt")
(def LINK "/tmp/janet-kit-smoke-link")

# sh - returns the command's exit code
(assert (= (sh "exit 0") 0) "sh exit code")
(assert (= (sh "exit 3") 3) "sh propagates a non-zero exit code")

# sh-capture - stdout via temp file, trimmed
(assert (= (sh-capture "printf hi") "hi") "sh-capture")
(assert (= (sh-capture "printf 'hi\\n\\n'") "hi") "sh-capture trims trailing whitespace")

# sh-quote - exact quoted output. Double quotes neutralise spaces, quotes,
# ; and |; $ and backticks still expand inside them (documented
# limitation - do not pass hostile strings).
(assert (= (sh-quote "a b c") "\"a b c\"") "sh-quote wraps spaces")
(assert (= (sh-quote "") "\"\"") "sh-quote wraps the empty string")
(assert (= (sh-quote "say \"hi\"") "\"say \\\"hi\\\"\"") "sh-quote escapes embedded quotes")
(assert (= (sh-quote "a\\b") "\"a\\\\b\"") "sh-quote doubles backslashes")
(assert (= (sh-quote "a\\\"b") "\"a\\\\\\\"b\"")
        "sh-quote escapes backslashes before quotes")
(assert (= (sh-quote "x; rm | y && z $W") "\"x; rm | y && z $W\"")
        "sh-quote leaves metacharacters inside the quotes")
(assert (= (sh-capture (string "W=expanded; printf %s " (sh-quote "pre $W post")))
           "pre expanded post")
        "sh-quote does not neutralise $ (documented limitation)")

# sh-join - rebuild an argv-shaped command with every part quoted
(assert (= (sh-join ["printf" "%s" "a b c"]) "\"printf\" \"%s\" \"a b c\"")
        "sh-join quotes every part")
(assert (= (sh-join []) "") "sh-join of an empty argv is the empty command")

# argv boundaries survive a trip through /bin/sh
(assert (= (sh-capture (string "printf %s " (sh-quote "two words; \"q\" \\ | && rm")))
           "two words; \"q\" \\ | && rm")
        "a quoted argument crosses the shell as one argv entry")
(assert (= (sh-capture (sh-join ["printf" "%s|%s" "a b" ""])) "a b|")
        "an empty string survives as its own argv entry")

# slurp-string - file contents as a real string
(spit FIXTURE "body")
(assert (= (slurp-string FIXTURE) "body") "slurp-string")

# script-args - user arguments without the script path
(assert (deep= (script-args) ["x" "y"]) "script-args")

# home-dir - HOME from the environment, never hardcoded
(assert (not (empty? (home-dir))) "home-dir is non-empty")
(assert (= (home-dir) (get (os/environ) "HOME")) "home-dir matches the environment")

# realpath - symlink resolution via realpath -m
(assert (string/has-suffix? "janet-kit-smoke.txt" (realpath FIXTURE))
        "realpath keeps the leaf name")
(assert (zero? (sh (string "ln -sf " (sh-quote FIXTURE) " " (sh-quote LINK))))
        "symlink fixture")
(assert (= (realpath LINK) (realpath FIXTURE)) "realpath resolves a symlink")
(sh (string "rm -f " (sh-quote LINK)))

# dirname - everything before the last slash
(assert (= (dirname "/a/b/c.txt") "/a/b") "dirname of a path")
(assert (= (dirname "foo.txt") ".") "dirname of a bare name")
(assert (= (dirname "/file") "/") "dirname of a root child")
(assert (= (dirname "a/b") "a") "dirname of a relative path")
(assert (= (dirname "") ".") "dirname of the empty string")

# path-exists - os/stat returns nil for missing paths instead of throwing
(assert (true? (path-exists FIXTURE)) "path-exists is true for an existing file")
(assert (false? (path-exists "/tmp/janet-kit-smoke-missing-404.txt"))
        "path-exists is false for a missing path")
(os/rm FIXTURE)
(assert (false? (path-exists FIXTURE)) "path-exists reflects deletion")

# dbl - unwraps s64/u64 wrappers to plain doubles. Regression: the old
# docstring claimed Janet "rationals" and coercion via (+ 0.0 x) - Janet
# has no rationals, core numbers are doubles, and (+ 0.0 x) is inert.
(assert (= (dbl (int/s64 5)) 5) "dbl unwraps s64 to a plain double")
(assert (= (type (dbl (int/s64 5))) :number) "dbl returns a core number")
(assert (= (dbl (int/u64 7)) 7) "dbl unwraps u64")
(assert (= (dbl 1) 1.0) "dbl passes doubles through")
# the float trap that created this helper: "/" is division on doubles, so
# (* 330 (/ 7 5)) prints "462" while (= v 462) is false
(assert (not= (* 330 (/ 7 5)) 462)
        "a float product can print 462 and still not be 462")
(assert (= (math/round (* 330 (/ 7 5))) 462)
        "math/round repairs near-integer counts")
(var dbl-err nil)
(try (dbl "x") ([e] (set dbl-err e)))
(assert (not (nil? (string/find "dbl: expected" dbl-err)))
        "dbl rejects non-numbers with a clear error")

(print "kit smoke ok")
