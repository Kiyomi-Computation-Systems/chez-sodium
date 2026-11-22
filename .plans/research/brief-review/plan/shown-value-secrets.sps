;; What chez-sqlite3's shown-value shows for a password given with the wrong
;; type: a symbol, a number (a PIN), a list of characters, a string, a bytevector.
(import (rnrs) (only (chez-sqlite3 private conditions) shown-value))
(for-each (lambda (x) (write (shown-value x)) (newline))
          (list 'hunter2 123456 (string->list "hunter2") "hunter2" (string->utf8 "hunter2")))
