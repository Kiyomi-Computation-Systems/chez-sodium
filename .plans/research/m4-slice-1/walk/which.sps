(import (rnrs) (rnrs eval) (chez-sodium))

(write
 (guard (e ((sodium-library-unavailable? e)
            (list 'refused
                  (sodium-library-unavailable-reason e)
                  (sodium-library-unavailable-path e))))
   (eval '(sodium-version) (environment '(chez-sodium)))))
(newline)
