; let users hook loading firth mode
(defvar firth-mode-hook nil)

; keymap for macro keys
(defvar firth-mode-map
  (let ((map (make-keymap)))
    (define-key map "\C-j" 'newline-and-indent)
    map)
  "Keymap for : Firth Major Mode")

; automatically load firth-mode, for .firth files
(add-to-list 'auto-mode-alist '("\\.firth\\'" . firth-mode))

;;; Syntax HIghlighting ;;;

(defconst firth-font-lock-keywords-1
  (list
   `(,(regexp-opt
    '(":" ";"
      "dup" "over" "drop" "clear" "swap" "rot" "-rot" "pick"
      "C\\>" "\\>C" "C@" "2C\\>" "2\\>C" "2C@"
      "binop" "bionopconst"
      "if" "else" "loops" "do" "end"
      "not" "2not"
      "\\.raw" "\\." "\\.x" "\\.\\." "\\.S" "\\.C"
      "loadfile" "exit" "setcompiling" "settarget" "iterpretpending"
      "compiling\\?" "parse" "parsematch" "\\>ts" "push" "create" "alias:"
      "buildfunc" "bindfunc" "does\\>" "dict" "last" "defined?"
      "@@" "!!" "immediate" "char" "call"
      "dump" "dumpword:" "trace" "notrace" "tracing\\?" "path"
      "calls:" "calledby:" "tstart" "tend"
      "&" "\\|" "^" "-"
      "NOP") 'words) . font-lock-builtin-face)
   '("\\('\\w*\\)" . font-lock-variable-name-face)) ; is this correct?
  "Minimal Highlighting for : Firth")

(defvar firth-font-lock-keywords firth-font-lock-keywords-1
  "Default Highlighting Expression for : Firth Mode")

(defvar firth-mode-syntax-table
  (let ((stab (make-syntax-table)))
    (modify-syntax-entry ?_ "w" stab)
    (modify-syntax-entry ?: "w" stab)
    (modify-syntax-entry ?/ ". 124b" stab)
    (modify-syntax-entry ?\n "> b" stab)
    stab)
  "Syntax Table for : Firth Mode")

;;; Indentation ;;;

;; TODO

;;; : Firth Mode Init and Entry ;;;

(defun firth-mode ()
  "Major Mode for Editing : Firth Files"
  (interactive)
  (kill-all-local-variables)
  (set-syntax-table firth-mode-syntax-table)
  (use-local-map firth-mode-map)
  (set (make-local-variable 'font-lock-defaults) '(firth-font-lock-keywords))
;  (set (make-local-variable 'indent-line-function) '(firth-indent-line))
  (setq major-mode 'firth-mode)
  (setq mode-name ": Firth")
  (run-hooks 'firth-mode-hook))

(provide 'firth-mode)
