#!r6rs
;;; make check-floors: reads the floors file, the README, and every file under
;;; the workflow directory, the CI scripts directory and each document named
;;; on the command line (make passes packaging/floors.sexp, README.org,
;;; .github/workflows, scripts/ci, then docs and the house files, a directory
;;; or a file each), and fails, naming each problem,
;;; unless README.org's Requirements section states the floors in
;;; packaging/floors.sexp (the lines (floors)'s requirement-lines writes from
;;; the file, whole, as one list) and no other line of README.org states
;;; either; no line of any file in the workflow directory contains either
;;; floor's version text, holds a backslash after a double quote, or holds an
;;; odd number of double quotes, a double-quoted string left open at the line's
;;; end: CI states no floor, and scripts/ci/floor.sh reads them from the file;
;;; and no line of any file in the scripts directory, of any document given as
;;; a file or under one given as a directory, contains either floor's version text: a page names the floors by a link to
;;; README.org's Requirements. The two rules about double quotes are YAML's,
;;; and a script is shell, a page prose, so they do not apply there. The rules
;;; are in (floors); this program reads the files, prints, and exits.
;;; tests/test-check-floors.sps holds each rule on texts and runs this program
;;; on fixture directories.
;;;
;;; The workflow, scripts and docs directories are each read whole: every
;;; file in it and in its subdirectories, whatever its name, in the order of
;;; their paths. The directory must be a directory, not a symbolic link to one;
;;; a symbolic link to a directory inside it is not followed: it is read as a
;;; file, which fails. A document argument that is no directory is read as one
;;; file, whose own path is its name; one that does not exist is a file that
;;; cannot be read.
;;;
;;; It fails closed, because a check that passes on nothing is vacuous. It
;;; names, and exits 1 on, a file or directory it cannot read, a floors file
;;; with a problem, a README with no "** Requirements" section or the wrong list
;;; in it, a workflow directory that holds no file or no ci.yml, a scripts
;;; directory that holds no file or no floor.sh, a docs directory that holds no
;;; file, and a floor written anywhere in them, or in README.org outside its
;;; Requirements' list lines, or, in a workflow only, a backslash after a
;;; double quote or an odd number of double quotes. A file it cannot read does
;;; not stop it comparing the others.
;;;
;;; It prints one line on a pass, to stdout, naming the files it read under the
;;; workflow directory, then those under the scripts directory, then those
;;; under each document directory, each document file by its path, and the
;;; floors it found, or each problem and then
;;; a count of them on a failure, to stderr. It exits 0 or 1, never a count.
(import (rnrs)
        (floors)
        (only (chezscheme) directory-list display-condition file-directory?
                file-symbolic-link?))

;; describe : Any -> String
(define (describe obj)
  (call-with-string-output-port
    (lambda (p) (if (condition? obj) (display-condition obj p) (write obj p)))))

;; say : Port String -> Unit
(define (say port text)
  (put-string port (string-append "check-floors: " text "\n")))

;; read-text : String -> (U (List 'text String) (List 'unreadable String))
;; The text of the file at PATH, or the problem with reading it.
(define (read-text path)
  (guard (e (#t (list 'unreadable
                      (string-append path ": it cannot be read: " (describe e)))))
    (list 'text (file-text path))))

(define (text-or-false read)
  (and (eq? (car read) 'text) (cadr read)))

;; walk : String -> (Listof String)
;; Every file under DIR, as a path, in subdirectories too, in no set order.
;; A subdirectory is entered only when it is a directory itself, not a
;; symbolic link to one, which is a file here. It raises when a directory
;; cannot be listed.
(define (walk dir)
  (apply append
         (map (lambda (name)
                (let ((path (string-append dir "/" name)))
                  (if (file-directory? path #f) (walk path) (list path))))
              (directory-list dir))))

;; read-directory : String
;;   -> (U (List 'files (Listof (List String (U (List 'text String) (List 'unreadable String)))))
;;         (List 'unreadable String))
;; Every file under the directory DIR, the workflows, the scripts or the
;; docs, in the order of its path, with its text or the problem with reading
;; it, or the problem with listing the directory. DIR itself must not be a
;; symbolic link.
(define (read-directory wdir)
  (guard (e (#t (list 'unreadable (string-append wdir ": it cannot be read: " (describe e)))))
    (when (file-symbolic-link? wdir)
      (error #f "it is a symbolic link, not a directory"))
    (list 'files
          (map (lambda (path) (list path (read-text path)))
               (list-sort string<? (walk wdir))))))

;; texts : (U (Listof (List String (U (List 'text String) (List 'unreadable String)))) #f)
;;   -> (U (Listof (List String (U String #f))) #f)
;; The files of a directory read as the pure checks take them: each path and
;; its text, or #f for a file that could not be read; #f for a directory that
;; could not be listed.
(define (texts files)
  (and files
       (map (lambda (file) (list (car file) (text-or-false (cadr file)))) files)))

;; unreadable : Directory -> (Listof String)
;; The problems of reading a directory W (what read-directory answers): the
;; directory's own when it could not be listed, else each file's that could not
;; be read, in path order.
(define (unreadable w)
  (if (eq? (car w) 'files)
      (apply append
             (map (lambda (file)
                    (if (eq? (car (cadr file)) 'text) '() (list (cadr (cadr file)))))
                  (cadr w)))
      (list (cadr w))))

;; read-document : String -> (U (List 'directory Directory) (List 'file Directory))
;; The document at PATH: a directory read whole (read-directory), else one
;; file, as a directory of that file alone, named by PATH itself. A symbolic
;; link to a directory is a directory here, so read-directory refuses it.
(define (read-document path)
  (if (file-directory? path)
      (list 'directory (read-directory path))
      (list 'file (list 'files (list (list path (read-text path)))))))

;; problems : String String String String (Listof String) Read Read Directory Directory
;;              (Listof Document) -> (Listof String)
;; What is wrong with the floors file at FPATH, the README at RPATH, the files
;; under the workflow directory WDIR, those under the scripts directory SDIR
;; and each document of DPATHS, given F, R, W, S and DS, what reading them
;; found: a Read is what read-text answers, a Directory what read-directory
;; answers, and a Document what read-document answers. A file or directory
;; that cannot be read is a problem of its own, named after the others', the
;; floors file's first, then the README's, then the workflow directory's or its
;; files', in path order, then the scripts', then each document's, in argument
;; order. The README, the workflows, the scripts and the documents are each
;; held to the floors file whenever it and they can be read.
(define (problems fpath rpath wdir sdir dpaths f r w s ds)
  (let ((files (and (eq? (car w) 'files) (cadr w)))
        (scripts (and (eq? (car s) 'files) (cadr s)))
        (ok (and (eq? (car f) 'text) (null? (floors-problems fpath (cadr f))))))
    (append (if (eq? (car f) 'text)
                (append
                 (check-floors fpath (cadr f) rpath (text-or-false r) wdir (texts files))
                 (if (and scripts ok)
                     (scripts-problems fpath sdir (texts scripts) (parse-floors (cadr f)))
                     '())
                 (apply append
                        (map (lambda (dpath d)
                               (let ((pages (and (eq? (car (cadr d)) 'files) (cadr (cadr d)))))
                                 (if (and pages ok)
                                     (docs-problems fpath dpath (texts pages) (parse-floors (cadr f)))
                                     '())))
                             dpaths ds)))
                (list (cadr f)))
            (if (eq? (car r) 'text) '() (list (cadr r)))
            (unreadable w)
            (unreadable s)
            (apply append (map (lambda (d) (unreadable (cadr d))) ds)))))

;; read-names : String Directory -> (Listof String)
;; The paths of the files W found under WDIR, relative to it, in order.
(define (read-names wdir w)
  (let ((skip (+ (string-length wdir) 1)))
    (map (lambda (file) (substring (car file) skip (string-length (car file))))
         (cadr w))))

;; joined : (Listof String) -> String
;; NAMES with ", " between them.
(define (joined names)
  (fold-left (lambda (text name) (if (string=? text "") name (string-append text ", " name)))
             ""
             names))

;; summary : String -> String
;; The floors in the file text FTEXT, which floors-problems accepts: "chez
;; 10.4.0, sodium 1.0.18".
(define (summary ftext)
  (let loop ((rest (parse-floors ftext)) (text ""))
    (if (null? rest)
        text
        (loop (cdr rest)
              (string-append text (if (string=? text "") "" ", ")
                             (symbol->string (caar rest)) " "
                             (cadar rest))))))

;; document-names : String Document -> String
;; What a pass prints of one document: a directory's path and the files read
;; in it, a file's path alone.
(define (document-names path d)
  (if (eq? (car d) 'directory)
      (string-append path " (" (joined (read-names path (cadr d))) ")")
      path))

;; with-and : (Listof String) -> String
;; ITEMS after the text before them: " and X" for one, else ", A, B and C".
(define (with-and items)
  (if (null? (cdr items))
      (string-append " and " (car items))
      (let loop ((rest items) (text ""))
        (if (null? (cdr rest))
            (string-append text " and " (car rest))
            (loop (cdr rest) (string-append text ", " (car rest)))))))

;; main : (Listof String) -> Unit
(define (main args)
  (if (< (length args) 5)
      (begin
        (say (current-error-port)
             "usage: scheme --libdirs tests --program tests/check-floors.sps FLOORS README WORKFLOWS SCRIPTS DOCS...")
        (exit 1))
      (let* ((fpath (car args))
             (rpath (cadr args))
             (wdir (caddr args))
             (sdir (cadddr args))
             (dpaths (cddddr args))
             (f (read-text fpath))
             (r (read-text rpath))
             (w (read-directory wdir))
             (s (read-directory sdir))
             (ds (map read-document dpaths))
             (found (problems fpath rpath wdir sdir dpaths f r w s ds)))
        (cond
          ((null? found)
           (say (current-output-port)
                (string-append rpath ", " wdir " (" (joined (read-names wdir w)) ")"
                               ", " sdir " (" (joined (read-names sdir s)) ")"
                               (with-and (map document-names dpaths ds))
                               " hold the floors in " fpath " (" (summary (cadr f)) ")"))
           (exit 0))
          (else
           (for-each (lambda (p) (say (current-error-port) p)) found)
           (say (current-error-port)
                (string-append "FAILED (problems: " (number->string (length found)) ")"))
           (exit 1))))))

(main (cdr (command-line)))
