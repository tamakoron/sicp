#|-*- mode:lisp -*-|#
#| <Put a one-line description here>
exec ros -Q -- $0 "$@"
|#
(in-package :cl-user)

(ql:quickload '(cl-ansi-text))

(defpackage :sicp4.repl
  (:use :cl :cl-ansi-text)
  (:shadow :eval :apply)
  (:export
   :*the-global-environment*
   :driver-loop))

(in-package :sicp4.repl)
(defvar apply-in-underlying-scheme (fdefinition 'cl:apply))

(defvar *the-empty-environment* '())
(defvar *primitive-procedures*
  (list (list 'car #'car)
        (list 'cdr #'cdr)
        (list 'cadr #'cadr) (list 'caar #'caar) (list 'cddr #'cadr)
        (list 'cons #'cons)
        (list 'null? #'null)
        (list 'print #'print)
        (list '+ #'+)
        (list '- #'-)
        (list '* #'*)
        (list '/ #'/)
        (list '= #'=)
        (list '< #'<)
        (list '> #'>)
        (list 'assoc #'assoc)
        (list 'list #'list)
        (list 'not #'not)
        ))

(defun -eq (exp tag)
  (when (symbolp exp)
    (string= exp tag)))

(defun set-car! (li x)
  (setf (car li) x))
(defun set-cdr! (li x)
  (setf (cdr li) x))

(defun self-evaluating? (exp)
  (cond ((numberp exp) t)
        ((stringp exp) t)
        (t nil)))

(defun variable?(exp) (symbolp exp))

(defun tagged-list? (exp tag)
  (if (consp exp)
      (-eq (car exp) tag)
      nil))

(defun quoted?(exp)
  (tagged-list? exp 'quote))

(defun assignment? (exp)
  (tagged-list? exp 'set!))

(defun definition? (exp)
  (tagged-list? exp 'define))

(defun if? (exp) (tagged-list? exp 'if))

(defun lambda? (exp) (tagged-list? exp 'lambda))

(defun begin? (exp) (tagged-list? exp 'begin))

(defun cond? (exp) (tagged-list? exp 'cond))

(defun application? (exp) (consp exp))

(defun primitive-procedure? (proc)
  (tagged-list? proc 'primitive))

(defun primitive-implementation (proc) (cadr proc))

(defun apply-primitive-procedure (proc args)
  (funcall apply-in-underlying-scheme
           (primitive-implementation proc) args))

(defun procedure-body (p) (caddr p))

(defun make-frame (variables values)
  (cons variables values))

(defun extend-environment (vars vals base-env)
  (if (= (length vars) (length vals))
      (cons (make-frame vars vals) base-env)
      (if (< (length vars) (length vals))
          (error "Too many arguments supplied ~S ~S" vars vals)
          (error "Too few arguments supplied ~S ~S" vars vals))))

(defun compound-procedure? (p)
  (tagged-list? p 'procedure))

(defun procedure-parameters (p) (cadr p))

(defun procedure-environment (p) (cadddr p))

(defun enclosing-environment (env) (cdr env))

(defun first-frame (env) (car env))

(defun frame-variables (frame) (car frame))

(defun frame-values (frame) (cdr frame))

(defun apply (procedure arguments)
  (cond ((primitive-procedure? procedure)
         (apply-primitive-procedure procedure arguments))
        ((compound-procedure? procedure)
         (eval-sequence
          (procedure-body procedure)
          (extend-environment
           (procedure-parameters procedure)
           arguments
           (procedure-environment procedure))))
        (t
         (error
          "Unknown procedure type -- APPLY ~S" procedure))))

(defun begin-actions (exp) (cdr exp))

(defun eval (exp env)
  (cond ((self-evaluating? exp) exp)
        ((variable? exp) (lookup-variable-value exp env))
        ((quoted? exp) (text-of-quotation exp))
        ((assignment? exp) (eval-assignment exp env))
        ((definition? exp) (eval-definition exp env))
        ((if? exp) (eval-if exp env))
        ((lambda? exp)
         (make-procedure (lambda-parameters exp)
                         (lambda-body exp)
                         env))
        ((begin? exp)
         (eval-sequence (begin-actions exp) env))
        ((cond? exp) (eval (cond->if exp) env))
        ((application? exp)
         (apply (eval (operator exp) env)
                (list-of-values (operands exp) env)))
        (t
         (error "Unknown expression type -- EVAL ~S" exp))))

(defun eval-sequence (exps env)
  (cond ((last-exp? exps) (eval (first-exp exps) env))
        (t (eval (first-exp exps) env)
           (eval-sequence (rest-exps exps) env))))

(defun list-of-values (exps env)
  (if (no-operands? exps)
      '()
      (cons (eval (first-operand exps) env)
            (list-of-values (rest-operands exps) env))))

(defun eval-if (exp env)
  (if (true? (eval (if-predicate exp) env))
      (eval (if-consequent exp) env)
      (eval (if-alternative exp) env)))

(defun eval-assignment (exp env)
  (set-variable-value! (assignment-variable exp)
                       (eval (assignment-value exp) env)
                       env)
  'ok)

(defun eval-definition (exp env)
  (define-variable! (definition-variable exp)
      (eval (definition-value exp) env)
    env)
  'ok)

(defun text-of-quotation (exp) (cadr exp))

(defun assignment-variable (exp) (cadr exp))

(defun assignment-value (exp) (caddr exp))

(defun definition-variable (exp)
  (if (symbolp (cadr exp))
      (cadr exp)
      (caadr exp)))

(defun definition-value (exp)
  (if (symbolp (cadr exp))
      (caddr exp)
      (make-lambda (cdadr exp)   ; 仮パラメタ
                   (cddr exp)))) ; 本体

(defun lambda-parameters (exp) (cadr exp))

(defun lambda-body (exp) (cddr exp))

(defun make-lambda (parameters body)
  (cons 'lambda (cons parameters body)))

(defun if-predicate (exp) (cadr exp))

(defun if-consequent (exp) (caddr exp))

(defun if-alternative (exp)
  (if (not (null (cdddr exp)))
      (cadddr exp)
      'false))

(defun make-if (predicate consequent alternative)
  (list 'if predicate consequent alternative))

(defun last-exp? (seq) (null (cdr seq)))

(defun first-exp (seq) (car seq))

(defun rest-exps (seq) (cdr seq))

(defun sequence->exp (seq)
  (cond ((null seq) seq)
        ((last-exp? seq) (first-exp seq))
        (t (make-begin seq))))

(defun make-begin (seq) (cons 'begin seq))

(defun operator (exp) (car exp))

(defun operands (exp) (cdr exp))

(defun no-operands? (ops) (null ops))

(defun first-operand (ops) (car ops))

(defun rest-operands (ops) (cdr ops))

(defun cond-clauses (exp) (cdr exp))

(defun cond-else-clause? (clause)
  (-eq (cond-predicate clause) 'else))

(defun cond-predicate (clause) (car clause))

(defun cond-actions (clause) (cdr clause))

(defun cond->if (exp)
  (expand-clauses (cond-clauses exp)))

(defun expand-clauses (clauses)
  (if (null clauses)
      'false                          ; else節なし
      (let ((first (car clauses))
            (rest (cdr clauses)))
        (if (cond-else-clause? first)
            (if (null rest)
                (sequence->exp (cond-actions first))
                (error "ELSE clause isn't last -- COND->IF ~S"
                       clauses))
            (make-if (cond-predicate first)
                     (sequence->exp (cond-actions first))
                     (expand-clauses rest))))))

(defun true? (x)
  (not (eq x nil)))

(defun false? (x)
  (eq x nil))

(defun make-procedure (parameters body env)
  (list 'procedure parameters body env))

(defun add-binding-to-frame! (var val frame)
  (set-car! frame (cons var (car frame)))
  (set-cdr! frame (cons val (cdr frame))))

(defun lookup-variable-value (var env)
  (labels ((env-loop (env)
             (labels ((scan (vars vals)
                        (cond ((null vars)
                               (env-loop (enclosing-environment env)))
                              ((-eq var (car vars))
                               (car vals))
                              (t (scan (cdr vars) (cdr vals))))))
               (if (eq env *the-empty-environment*)
                   (error "Unbound variable ~S" var)
                   (let ((frame (first-frame env)))
                     (scan (frame-variables frame)
                           (frame-values frame)))))))
    (env-loop env)))

(defun set-variable-value! (var val env)
  (labels ((env-loop (env)
             (labels ((scan (vars vals)
                        (cond ((null vars)
                               (env-loop (enclosing-environment env)))
                              ((eq var (car vars))
                               (set-car! vals val))
                              (t (scan (cdr vars) (cdr vals))))))
               (if (eq env *the-empty-environment*)
                   (error "Unbound variable -- SET! ~S" var)
                   (let ((frame (first-frame env)))
                     (scan (frame-variables frame)
                           (frame-values frame)))))))
    (env-loop env)))

(defun define-variable! (var val env)
  (let ((frame (first-frame env)))
    (labels ((scan (vars vals)
               (cond ((null vars)
                      (add-binding-to-frame! var val frame))
                     ((eq var (car vars))
                      (set-car! vals val))
                     (t (scan (cdr vars) (cdr vals))))))
      (scan (frame-variables frame)
            (frame-values frame)))))

(defun primitive-procedure-objects()
  (mapcar (lambda (proc) (list 'primitive (cadr proc)))
          *primitive-procedures*))

(defun setup-environment()
  (let ((initial-env
          (extend-environment (funcall #'primitive-procedure-names)
                              (funcall #'primitive-procedure-objects)
                              *the-empty-environment*)))
    (define-variable! 'true t initial-env)
    (define-variable! 'false nil initial-env)
    initial-env))

(defun primitive-procedure-names()
  (mapcar #'car
          *primitive-procedures*))

(defvar input-prompt ";;; M-Eval input:")
(defvar output-prompt ";;; M-Eval value:")

(defun input-debug-print (obj)
  (let ((str (format nil "~s" obj)))
    (let ((len (length str))
          (s (make-array '(0)
                         :element-type 'base-char
                         :fill-pointer 0
                         :adjustable t)))
      (with-output-to-string (sb s)
        (flet ((print->> ()
                 (format sb "~&~a>>>>:~a"
                         (CL-ANSI-TEXT:MAKE-COLOR-STRING #x666666 :EFFECT :UNSET :STYLE
                                                                          :FOREGROUND)
                         (CL-ANSI-TEXT:MAKE-COLOR-STRING #xFF8888 :EFFECT :UNSET :STYLE
                                                                          :FOREGROUND))))
          (labels ((iter (i)
                     (when (< i len)
                       (let ((ch (char str i)))
                         (format sb "~c" ch)
                         (when (char= ch #\newline)
                           (print->>))
                         (iter (1+ i))))))
            (print->>)
            (iter 0)))
        (format t "~&~a~a~%" s cl-ansi-text:+reset-color-string+)))))


(defun prompt-for-input (string)
  (format t "~%~a~a~a~%"  (make-color-string :yellow) string +RESET-COLOR-STRING+))

(defun announce-output (string)
  (format t "~&~a~a~a~%"  (make-color-string :blue) string +RESET-COLOR-STRING+))

(defun user-print (object)
  (cl-ansi-text:with-color (:green)
    (if (compound-procedure? object)
        (format t "~a" (list 'compound-procedure
                             (procedure-parameters object)
                             (procedure-body object)
                             '()))
        (format t "~a" object))))

(defvar *the-global-environment* (setup-environment))

(defun driver-loop (&optional (input-stream *standard-input*))
  (prompt-for-input input-prompt)
  (let ((input (read input-stream nil :eof)))
    (unless (eq :eof input)
      (input-debug-print input)
      (let ((output (eval input *the-global-environment*)))
        (announce-output output-prompt)
        (user-print output))
      (driver-loop input-stream))))
