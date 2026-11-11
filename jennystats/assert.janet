# jennystats/assert.janet - error assertions for testament. License: AGPLv3 (see LICENSE).

# Testament's assert-thrown-message matches the error message EXACTLY, so a
# contract sentence saying "raises ERR_BAD_KEY" fails against a correct
# implementation that raises "ERR_BAD_KEY: duplicate". This module supplies
# the assertion testament does not have: a match on the error class, plus the
# other error shapes a prose contract needs.
#
# Every helper returns a boolean and raises nothing, so it works inside
# testament's assert-expr:
#   (t/assert-expr (a/assert-raises-with "ERR_X" (fn [] (save bad)))).
#
# Depends on ./typed (same package). The import is MODULE-RELATIVE for the
# same reason kit's is - see kit.janet's header note.
# Full description and testament behaviour notes: see the README, ## assert.

(import ./typed :prefix "")

(put (curenv) :doc
     "Error assertions for testament. assert-raises-with matches an error
class prefix, assert-raises asserts that a call raises, assert-not-raises
asserts that it does not, raises and error-message are the underlying
predicates. Each takes a FUNCTION and invokes it, where testament's
assert-thrown takes a form and would watch a closure rather than call it.
Returns booleans, raises nothing.")

(defn/typed raises {:args [:function] :ret :boolean} [f]
  "True when calling f raises. Invokes f."
  (def [_ err] (try (do (f) [true nil]) ([e] [false e])))
  (not (nil? err)))

(defn/typed error-message {:args [:function] :ret :string} [f]
  "Call f and return the raised message as a string, or the empty string
  when f did not raise."
  (def [_ err] (try (do (f) [true nil]) ([e] [false e])))
  (if err (string err) ""))

(defn/typed assert-raises {:args [:function] :ret :boolean} [f]
  "Assert that f raises. Invokes f, so a closure cannot be mistaken for
  the expression a form-taking assertion would watch."
  (raises f))

(defn/typed assert-raises-with {:args [:string :function] :ret :boolean}
  [prefix f]
  "Assert that f raises with a message beginning with prefix. A contract
  sentence names an error class; implementations append detail to it."
  (string/has-prefix? prefix (error-message f)))

(defn/typed assert-not-raises {:args [:function] :ret :boolean} [f]
  "Assert that f does not raise. Invokes f."
  (not (raises f)))
