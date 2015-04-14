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

;;; Syntax Highlighting ;;;

(defface firth-prims
  '((t (:inherit font-lock-builtin-face)))
  ":Firth prims font."
  :group 'font-lock-faces)
(defvar firth-prims 'firth-prims)

(defface firth-consts
  '((t (:inherit font-lock-constant-face)))
  ": Firth const font."
  :group 'font-lock-faces)
(defvar firth-consts 'firth-consts)

(defface firth-defining-words
  '((t (:inherit firth-prims :weight bold)))
  ": Firth core defining words."
  :group 'font-lock-faces)
(defvar firth-defining-words 'firth-defining-words)

(defface firth-core-words
  '((t (:inherit font-lock-function-name-face)))
  ": Firth word def names."
  :group 'font-lock-faces)
(defvar firth-core-words 'firth-core-words)

(defconst firth-font-lock-prims-pattern
  (list
   `(,(regexp-opt
    '("dup" "over" "drop" "clear" "swap" "rot" "-rot" "pick"
      "C\\>" "\\>C" "C@" "2C\\>" "2\\>C" "2C@"
      "binop" "binopconst"
      "if" "else" "loops" "do" "end"
      "not" "2not"
      "\\.raw" "\\." "\\.x" "\\.\\." "\\.S" "\\.C"
      "loadfile" "exit" "setcompiling" "settarget" "iterpretpending"
      "compiling\\?" "parse" "parsematch" "\\>ts" "push" "create"
      "buildfunc" "bindfunc" "does\\>" "dict" "last" "defined?"
      "@@" "!!" "char" "call"
      "dump" "dumpword:" "trace" "notrace" "tracing\\?" "path"
      "calls:" "calledby:" "tstart" "tend"
      "&" "\\|" "^" "-"
      "NOP") 'words) (1 firth-prims)))
  "Minimal Highlighting for : Firth")

(defconst firth-font-lock-consts-pattern
 (append
  firth-font-lock-prims-pattern
  (list
   `(,(regexp-opt '("true" "false" "nil") 'words)
     (1 firth-consts))))
 "Additional constants for highlighting : Firth Mode")

(defconst firth-font-lock-consts2-pattern
 (append
  firth-font-lock-consts-pattern
  (list
   `(,(regexp-opt
       '("{}"
         "[]") 'words)
     . firth-consts)
   '("char \\([%\]?\\w\\)" . (1 font-lock-string-face))))
 "Additional literals for agregate types for : Firth Mode")

(defconst firth-font-lock-definitions-pattern
  (append
   firth-font-lock-consts2-pattern
   (list
    `(,(regexp-opt
        '(":" ";" "immediate" ";immed"
          "variable" "var:" "val:" "const:" "alias:") 'words)
      . firth-defining-words)
    `(,(concat
        ;; (regexp-opt '(":" "alias:" "var:" "val:" "const:") 'words)
        "\\s-+\\(\\w+\\)\\s-+"
        );; (regexp-opt '(";" ";immed") 'words))
      (1 'font-lock-function-name-face))))
  "Important defining words.")

(defvar firth-font-lock-keywords-pattern firth-font-lock-definitions-pattern
  "Default Highlighting Expression for : Firth Mode")

(defvar firth-mode-syntax-table
  (let ((stab (make-syntax-table)))
    ;; mark typical "punctuation" chars as valid parts of words
    (modify-syntax-entry ?_ "w" stab)
    (modify-syntax-entry ?: "w" stab)
    (modify-syntax-entry ?; "w" stab)
    (modify-syntax-entry ?. "w" stab)
    (modify-syntax-entry ?> "w" stab)
    (modify-syntax-entry ?[ "w" stab)
    (modify-syntax-entry ?] "w" stab)
    (modify-syntax-entry ?{ "w" stab)
    (modify-syntax-entry ?} "w" stab)
    (modify-syntax-entry ?+ "w" stab)
    (modify-syntax-entry ?- "w" stab)
    (modify-syntax-entry ?* "w" stab)
    (modify-syntax-entry ?/ "w" stab)

	;; define what comments look like
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
  (set (make-local-variable 'font-lock-defaults) '(firth-font-lock-keywords-pattern))
;  (set (make-local-variable 'indent-line-function) '(firth-indent-line))
  (setq major-mode 'firth-mode)
  (setq mode-name ": Firth")
  (run-hooks 'firth-mode-hook))

(provide 'firth-mode)
