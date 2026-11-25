(import (rnrs) (rnrs eval) (chez-sodium))

;; The load runs when the program first needs libsodium. Reached through
;; eval, it runs inside this guard, so a refusal is caught.
(write
 (guard (e ((sodium-library-unavailable? e)
            (list 'refused
                  (sodium-library-unavailable-reason e)
                  (sodium-library-unavailable-path e))))
   (eval '(sodium-version) (environment '(chez-sodium)))))
(newline)
