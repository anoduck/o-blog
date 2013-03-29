;;; o-blog-utils.el --- Some generic function used in o-blog.

;; Copyright © 2013 Sébastien Gross <seb•ɑƬ•chezwam•ɖɵʈ•org>

;; Author: Sébastien Gross <seb•ɑƬ•chezwam•ɖɵʈ•org>
;; Keywords: emacs, 
;; Created: 2013-01-22
;; Last changed: 2013-03-29 20:49:07
;; Licence: WTFPL, grab your copy here: http://sam.zoy.org/wtfpl/

;; This file is NOT part of GNU Emacs.

;;; Commentary:
;; 


;;; Code:

(defun ob:replace-in-string (string replacement-list)
  "Perform a mass `replace-regexp-in-string' against STRING for
all \(regexp rep\) items from REPLACEMENT-LIST and return the
result string."
  (loop for (regexp rep) in replacement-list
	do (setf string (replace-regexp-in-string regexp rep string)))
  string)

(defun ob:sanitize-string (s)
  "Sanitize string S by:

- converting all charcters ton pure ASCII
- replacing non alphanumerical chars to \"-\"
- down-casing all letters
- trimming leading and tailing \"-\""
  (loop for c across s
	with cd
	with gc
	with ret
	do (progn
	     (setf gc (get-char-code-property c 'general-category))
	     (setf cd (get-char-code-property c 'decomposition)))
	if (or (member gc '(Lu Ll Nd)) (= ?- c))
	collect (downcase
		 (char-to-string (if cd (car cd)  c)))
	into ret
	else if (member gc '(Zs))
	collect "-" into ret
	finally return (ob:replace-in-string
			(mapconcat 'identity ret "")
			'(("--+" "-")
			  ("^-+\\|-+$" "")))))

(defun ob:write-file (file)
  "Write current buffer to FILE. Ensure FILE directories are present."
  (mkdir (file-name-directory file) t)
  (let ((buffer (current-buffer)))
    (with-temp-file file
      (insert (with-current-buffer buffer (buffer-string))))))

(defun ob:eval-lisp()
  "Eval embeded lisp code defined by <lisp> tags in html fragment
when publishing a page."
  (save-excursion
    (save-restriction
      (save-match-data
	;; needed for thing-at-point
	(html-mode)
	(beginning-of-buffer)
	(let ((open-tag "<lisp>\\|{lisp}\\|\\[lisp\\]")
	      (close-tag "</lisp>\\|{/lisp}\\|\\[/lisp\\]")
	      beg end sexp)
	  (while (search-forward-regexp open-tag nil t)
	    (setq beg (- (point) (length  (match-string 0))))
	    (when (search-forward-regexp close-tag nil t)
	      (setq end (point))
	      (backward-char (length (match-string 0)))
	      (backward-sexp)
	      (setq sexp (substring-no-properties (thing-at-point 'sexp)))
	      (narrow-to-region beg end)
	      (delete-region (point-min) (point-max))
	      (insert
	       (save-match-data
		 (condition-case err
		     (let ((object (eval (read sexp))))
		       (cond
			;; result is a string
			((stringp object) object)
			;; a list
			((and (listp object)
			      (not (eq object nil)))
			 (let ((string (pp-to-string object)))
			   (substring string 0 (1- (length string)))))
			;; a number
			((numberp object)
			 (number-to-string object))
			;; nil
			((eq object nil) "")
			;; otherwise
			(t (pp-to-string object))))
		   ;; error handler
		   (error
		    (format "Lisp error in %s: %s" (buffer-file-name) err)))))
	      (goto-char (point-min))
	      (widen))))))))

(defun ob:format-date (date &optional format locale)
  "Format DATE using FORMAT and LOCALE.

DATE can heither be string suitable for `parse-time-string' or a
list of interger using `current-time' format.

FORMAT is a `format-time-string' compatible definition. If not
set ISO8601 \"%Y-%m-%dT%TZ\" format would be used."
  (let* ((date (cond
		((stringp date)
		 (apply 'encode-time
			(parse-time-string date)))
		((listp date)
		 date)))
	 (format (or format "%Y-%m-%dT%TZ"))
	 (system-time-locale locale))
    (format-time-string format date)))

(defun ob:path-to-root ()
  "Return path to site root from `PATH-TO-ROOT' or `POST'
path-to-root slot."
  (cond
   ((boundp 'PATH-TO-ROOT) PATH-TO-ROOT)
   ((boundp 'POST) (ob:entry:get 'path-to-root POST))
   (t ".")))

(defun ob:get (slot &optional object)
  "Try to get SLOT from OBJECT.

If object is `nil' try to get SLOT from:

- TAG
- CATEGORY
- POST
- BLOG"
  (if object
      (when (slot-exists-p object slot)
	(slot-value object slot))
    (loop for o in '(TAG CATEGORY POST BLOG)
	  when (and (boundp o) (slot-exists-p (eval o) slot))
	  return (slot-value (eval o) slot))))

(defun ob:get-post-by-id (id)
  "Return post which id is ID"
  (let ((POSTS (or (when (boundp 'POSTS) POSTS)
		   (ob:get 'articles BLOG))))
    (when (>= id 0)
      (nth id POSTS))))


(defun ob:get-name (object)
  "Return OBJECT class name."
  (if (boundp 'object-name)
      (aref object object-name)
    (eieio-object-name-string object)))


;; FIXME: do no use ob-bck-end
(defun ob:insert-template (template &optional ob-bck-end)
  "Return the lisp evaluated (see `ob:eval-lisp') content of
TEMPLATE (relative from `ob:backend' `template' slot) as a
string."
  (insert
   (with-temp-buffer
     (insert-file-contents
      (format "%s/%s" (ob:get 'template-dir ob-bck-end) template))
     (ob:eval-lisp)
     (buffer-string))))

(provide 'o-blog-utils)

;; o-blog-utils.el ends here
