;;; Janusz S. Bien 2002
;;; texlog.el --- texlog mode commands for Emacs

;; Copyright (C) 1986, 93, 94, 95, 97, 2000, 2001
;;   Free Software Foundation, Inc.

;; Maintainer: FSF
;; Keywords: texlogs

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; This package is a major mode for editing texlog-format documents.
;; An texlog can be `abstracted' to show headers at any given level,
;; with all stuff below hidden.  See the Emacs manual for details.

;;; Todo:

;; - subtree-terminators

;;; Code:

(defgroup texlogs nil
  "Support for hierarchical outlining"
  :prefix "texlog-"
  :group 'editing)

;(defcustom texlog-regexp "[*\^L]+"
(defcustom texlog-regexp "[\.\^L]+"
  "*Regular expression to match the beginning of a heading.
Any line whose beginning matches this regexp is considered to start a heading.
Note that Texlog mode only checks this regexp at the start of a line,
so the regexp need not (and usually does not) start with `^'.
The recommended way to set this is with a Local Variables: list
in the file it applies to.  See also `texlog-heading-end-regexp'."
  :type '(choice regexp (const nil))
  :group 'texlogs)

(defcustom texlog-heading-end-regexp "\n"
  "*Regular expression to match the end of a heading line.
You can assume that point is at the beginning of a heading when this
regexp is searched for.  The heading ends at the end of the match.
The recommended way to set this is with a `Local Variables:' list
in the file it applies to."
  :type 'regexp
  :group 'texlogs)

(defvar texlog-mode-prefix-map nil)

(if texlog-mode-prefix-map
    nil
  (setq texlog-mode-prefix-map (make-sparse-keymap))
  (define-key texlog-mode-prefix-map "@" 'texlog-mark-subtree)
  (define-key texlog-mode-prefix-map "\C-n" 'texlog-next-visible-heading)
  (define-key texlog-mode-prefix-map "\C-p" 'texlog-previous-visible-heading)
  (define-key texlog-mode-prefix-map "\C-i" 'show-children)
  (define-key texlog-mode-prefix-map "\C-s" 'show-subtree)
  (define-key texlog-mode-prefix-map "\C-d" 'hide-subtree)
  (define-key texlog-mode-prefix-map "\C-u" 'texlog-up-heading)
  (define-key texlog-mode-prefix-map "\C-f" 'texlog-forward-same-level)
  (define-key texlog-mode-prefix-map "\C-b" 'texlog-backward-same-level)
  (define-key texlog-mode-prefix-map "\C-t" 'hide-body)
  (define-key texlog-mode-prefix-map "\C-a" 'show-all)
  (define-key texlog-mode-prefix-map "\C-c" 'hide-entry)
  (define-key texlog-mode-prefix-map "\C-e" 'show-entry)
  (define-key texlog-mode-prefix-map "\C-l" 'hide-leaves)
  (define-key texlog-mode-prefix-map "\C-k" 'show-branches)
  (define-key texlog-mode-prefix-map "\C-q" 'hide-sublevels)
  (define-key texlog-mode-prefix-map "\C-o" 'hide-other))

(defvar texlog-mode-menu-bar-map nil)
(if texlog-mode-menu-bar-map
    nil
  (setq texlog-mode-menu-bar-map (make-sparse-keymap))

  (define-key texlog-mode-menu-bar-map [hide]
    (cons "Hide" (make-sparse-keymap "Hide")))

  (define-key texlog-mode-menu-bar-map [hide hide-other]
    '("Hide Other" . hide-other))
  (define-key texlog-mode-menu-bar-map [hide hide-sublevels]
    '("Hide Sublevels" . hide-sublevels))
  (define-key texlog-mode-menu-bar-map [hide hide-subtree]
    '("Hide Subtree" . hide-subtree))
  (define-key texlog-mode-menu-bar-map [hide hide-entry]
    '("Hide Entry" . hide-entry))
  (define-key texlog-mode-menu-bar-map [hide hide-body]
    '("Hide Body" . hide-body))
  (define-key texlog-mode-menu-bar-map [hide hide-leaves]
    '("Hide Leaves" . hide-leaves))

  (define-key texlog-mode-menu-bar-map [show]
    (cons "Show" (make-sparse-keymap "Show")))

  (define-key texlog-mode-menu-bar-map [show show-subtree]
    '("Show Subtree" . show-subtree))
  (define-key texlog-mode-menu-bar-map [show show-children]
    '("Show Children" . show-children))
  (define-key texlog-mode-menu-bar-map [show show-branches]
    '("Show Branches" . show-branches))
  (define-key texlog-mode-menu-bar-map [show show-entry]
    '("Show Entry" . show-entry))
  (define-key texlog-mode-menu-bar-map [show show-all]
    '("Show All" . show-all))

  (define-key texlog-mode-menu-bar-map [headings]
    (cons "Headings" (make-sparse-keymap "Headings")))

  (define-key texlog-mode-menu-bar-map [headings copy]
    '(menu-item "Copy to kill ring" texlog-headers-as-kill
		:enable mark-active))
  (define-key texlog-mode-menu-bar-map [headings texlog-backward-same-level]
    '("Previous Same Level" . texlog-backward-same-level))
  (define-key texlog-mode-menu-bar-map [headings texlog-forward-same-level]
    '("Next Same Level" . texlog-forward-same-level))
  (define-key texlog-mode-menu-bar-map [headings texlog-previous-visible-heading]
    '("Previous" . texlog-previous-visible-heading))
  (define-key texlog-mode-menu-bar-map [headings texlog-next-visible-heading]
    '("Next" . texlog-next-visible-heading))
  (define-key texlog-mode-menu-bar-map [headings texlog-up-heading]
    '("Up" . texlog-up-heading)))

(defvar texlog-mode-map nil "")

(if texlog-mode-map
    nil
  (setq texlog-mode-map (nconc (make-sparse-keymap) text-mode-map))
  (define-key texlog-mode-map "\C-c" texlog-mode-prefix-map)
  (define-key texlog-mode-map [menu-bar] texlog-mode-menu-bar-map))

(defvar texlog-font-lock-keywords
  '(;;
    ;; Highlight headings according to the level.
    (eval . (list (concat "^" texlog-regexp ".+")
		  0 '(or (cdr (assq (texlog-font-lock-level)
				    '((1 . font-lock-function-name-face)
				      (2 . font-lock-variable-name-face)
				      (3 . font-lock-keyword-face)
				      (4 . font-lock-builtin-face)
				      (5 . font-lock-comment-face)
				      (6 . font-lock-constant-face)
				      (7 . font-lock-type-face)
				      (8 . font-lock-string-face))))
			 font-lock-warning-face)
		  nil t)))
  "Additional expressions to highlight in Texlog mode.")

(defun texlog-font-lock-level ()
  (let ((count 1))
    (save-excursion
      (texlog-back-to-heading t)
      (while (and (not (bobp))
		  (not (eq (funcall texlog-level) 1)))
	(texlog-up-heading-all 1)
	(setq count (1+ count)))
      count)))

(defvar texlog-view-change-hook nil
  "Normal hook to be run after texlog visibility changes.")

;;;###autoload
(define-derived-mode texlog-mode text-mode "Texlog"
  "Set major mode for editing texlogs with selective display.
Headings are lines which start with asterisks: one for major headings,
two for subheadings, etc.  Lines not starting with asterisks are body lines.

Body text or subheadings under a heading can be made temporarily
invisible, or visible again.  Invisible lines are attached to the end
of the heading, so they move with it, if the line is killed and yanked
back.  A heading with text hidden under it is marked with an ellipsis (...).

Commands:\\<texlog-mode-map>
\\[texlog-next-visible-heading]   texlog-next-visible-heading      move by visible headings
\\[texlog-previous-visible-heading]   texlog-previous-visible-heading
\\[texlog-forward-same-level]   texlog-forward-same-level        similar but skip subheadings
\\[texlog-backward-same-level]   texlog-backward-same-level
\\[texlog-up-heading]   texlog-up-heading		    move from subheading to heading

\\[hide-body]	make all text invisible (not headings).
\\[show-all]	make everything in buffer visible.

The remaining commands are used when point is on a heading line.
They apply to some of the body or subheadings of that heading.
\\[hide-subtree]   hide-subtree	make body and subheadings invisible.
\\[show-subtree]   show-subtree	make body and subheadings visible.
\\[show-children]   show-children	make direct subheadings visible.
		 No effect on body, or subheadings 2 or more levels down.
		 With arg N, affects subheadings N levels down.
\\[hide-entry]	   make immediately following body invisible.
\\[show-entry]	   make it visible.
\\[hide-leaves]	   make body under heading and under its subheadings invisible.
		     The subheadings remain visible.
\\[show-branches]  make all subheadings at all levels visible.

The variable `texlog-regexp' can be changed to control what is a heading.
A line is a heading if `texlog-regexp' matches something at the
beginning of the line.  The longer the match, the deeper the level.

Turning on texlog mode calls the value of `text-mode-hook' and then of
`texlog-mode-hook', if they are non-nil."
  (make-local-variable 'line-move-ignore-invisible)
  (setq line-move-ignore-invisible t)
  ;; Cause use of ellipses for invisible text.
  (add-to-invisibility-spec '(texlog . t))
  (set (make-local-variable 'paragraph-start)
       (concat paragraph-start "\\|\\(" texlog-regexp "\\)"))
  ;; Inhibit auto-filling of header lines.
  (set (make-local-variable 'auto-fill-inhibit-regexp) texlog-regexp)
  (set (make-local-variable 'paragraph-separate)
       (concat paragraph-separate "\\|\\(" texlog-regexp "\\)"))
  (set (make-local-variable 'font-lock-defaults)
       '(texlog-font-lock-keywords t nil nil backward-paragraph))
  (setq imenu-generic-expression
	(list (list nil (concat "^\\(?:" texlog-regexp "\\).*$") 0)))
  (add-hook 'change-major-mode-hook 'show-all nil t))

(defcustom texlog-minor-mode-prefix "\C-c@"
  "*Prefix key to use for Texlog commands in Texlog minor mode.
The value of this variable is checked as part of loading Texlog mode.
After that, changing the prefix key requires manipulating keymaps."
  :type 'string
  :group 'texlogs)

;;;###autoload
(define-minor-mode texlog-minor-mode
  "Toggle Texlog minor mode.
With arg, turn Texlog minor mode on if arg is positive, off otherwise.
See the command `texlog-mode' for more information on this mode."
  nil " Outl" (list (cons [menu-bar] texlog-mode-menu-bar-map)
		    (cons texlog-minor-mode-prefix texlog-mode-prefix-map))
  (if texlog-minor-mode
      (progn
	;; Turn off this mode if we change major modes.
	(add-hook 'change-major-mode-hook
		  (lambda () (texlog-minor-mode -1))
		  nil t)
	(set (make-local-variable 'line-move-ignore-invisible) t)
	;; Cause use of ellipses for invisible text.
	(add-to-invisibility-spec '(texlog . t)))
    (setq line-move-ignore-invisible nil)
    ;; Cause use of ellipses for invisible text.
    (remove-from-invisibility-spec '(texlog . t)))
  ;; When turning off texlog mode, get rid of any texlog hiding.
  (or texlog-minor-mode
      (show-all)))

(defcustom texlog-level 'texlog-level
  "*Function of no args to compute a header's nesting level in an texlog.
It can assume point is at the beginning of a header line."
  :type 'function
  :group 'texlogs)

;; This used to count columns rather than characters, but that made ^L
;; appear to be at level 2 instead of 1.  Columns would be better for
;; tab handling, but the default regexp doesn't use tabs, and anyone
;; who changes the regexp can also redefine the texlog-level variable
;; as appropriate.
(defun texlog-level ()
  "Return the depth to which a statement is nested in the texlog.
Point must be at the beginning of a header line.  This is actually
the number of characters that `texlog-regexp' matches."
  (save-excursion
    (looking-at texlog-regexp)
    (- (match-end 0) (match-beginning 0))))

(defun texlog-next-preface ()
  "Skip forward to just before the next heading line.
If there's no following heading line, stop before the newline
at the end of the buffer."
  (if (re-search-forward (concat "\n\\(" texlog-regexp "\\)")
			 nil 'move)
      (goto-char (match-beginning 0)))
  (if (and (bolp) (not (bobp)))
      (forward-char -1)))

(defun texlog-next-heading ()
  "Move to the next (possibly invisible) heading line."
  (interactive)
  (if (re-search-forward (concat "\n\\(" texlog-regexp "\\)")
			 nil 'move)
      (goto-char (1+ (match-beginning 0)))))

(defun texlog-previous-heading ()
  "Move to the previous (possibly invisible) heading line."
  (interactive)
  (re-search-backward (concat "^\\(" texlog-regexp "\\)")
		      nil 'move))

(defsubst texlog-invisible-p ()
  "Non-nil if the character after point is invisible."
  (get-char-property (point) 'invisible))
(defun texlog-visible ()
  "Obsolete.  Use `texlog-invisible-p'."
  (not (texlog-invisible-p)))

(defun texlog-back-to-heading (&optional invisible-ok)
  "Move to previous heading line, or beg of this line if it's a heading.
Only visible heading lines are considered, unless INVISIBLE-OK is non-nil."
  (beginning-of-line)
  (or (texlog-on-heading-p invisible-ok)
      (let (found)
	(save-excursion
	  (while (not found)
	    (or (re-search-backward (concat "^\\(" texlog-regexp "\\)")
				    nil t)
		(error "before first heading"))
	    (setq found (and (or invisible-ok (texlog-visible)) (point)))))
	(goto-char found)
	found)))

(defun texlog-on-heading-p (&optional invisible-ok)
  "Return t if point is on a (visible) heading line.
If INVISIBLE-OK is non-nil, an invisible heading line is ok too."
  (save-excursion
    (beginning-of-line)
    (and (bolp) (or invisible-ok (texlog-visible))
	 (looking-at texlog-regexp))))

(defun texlog-end-of-heading ()
  (if (re-search-forward texlog-heading-end-regexp nil 'move)
      (forward-char -1)))

(defun texlog-next-visible-heading (arg)
  "Move to the next visible heading line.
With argument, repeats or can move backward if negative.
A heading line is one that starts with a `*' (or that
`texlog-regexp' matches)."
  (interactive "p")
  (if (< arg 0)
      (beginning-of-line)
    (end-of-line))
  (while (and (not (bobp)) (< arg 0))
    (while (and (not (bobp))
		(re-search-backward (concat "^\\(" texlog-regexp "\\)")
				    nil 'move)
		(not (texlog-visible))))
    (setq arg (1+ arg)))
  (while (and (not (eobp)) (> arg 0))
    (while (and (not (eobp))
		(re-search-forward (concat "^\\(" texlog-regexp "\\)")
				   nil 'move)
		(not (texlog-visible))))
    (setq arg (1- arg)))
  (beginning-of-line))

(defun texlog-previous-visible-heading (arg)
  "Move to the previous heading line.
With argument, repeats or can move forward if negative.
A heading line is one that starts with a `*' (or that
`texlog-regexp' matches)."
  (interactive "p")
  (texlog-next-visible-heading (- arg)))

(defun texlog-mark-subtree ()
  "Mark the current subtree in an texlogd document.
This puts point at the start of the current subtree, and mark at the end."
  (interactive)
  (let ((beg))
    (if (texlog-on-heading-p)
	;; we are already looking at a heading
	(beginning-of-line)
      ;; else go back to previous heading
      (texlog-previous-visible-heading 1))
    (setq beg (point))
    (texlog-end-of-subtree)
    (push-mark (point))
    (goto-char beg)))

(defun texlog-flag-region (from to flag)
  "Hides or shows lines from FROM to TO, according to FLAG.
If FLAG is nil then text is shown, while if FLAG is t the text is hidden."
  (save-excursion
    (goto-char from)
    (end-of-line)
    (texlog-discard-overlays (point) to 'texlog)
    (if flag
	(let ((o (make-overlay (point) to)))
	  (overlay-put o 'invisible 'texlog)
	  (overlay-put o 'isearch-open-invisible
		       'texlog-isearch-open-invisible))))
  (run-hooks 'texlog-view-change-hook))


;; Function to be set as an texlog-isearch-open-invisible' property
;; to the overlay that makes the texlog invisible (see
;; `texlog-flag-region').
(defun texlog-isearch-open-invisible (overlay)
  ;; We rely on the fact that isearch places point one the matched text.
  (show-entry))


;; Exclude from the region BEG ... END all overlays
;; which have PROP as the value of the `invisible' property.
;; Exclude them by shrinking them to exclude BEG ... END,
;; or even by splitting them if necessary.
;; Overlays without such an `invisible' property are not touched.
(defun texlog-discard-overlays (beg end prop)
  (if (< end beg)
      (setq beg (prog1 end (setq end beg))))
  (save-excursion
    (dolist (o (overlays-in beg end))
      (if (eq (overlay-get o 'invisible) prop)
	  ;; Either push this overlay outside beg...end
	  ;; or split it to exclude beg...end
	  ;; or delete it entirely (if it is contained in beg...end).
	  (if (< (overlay-start o) beg)
	      (if (> (overlay-end o) end)
		  (progn
		    (move-overlay (texlog-copy-overlay o)
				  (overlay-start o) beg)
		    (move-overlay o end (overlay-end o)))
		(move-overlay o (overlay-start o) beg))
	    (if (> (overlay-end o) end)
		(move-overlay o end (overlay-end o))
	      (delete-overlay o)))))))

;; Make a copy of overlay O, with the same beginning, end and properties.
(defun texlog-copy-overlay (o)
  (let ((o1 (make-overlay (overlay-start o) (overlay-end o)
			  (overlay-buffer o)))
	(props (overlay-properties o)))
    (while props
      (overlay-put o1 (car props) (nth 1 props))
      (setq props (cdr (cdr props))))
    o1))

(defun hide-entry ()
  "Hide the body directly following this heading."
  (interactive)
  (texlog-back-to-heading)
  (texlog-end-of-heading)
  (save-excursion
   (texlog-flag-region (point) (progn (texlog-next-preface) (point)) t)))

(defun show-entry ()
  "Show the body directly following this heading.
Show the heading too, if it is currently invisible."
  (interactive)
  (save-excursion
    (texlog-back-to-heading t)
    (texlog-flag-region (1- (point))
			 (progn (texlog-next-preface) (point)) nil)))

(defun hide-body ()
  "Hide all of buffer except headings."
  (interactive)
  (hide-region-body (point-min) (point-max)))

(defun hide-region-body (start end)
  "Hide all body lines in the region, but not headings."
  ;; Nullify the hook to avoid repeated calls to `texlog-flag-region'
  ;; wasting lots of time running `lazy-lock-fontify-after-texlog'
  ;; and run the hook finally.
  (let (texlog-view-change-hook)
    (save-excursion
      (save-restriction
	(narrow-to-region start end)
	(goto-char (point-min))
	(if (texlog-on-heading-p)
	    (texlog-end-of-heading))
	(while (not (eobp))
	  (texlog-flag-region (point)
			       (progn (texlog-next-preface) (point)) t)
	  (unless (eobp)
	    (forward-char (if (looking-at "\n\n") 2 1))
	    (texlog-end-of-heading))))))
  (run-hooks 'texlog-view-change-hook))

(defun show-all ()
  "Show all of the text in the buffer."
  (interactive)
  (texlog-flag-region (point-min) (point-max) nil))

(defun hide-subtree ()
  "Hide everything after this heading at deeper levels."
  (interactive)
  (texlog-flag-subtree t))

(defun hide-leaves ()
  "Hide all body after this heading at deeper levels."
  (interactive)
  (texlog-back-to-heading)
  (save-excursion
    (texlog-end-of-heading)
    (hide-region-body (point) (progn (texlog-end-of-subtree) (point)))))

(defun show-subtree ()
  "Show everything after this heading at deeper levels."
  (interactive)
  (texlog-flag-subtree nil))

(defun hide-sublevels (levels)
  "Hide everything but the top LEVELS levels of headers, in whole buffer."
  (interactive "p")
  (if (< levels 1)
      (error "Must keep at least one level of headers"))
  (setq levels (1- levels))
  (let (texlog-view-change-hook)
    (save-excursion
      (goto-char (point-min))
      ;; Keep advancing to the next top-level heading.
      (while (or (and (bobp) (texlog-on-heading-p))
		 (texlog-next-heading))
	(let ((end (save-excursion (texlog-end-of-subtree) (point))))
	  ;; Hide everything under that.
	  (texlog-flag-region (point) end t)
	  ;; Show the first LEVELS levels under that.
	  (if (> levels 0)
	      (show-children levels))
	  ;; Move to the next, since we already found it.
	  (goto-char end)))))
  (run-hooks 'texlog-view-change-hook))

(defun hide-other ()
  "Hide everything except current body and parent and top-level headings."
  (interactive)
  (hide-sublevels 1)
  (let (texlog-view-change-hook)
    (save-excursion
      (texlog-back-to-heading t)
      (show-entry)
      (while (condition-case nil (progn (texlog-up-heading 1) (not (bobp)))
	       (error nil))
	(texlog-flag-region (1- (point))
			     (save-excursion (forward-line 1) (point))
			     nil))))
  (run-hooks 'texlog-view-change-hook))

(defun texlog-flag-subtree (flag)
  (save-excursion
    (texlog-back-to-heading)
    (texlog-end-of-heading)
    (texlog-flag-region (point)
			  (progn (texlog-end-of-subtree) (point))
			  flag)))

(defun texlog-end-of-subtree ()
  (texlog-back-to-heading)
  (let ((opoint (point))
	(first t)
	(level (funcall texlog-level)))
    (while (and (not (eobp))
		(or first (> (funcall texlog-level) level)))
      (setq first nil)
      (texlog-next-heading))
    (if (bolp)
	(progn
	  ;; Go to end of line before heading
	  (forward-char -1)
	  (if (bolp)
	      ;; leave blank line before heading
	      (forward-char -1))))))

(defun show-branches ()
  "Show all subheadings of this heading, but not their bodies."
  (interactive)
  (show-children 1000))

(defun show-children (&optional level)
  "Show all direct subheadings of this heading.
Prefix arg LEVEL is how many levels below the current level should be shown.
Default is enough to cause the following heading to appear."
  (interactive "P")
  (setq level
	(if level (prefix-numeric-value level)
	  (save-excursion
	    (texlog-back-to-heading)
	    (let ((start-level (funcall texlog-level)))
	      (texlog-next-heading)
	      (if (eobp)
		  1
		(max 1 (- (funcall texlog-level) start-level)))))))
  (let (texlog-view-change-hook)
    (save-excursion
      (save-restriction
	(texlog-back-to-heading)
	(setq level (+ level (funcall texlog-level)))
	(narrow-to-region (point)
			  (progn (texlog-end-of-subtree)
				 (if (eobp) (point-max) (1+ (point)))))
	(goto-char (point-min))
	(while (and (not (eobp))
		    (progn
		      (texlog-next-heading)
		      (not (eobp))))
	  (if (<= (funcall texlog-level) level)
	      (save-excursion
		(texlog-flag-region (save-excursion
				       (forward-char -1)
				       (if (bolp)
					   (forward-char -1))
				       (point))
				     (progn (texlog-end-of-heading) (point))
				     nil)))))))
  (run-hooks 'texlog-view-change-hook))

(defun texlog-up-heading-all (arg)
  "Move to the heading line of which the present line is a subheading.
This function considers both visible and invisible heading lines.
With argument, move up ARG levels."
  (texlog-back-to-heading t)
  (if (eq (funcall texlog-level) 1)
      (error "Already at top level of the texlog"))
  (while (and (> (funcall texlog-level) 1)
	      (> arg 0)
	      (not (bobp)))
    (let ((present-level (funcall texlog-level)))
      (while (and (not (< (funcall texlog-level) present-level))
		  (not (bobp)))
	(texlog-previous-heading))
      (setq arg (- arg 1)))))

(defun texlog-up-heading (arg)
  "Move to the visible heading line of which the present line is a subheading.
With argument, move up ARG levels."
  (interactive "p")
  (texlog-back-to-heading)
  (if (eq (funcall texlog-level) 1)
      (error "Already at top level of the texlog"))
  (while (and (> (funcall texlog-level) 1)
	      (> arg 0)
	      (not (bobp)))
    (let ((present-level (funcall texlog-level)))
      (while (and (not (< (funcall texlog-level) present-level))
		  (not (bobp)))
	(texlog-previous-visible-heading 1))
      (setq arg (- arg 1)))))

(defun texlog-forward-same-level (arg)
  "Move forward to the ARG'th subheading at same level as this one.
Stop at the first and last subheadings of a superior heading."
  (interactive "p")
  (texlog-back-to-heading)
  (while (> arg 0)
    (let ((point-to-move-to (save-excursion
			      (texlog-get-next-sibling))))
      (if point-to-move-to
	  (progn
	    (goto-char point-to-move-to)
	    (setq arg (1- arg)))
	(progn
	  (setq arg 0)
	  (error "No following same-level heading"))))))

(defun texlog-get-next-sibling ()
  "Move to next heading of the same level, and return point or nil if none."
  (let ((level (funcall texlog-level)))
    (texlog-next-visible-heading 1)
    (while (and (> (funcall texlog-level) level)
		(not (eobp)))
      (texlog-next-visible-heading 1))
    (if (< (funcall texlog-level) level)
	nil
      (point))))

(defun texlog-backward-same-level (arg)
  "Move backward to the ARG'th subheading at same level as this one.
Stop at the first and last subheadings of a superior heading."
  (interactive "p")
  (texlog-back-to-heading)
  (while (> arg 0)
    (let ((point-to-move-to (save-excursion
			      (texlog-get-last-sibling))))
      (if point-to-move-to
	  (progn
	    (goto-char point-to-move-to)
	    (setq arg (1- arg)))
	(progn
	  (setq arg 0)
	  (error "No previous same-level heading"))))))

(defun texlog-get-last-sibling ()
  "Move to previous heading of the same level, and return point or nil if none."
  (let ((level (funcall texlog-level)))
    (texlog-previous-visible-heading 1)
    (while (and (> (funcall texlog-level) level)
		(not (bobp)))
      (texlog-previous-visible-heading 1))
    (if (< (funcall texlog-level) level)
	nil
        (point))))

(defun texlog-headers-as-kill (beg end)
  "Save the visible texlog headers in region at the start of the kill ring.

Text shown between the headers isn't copied.  Two newlines are
inserted between saved headers.  Yanking the result may be a
convenient way to make a table of contents of the buffer."
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (let ((buffer (current-buffer))
	    start end)
	(with-temp-buffer
	  (with-current-buffer buffer
	    ;; Boundary condition: starting on heading:
	    (when (texlog-on-heading-p)
	      (texlog-back-to-heading)
	      (setq start (point)
		    end (progn (texlog-end-of-heading)
			       (point)))
	      (insert-buffer-substring buffer start end)
	      (insert "\n\n")))
	  (let ((temp-buffer (current-buffer)))
	    (with-current-buffer buffer
	      (while (texlog-next-heading)
		(when (texlog-visible)
		  (setq start (point)
			end (progn (texlog-end-of-heading) (point)))
		  (with-current-buffer temp-buffer
		    (insert-buffer-substring buffer start end)
		    (insert "\n\n"))))))
	  (kill-new (buffer-string)))))))

(provide 'texlog)
(provide 'ntexlog)

;;; texlog.el ends here
