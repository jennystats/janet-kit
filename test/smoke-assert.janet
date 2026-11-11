# smoke-assert.janet - janet-kit smoke for jennystats/assert.
# Every positive has a negative control: an assertion helper that cannot fail
# is an instrument that reports success.
# Testament integration lives in smoke-assert-testament.janet, run separately
# when testament is installed (Janet resolves imports at compile time, so it
# cannot be conditional in this file).

(import ../jennystats/assert :as a)
(import ../jennystats/typed :prefix "")

(var pass 0)
(var fail 0)

(defn/typed check {:args [:string :boolean] :ret :nil}
  [lbl ok]
  (if ok
    (do (set pass (+ pass 1)) (print (string "PASS " lbl)))
    (do (set fail (+ fail 1)) (print (string "FAIL " lbl))))
  nil)

# --- positives ---------------------------------------------------------

(check "raises sees an error"
       (a/assert-raises (fn [] (error "boom"))))

(check "raises-with matches a longer message"
       (a/assert-raises-with "ERR_BAD_KEY" (fn [] (error "ERR_BAD_KEY: dup"))))

(check "not-raises passes on a silent fn"
       (a/assert-not-raises (fn [] 42)))

(check "error-message returns the text"
       (= "boom" (a/error-message (fn [] (error "boom")))))

(check "error-message is empty when silent"
       (= "" (a/error-message (fn [] 42))))

# --- negative controls: these MUST come back false ---------------------

(check "raises returns false on a silent fn"
       (not (a/assert-raises (fn [] 42))))

(check "raises-with returns false on a different message"
       (not (a/assert-raises-with "ERR_BAD_KEY" (fn [] (error "ERR_OTHER")))))

(check "raises-with returns false when nothing raises"
       (not (a/assert-raises-with "ERR_BAD_KEY" (fn [] :ok))))

(check "not-raises returns false on a raiser"
       (not (a/assert-not-raises (fn [] (error "x")))))

(print (string "TOTAL " (+ pass fail) " PASS " pass " FAIL " fail))
(if (> fail 0) (os/exit 1))
