;;; ob-lisp.el --- org-babel functions for common lisp evaluation with SLY or SLIME.

;; Copyright (C) 2016-2020 Free Software Foundation, Inc.

;; Authors: stardiviner <numbchild@gmail.com>
;; Maintainer: stardiviner <numbchild@gmail.com>
;; Keywords: org babel lisp sly slime
;; URL: https://github.com/stardiviner/ob-lisp
;; Created: 1th March 2016
;; Version: 0.0.1
;; Package-Requires: ((org "8"))

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Support for evaluating Common Lisp code, relies on SLY or SLIME for all eval.

;;; Requirements:

;; Requires SLY (Sylvester the Cat's Common Lisp IDE) and SLIME
;; See:
;; - https://github.com/capitaomorte/sly
;; - http://common-lisp.net/project/slime/

;;; Code:
(require 'ob)

(defcustom org-babel-lisp-eval-fn "sly-eval"
  "The function to be called to evaluate code on the Lisp side."
  :group 'org-babel
  :version "24.1"
  :options '("sly-eval" "slime-eval")
  :type 'stringp)


;; (declare-function sly-eval "ext:sly" (sexp &optional package))

(defvar org-babel-tangle-lang-exts)
(add-to-list 'org-babel-tangle-lang-exts '("lisp" . "lisp"))

(defvar org-babel-default-header-args:lisp '())
(defvar org-babel-header-args:lisp '((package . :any)))

(defcustom org-babel-lisp-dir-fmt
  "(let ((*default-pathname-defaults* #P%S\n)) %%s\n)"
  "Format string used to wrap code bodies to set the current directory.
For example a value of \"(progn ;; %s\\n   %%s)\" would ignore the
current directory string."
  :group 'org-babel
  :version "24.1"
  :type 'string)

(defun org-babel-expand-body:lisp (body params)
  "Expand BODY according to PARAMS, return the expanded body."
  (let* ((vars (mapcar #'cdr (org-babel-get-header params :var)))
         (result-params (cdr (assoc :result-params params)))
         (print-level nil) (print-length nil)
         (body (org-babel-trim
                (if (> (length vars) 0)
                    (concat "(let ("
                            (mapconcat
                             (lambda (var)
                               (format "(%S (quote %S))" (car var) (cdr var)))
                             vars "\n      ")
                            ")\n" body ")")
                  body))))
    (if (or (member "code" result-params)
            (member "pp" result-params))
        (format "(pprint %s)" body)
      body)))

;;;###autoload
(defun org-babel-execute:lisp (body params)
  "Execute a block `BODY' with `PARAMS' of Common Lisp code with Babel."
  (pcase org-babel-lisp-eval-fn
    ("slime-eval" (require 'slime))
    ("sly-eval" (require 'sly)))
  (org-babel-reassemble-table
   (let ((result
          (funcall (if (member "output" (cdr (assoc :result-params params)))
                       #'car #'cadr)
                   (with-temp-buffer
                     (insert (org-babel-expand-body:lisp body params))
                     (funcall org-babel-lisp-eval-fn
                              `(swank:eval-and-grab-output
                                ,(let ((dir (if (assoc :dir params)
                                                (cdr (assoc :dir params))
                                              default-directory)))
                                   (format
                                    (if dir (format org-babel-lisp-dir-fmt dir)
                                      "(progn %s\n)")
                                    (buffer-substring-no-properties
                                     (point-min) (point-max)))))
                              (cdr (assoc :package params)))))))
     (org-babel-result-cond (cdr (assoc :result-params params))
       result
       (condition-case nil
           (read (org-babel-lisp-vector-to-list result))
         (error result))))
   (org-babel-pick-name (cdr (assoc :colname-names params))
                        (cdr (assoc :colnames params)))
   (org-babel-pick-name (cdr (assoc :rowname-names params))
                        (cdr (assoc :rownames params)))))

(defun org-babel-lisp-vector-to-list (results)
  ;; TODO: better would be to replace #(...) with [...]
  (replace-regexp-in-string "#(" "(" results))

(provide 'ob-lisp)



;;; ob-lisp.el ends here
