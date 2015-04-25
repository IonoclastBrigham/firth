;; firth-mode.el
;; :Firth source editing major mode
;;
;; Copyright © 2015 Brigham Toskin
;;
;; To automatically load firth-mode for .firth files, install firth-mode.el on
;; your library load path and add the following lines to your .emacs file:
;;   (autoload 'firth-mode "firth-mode" nil t)
;;   (add-to-list 'auto-mode-alist '("\\.firth\\'" . firth-mode))

; keymap for macro keys
(defvar firth-mode-map
  (let ((map (make-keymap)))
    (define-key map "\C-j" 'newline-and-indent)
    map)
  "Keymap for :Firth Major Mode")

;;; Syntax Highlighting ;;;

(defface firth-prims
  '((t (:inherit font-lock-builtin-face)))
  ":Firth prims font."
  :group 'font-lock-faces)
(defvar firth-prims 'firth-prims)

(defface firth-consts
  '((t (:inherit font-lock-constant-face)))
  ":Firth const font."
  :group 'font-lock-faces)
(defvar firth-consts 'firth-consts)

(defface firth-defining-words
  '((t (:inherit firth-prims :weight bold)))
  ":Firth core defining words."
  :group 'font-lock-faces)
(defvar firth-defining-words 'firth-defining-words)

(defface firth-word-def-name
  '((t (:inherit font-lock-function-name-face :weight bold)))
  ":Firth new word definition name."
  :group 'font-lock-faces)
(defvar firth-word-def-name 'firth-word-def-name)

(defface firth-ticked-word
  '((t (:inherit font-lock-keyword-face :slant oblique)))
  "Ticked :Firth words."
  :group 'font-lock-faces)
(defvar firth-ticked-word 'firth-ticked-word)

(defface firth-core-words
  '((t (:inherit font-lock-keyword-face)))
  ":Firth word def names."
  :group 'font-lock-faces)
(defvar firth-core-words 'firth-core-words)

(defconst firth-prims-pattern
  (list
   `(,(regexp-opt
    '("dup" "over" "drop" "clear" "swap" "rot" "-rot" "pick"
      "C>" ">C" "C@" "2C>" "2>C" "2C@"
      "binop" "binopconst"
      "if" "else" "loops" "do" "end"
      "not" "2not"
      ".raw" "." ".x" ".." ".S" ".C"
      "loadfile" "exit"
      "setcompiling" "settarget" "interpret" "interpretpending"
      "compiling?" "parse" "parsematch" ">ts" "push" "create"
      "buildfunc" "bindfunc" "dict" "last" "defined?"
      "@@" "!!" "char" "call" "execute"
      "dump" "dumpword:" "trace" "notrace" "tracing?" "path"
      "calls:" "calledby:" "tstart" "tend"
      "&" "|" "^"
      "NOP") 'words) (1 firth-prims)))
  "Minimal Highlighting for :Firth")

(defconst firth-consts-pattern
  (list
   ;; strings and chars
   '("\\<\"\\s-.*?\"\\.?\\>" .  font-lock-string-face)
   '("\\<char\\s-+\\([%\\]?\\w\\)" . (1 font-lock-string-face))
   '("\\<\\(?:\\\\n\\|%s\\)\\>" . font-lock-string-face)

   ;; booleans, nil refs
   `(,(regexp-opt '("true" "false" "nil") 'words) . firth-consts)

   ;; integer and float numbers
   '("\\<[+-]?[[:digit:]]+\\>" . firth-consts)
   '("\\<[+-]?[[:digit:]]+\\.[[:digit:]]+\\(?:[Ee][+-]?[[:digit:]]+\\)?\\>" . firth-consts)
   '("\\<0[Xx][[:xdigit:]]+\\>" . firth-consts))
 "Additional constants for highlighting :Firth Mode")

(defconst firth-comments-pattern
  (list
   '("\\<\\(//\\)\\>\\(.*\\)" (1 font-lock-comment-face) (2 font-lock-comment-face))
   '("\\<(.*)\\>" . font-lock-comment-face))
  ":Firth standard comments.")

(defconst firth-agregate-literals-pattern
  (list
   '("\\<{}\\|\\[\\]\\>" . firth-consts)
   '("\\<\\(?:DATA\\|VERSION\\)\\>" . firth-consts))
 "Additional literals for agregate types for :Firth Mode")

(defconst firth-definitions-pattern
   (list
    ;; new word definition names
    `(,(concat
        "\\<\\:\\s-+"										; opening colon
        "\\(\\w+\\)"										; capture name
        "[[:space:][:word:]]+?"								; def body
		"\\(?:bindfunc\\|;\\(?:immed\\|defer\\)?\\)\\>")	; matches def close
      (1 'firth-word-def-name))

    ;; aliases, variables, etc.
    `(,(concat
        "\\<\\(?:alias\\|var\\|val\\|const\\):"
        "\\s-+\\(\\w+\\)\\>")
      (1 firth-word-def-name))

    ;; postponed calls and ticked words
    '("\\<\\(?:postpone\\|call:\\|'\\|does>\\|`\\)\\s-+\\(\\w+\\)\\>"
	  (1 firth-ticked-word))

    ;; the defining words themselves
    `(,(regexp-opt
        '(":" ";" "immediate" ";immed" "?deferred" ";defer"
          "variable" "var:" "val:" "const:" "alias:" "does>") 'words)
      . firth-defining-words))
  "Important defining words from prims and core.")

(defconst firth-core-words-pattern
  (list
   `(,(regexp-opt
       '("nextword" "postpone" "call:" "xt"
         "CR"
         "'" "`" "@" "!"
         "2dup" "3dup" "2drop" "3drop"
         "+" "-" "*" "/" "%" "**"
         "1+" "1-" "-1*" "inc" "dec" "neg"
         "2+" "2-" "2*" "2/" "double" "halve"
         "5+" "5-" "5*" "5/"
         "10+" "10-" "10*" "10/"
         "100+" "100-" "100*" "100/" "percent"
         ">" "<" "=" ">=" "<=" "~="
         "greater?" "less?" "equal?" "greatereq?" "lesseq?" "noteq?"
         "and" "or" "nand" "nor" "xor"
         "copyright" "©"
         "NOOP") 'words)
     . firth-core-words)
   '("\\<.\"\\s-.*?\"\\>" . font-lock-string-face)) ; print string
  "Useful words from :Firth core library.")

;; Define some default groupings for syntax highlighting options.
;; Users of firth-mode may choose one of the below, or set their
;; own desired mix of highlighting patterns in their .emacs file.
(defconst firth-min-syntax-pattern
  (append
   firth-prims-pattern
   firth-consts-pattern)
  "Minimally useful syntax highlighting for :Firth")

(defconst firth-nicer-syntax-pattern
  (append
   firth-comments-pattern
   firth-min-syntax-pattern
   firth-agregate-literals-pattern)
  "Nicer syntax highlighting for :Firth with agregates and standard comments.")

(defconst firth-full-syntax-pattern
  (append
   firth-comments-pattern
   firth-definitions-pattern
   firth-consts-pattern
   firth-core-words-pattern
   firth-prims-pattern
   firth-agregate-literals-pattern)
  "Full syntax highlighting for :Firth, including defs and core lib.")

(defvar firth-font-lock-keywords-pattern firth-full-syntax-pattern
  "Default Highlighting Expression for :Firth Mode")

;; override how some characters are handled by emacs
(defvar firth-mode-syntax-table
  (let ((stab (make-syntax-table)))
    ;; mark typical "punctuation" chars as valid parts of words
    (modify-syntax-entry ?_ "w" stab)
    (modify-syntax-entry ?: "w" stab)
    (modify-syntax-entry ?; "w" stab)
    (modify-syntax-entry ?" "w" stab) ;"
    (modify-syntax-entry ?' "w" stab)
    (modify-syntax-entry ?. "w" stab)
    (modify-syntax-entry ?< "w" stab)
    (modify-syntax-entry ?> "w" stab)
    (modify-syntax-entry ?( "w" stab)
    (modify-syntax-entry ?) "w" stab)
    (modify-syntax-entry ?[ "w" stab)
    (modify-syntax-entry ?] "w" stab)
    (modify-syntax-entry ?{ "w" stab)
    (modify-syntax-entry ?} "w" stab)
    (modify-syntax-entry ?\\ "w" stab)
    (modify-syntax-entry ?+ "w" stab)
    (modify-syntax-entry ?- "w" stab)
    (modify-syntax-entry ?* "w" stab)
    (modify-syntax-entry ?/ "w" stab)
    (modify-syntax-entry ?% "w" stab)
    (modify-syntax-entry ?= "w" stab)
    (modify-syntax-entry ?~ "w" stab)
    (modify-syntax-entry ?& "w" stab)
    (modify-syntax-entry ?| "w" stab)
    (modify-syntax-entry ?^ "w" stab)
    (modify-syntax-entry ?! "w" stab)
    (modify-syntax-entry ?? "w" stab)
    (modify-syntax-entry ?@ "w" stab)
    (modify-syntax-entry ?© "w" stab)
    (modify-syntax-entry ?` "w" stab)

	;; define what comments look like
    ;; (modify-syntax-entry ?( "< n" stab)
    ;; (modify-syntax-entry ?) "> n" stab)
    ;; (modify-syntax-entry ?/ "< 12" stab)
    ;; (modify-syntax-entry ?\n "> " stab)

    stab)
  "Syntax Table for :Firth Mode")

;;; Indentation ;;;

;; TODO

;;; :Firth Mode Init and Entry ;;;

; let users hook loading firth mode
(defvar firth-mode-hook nil)

(defun firth-mode ()
  "Major Mode for Editing :Firth Files."
  (interactive)
  (kill-all-local-variables)
  (set-syntax-table firth-mode-syntax-table)
  (use-local-map firth-mode-map)
  (set (make-local-variable 'font-lock-defaults) '(firth-font-lock-keywords-pattern))
;  (set (make-local-variable 'indent-line-function) '(firth-indent-line))
  (setq major-mode 'firth-mode)
  (setq mode-name ":Firth")
  (run-hooks 'firth-mode-hook))

(provide 'firth-mode)
