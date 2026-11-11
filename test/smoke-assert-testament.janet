# smoke-assert-testament.janet - proves jennystats/assert works inside
# testament, which is the module's reason to exist.
# Needs testament installed. Skipped by run_tests.sh when it is absent.
# The two cells are a positive and a negative control: a helper that reports
# success whether or not the error matches is an instrument that cannot fail.

(import ../jennystats/assert :as a)
(import testament :as t)

(t/deftest "assert-raises-with passes inside testament"
  (t/assert-expr (a/assert-raises-with "ERR_BAD_KEY"
                                       (fn [] (error "ERR_BAD_KEY: dup")))))

(t/deftest "assert-raises-with fails inside testament on a wrong class"
  (t/assert-expr (not (a/assert-raises-with "ERR_BAD_KEY"
                                            (fn [] (error "ERR_OTHER"))))))

(t/deftest "assert-raises-with fails when nothing raises"
  (t/assert-expr (not (a/assert-raises-with "ERR_BAD_KEY" (fn [] :ok)))))

(def reports (t/run-tests! :no-exit? true :silent? true))

(var pass 0)
(var fail 0)
(each r reports
  (set pass (+ pass (length (r :passes))))
  (set fail (+ fail (length (r :failures)))))

(print (string "TOTAL " (+ pass fail) " PASS " pass " FAIL " fail))
(if (or (> fail 0) (not= 3 pass)) (os/exit 1))
