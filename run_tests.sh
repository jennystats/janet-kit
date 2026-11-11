#!/bin/sh
# run_tests.sh - janet-kit smoke suite (typed + kit + assert); runs from the
# repo root.
# The testament integration smoke runs only when testament is installed, since
# it is an optional dependency of the assert module.
set -e

janet test/smoke-typed.janet
janet test/smoke-kit.janet x y
janet test/smoke-assert.janet

if janet -e '(import testament)' >/dev/null 2>&1; then
  janet test/smoke-assert-testament.janet
else
  echo "SKIP testament integration smoke (testament not installed)"
fi

echo "RESULT: pass"
