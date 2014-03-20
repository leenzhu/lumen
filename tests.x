;; -*- mode: lisp -*-

;; infrastructure

(define passed 0)
(define failed 0)
(define tests ())

(define-macro test (x msg)
  `(if (not ,x)
       (do (set! failed (+ failed 1))
	   (return ,msg))
     (set! passed (+ passed 1))))

(define equal? (a b)
  (if (atom? a)
      (= a b)
    (= (to-string a) (to-string b))))

(define-macro test= (a b)
  `(test (equal? ,a ,b)
	 (cat " failed: expected " (to-string ,a) ", was " (to-string ,b))))

(define-macro define-test (name _ body...)
  `(push! tests (list ',name (fn () ,@body))))

(define run-tests ()
  (across (tests test)
    (let (name (at test 0)
	  f (at test 1)
	  result (f))
      (if (string? result)
	  (pr  " " name result))))
  (pr passed " passed, " failed " failed"))

;; basic

(define-test reader ()
  (test= 17 (read-from-string "17"))
  (test= 0.015 (read-from-string "1.5e-2"))
  (test= true (read-from-string "true"))
  (test= (not true) (read-from-string "false"))
  (test= 'hi (read-from-string "hi"))
  (test= '"hi" (read-from-string "\"hi\""))
  (test= '(1 2) (read-from-string "(1 2)"))
  (test= '(1 (a)) (read-from-string "(1 (a))"))
  (test= '(quote a) (read-from-string "'a"))
  (test= '(quasiquote a) (read-from-string "`a"))
  (test= '(quasiquote (unquote a)) (read-from-string "`,a"))
  (test= '(quasiquote (unquote-splicing a)) (read-from-string "`,@a"))
  (test= true (key? "foo:"))
  (test= false (key? "foo:a"))
  (test= false (key? ":a"))
  (test= false (key? ":"))
  (test= false (key? ""))
  (test= '(1 2) (read-from-string "(1 2 a: 7)"))
  (test= 7 (get (read-from-string "(1 2 a: 7)") 'a)))

(define-test boolean ()
  (test= true (or true false))
  (test= false (or false false))
  (test= true (not false))
  (test= true (and true true))
  (test= false (and true false))
  (test= false (and true true false)))

(define-test numeric ()
  (test= 4 (+ 2 2))
  (test= 18 18.00)
  (test= 4 (- 7 3))
  (test= 5.0 (/ 10 2))
  (test= 6 (* 2 3.00))
  (test= true (> 2.01 2))
  (test= true (>= 5.0 5.0))
  (test= false (< 2 2))
  (test= true (<= 2 2))
  (test= -7 (- 7)))

(define-test string ()
  (test= 3 (length "foo"))
  (test= 3 (length "\"a\""))
  (test= 'a "a")
  (test= "a" (char "bar" 1)))

(define-test quote ()
  (test= 7 (quote 7))
  (test= true (quote true))
  (test= false (quote false))
  (test= (quote a) 'a)
  (test= (quote (quote a)) ''a)
  (test= "\"a\"" '"a")
  (test= '(quote "a") ''"a")
  (test= (quote unquote) 'unquote)
  (test= (quote (unquote)) '(unquote))
  (test= (quote (unquote a)) '(unquote a)))

(define-test list ()
  (test= '() (list))
  (test= () (list))
  (test= '(a) (list 'a))
  (test= '(a) (quote (a)))
  (test= '(()) (list (list)))
  (test= 0 (length (list)))
  (test= 2 (length (list 1 2))))

(define-test quasiquote ()
  (test= (quote a) (quasiquote a))
  (test= 'a `a)
  (test= '() `())
  (test= () `())
  (test= 2 `,2)
  (let (a 42)
    (test= 42 `,a)
    (test= 42 (quasiquote (unquote a)))
    (test= '(quasiquote (unquote a)) ``,a)
    (test= '(quasiquote (unquote 42)) ``,,a)
    (test= '(quasiquote (quasiquote (unquote (unquote a)))) ```,,a)
    (test= '(quasiquote (quasiquote (unquote (unquote 42)))) ```,,,a)
    (test= '(a (quasiquote (b (unquote c)))) `(a `(b ,c)))
    (test= '(a (quasiquote (b (unquote 42)))) `(a `(b ,,a)))
    (let (b 'c)
      (test= '(quote c) `',b)
      (test= '(42) `(,a))
      (test= '((42)) `((,a)))
      (test= '(41 (42)) `(41 (,a)))))
  (let (c '(1 2 3))
    (test= '((1 2 3)) `(,c))
    (test= '(1 2 3) `(,@c))
    (test= '(0 1 2 3) `(0 ,@c))
    (test= '(0 1 2 3 4) `(0 ,@c 4))
    (test= '(0 (1 2 3) 4) `(0 (,@c) 4))
    (test= '(1 2 3 1 2 3) `(,@c ,@c))
    (test= '((1 2 3) 1 2 3) `((,@c) ,@c)))
  (let (a 42)
    (test= '(quasiquote ((unquote-splicing (list a)))) ``(,@(list a)))
    (test= '(quasiquote ((unquote-splicing (list 42)))) ``(,@(list ,a)))))

(define-test calls ()
  (let (f (fn () 42)
	l (list f)
	t (table f f))
    (test= 42 (f))
    (test= 42 ((at l 0)))
    (test= 42 (t.f))
    (test= 42 ((get t 'f)))))

(define-test quasiexpand ()
  (test= 'a (macroexpand 'a))
  (test= '(17) (macroexpand '(17)))
  (test= '(1 z) (macroexpand '(1 z)))
  (test= '(list '1 'z) (macroexpand '`(1 z)))
  (test= '(list 1 z) (macroexpand '`(,1 ,z)))
  (test= 'z (macroexpand '`(,@z)))
  (test= '(join (list 1) z) (macroexpand '`(,1 ,@z)))
  (test= '(join (list 1) (join x y)) (macroexpand '`(,1 ,@x ,@y)))
  (test= '(join (list 1) (join z (list 2))) (macroexpand '`(,1 ,@z ,2)))
  (test= '(join (list 1) (join z (list 'a))) (macroexpand '`(,1 ,@z a)))
  (test= '(quote x) (macroexpand '`x))
  (test= '(list 'quasiquote 'x) (macroexpand '``x))
  (test= '(list 'quasiquote (list 'quasiquote 'x)) (macroexpand '```x))
  (test= 'x (macroexpand '`,x))
  (test= '(list 'quote x) (macroexpand '`',x))
  (test= '(list 'quasiquote (list 'x)) (macroexpand '``(x)))
  (test= '(list 'quasiquote (list 'unquote 'a)) (macroexpand '``,a))
  (test= '(list 'quasiquote (list (list 'unquote 'x))) (macroexpand '``(,x))))

;; special forms

(define-test local ()
  (local a 42)
  (test= 42 a))

(define-test set! ()
  (let (a 42)
    (set! a 'bar)
    (test= 'bar a)))

(define-test do ()
  (let (a 17)
    (do (set! a 10)
	(test= 10 a))
    ;; do cannot introduce a new scope
    (do (local a 7)
	(test= 7 a))
    (test= 7 a)))

(define-test if ()
  (if true
      (test= true true)
    (test= true false)))

(define-test while ()
  (let (i 0)
    (while (< i 10)
      (set! i (+ i 1)))
    (test= 10 i)))

(define-test table ()
  (test= (table a 10 b 20) (table a 10 b 20))
  (test= 10 (get (table a 10) 'a)))

(define-test get-set ()
  (let (t (table))
    (set! (get t 'foo) 'bar)
    (test= 'bar (get t 'foo))
    (test= 'bar (get t "foo"))
    (let (k 'foo)
      (test= 'bar (get t k)))
    (test= 'bar (get t (cat "f" "oo")))))

(define-test each ()
  (let (a "" b 0)
    (each ((table a 10 b 20 c 30) k v)
      (cat! a k)
      (set! b (+ b v)))
    (test= 3 (length a))
    (test= 60 b)))

(define-test fn ()
  (let (f (fn (n) (+ n 10)))
    (test= 20 (f 10))
    (test= 30 (f 20))
    (test= 40 ((fn (n) (+ n 10)) 30))))

;; macros

(define-test let ()
  (let (a 10)
    (test= 10 a))
  (let (a 11
	b 12)
    (test= 11 a)
    (test= 12 b))
  (let (a 1)
    (test= 1 a)
    (let (a 2)
      (test= 2 a))
    (test= 1 a))
  ((fn (zz)
     (test= 20 zz)
     (let (zz 21)
       (test= 21 zz))
     (test= 20 zz))
   20))

(define-test destructuring-let ()
  (let ((a b c) '(1 2 3))
    (test= 1 a)
    (test= 2 b)
    (test= 3 c))
  (let ((_ b) '(1 2))
    (test= 2 b))
  (let ((w (x (y) z)) '(1 (2 (3) 4)))
    (test= 1 w)
    (test= 2 x)
    (test= 3 y)
    (test= 4 z))
  (let ((a b c...) '(1 2 3 4))
    (test= '(3 4) c))
  (let ((w (x y...) z...) '(1 (2 3 4) 5 6 7))
    (test= '(3 4) y)
    (test= '(5 6 7) z)))

(define-test let-macro ()
  (let-macro ((a () 17)
	      (b (a) `(+ ,a 10)))
    (test= 17 (a))
    (test= 42 (b 32))
    (let-macro ((a () 1))
      (test= 1 (a)))
    (test= 17 (a)))
  (let-macro ((a () 18))
    (let (b (fn () 20))
      (test= 18 (a))
      (test= 20 (b)))))

(define-test let-symbol ()
  (let-symbol ((a 17)
	       (b (+ 10 7)))
    (test= 17 a)
    (test= 17 b)
    (let-symbol ((a 1))
      (test= 1 a))
    (test= 17 a))
  (let-symbol ((a 18))
    (let (b 20)
      (test= 18 a)
      (test= 20 b))))

(define-test macros-and-symbol-macros ()
  (let-symbol ((a 1))
    (let-macro ((a () 2))
      (test= 2 (a)))
    (test= 1 a))
  (let-macro ((a () 2))
    (let-symbol ((a 1))
      (test= 1 a))
    (test= 2 (a))))

(define-test macros-and-let ()
  (let (a 10)
    (test= a 10)
    (let-macro ((a () 12))
      (test= 12 (a)))
    (test= a 10))
  (let (b 20)
    (test= b 20)
    (let-symbol ((b 22))
      (test= 22 b))
    (test= b 20))
  (let-macro ((c () 30))
    (test= 30 (c))
    (let (c 32)
      (test= 32 c))
    (test= 30 (c)))
  (let-symbol ((d 40))
    (test= 40 d)
    (let (d 42)
      (test= 42 d))
    (test= 40 d)))

;; expressions

(define-test if-expr ()
  (test= 10 (if true 10 20)))

(define-test set-expr ()
  (let (a 5)
    (test= nil (set! a 7))
    (test= 10 (do (set! a 10) a))))

(define-test local-expr ()
  (let (a 5)
    (test= 10 (do (local a 10) a))))

(define-test while-expr ()
  (let (i 0)
    (test= 10 (do (while (< i 10) (set! i (+ i 1))) i))))

(define-test each-expr ()
  (let (i 0 t (table a 10 b 20))
    (test= 2 (do (each (t _ _) (set! i (+ i 1))) i))))

;; library

(define-test push! ()
  (let (l ())
    (push! l 'a)
    (push! l 'b)
    (push! l 'c)
    (test= '(a b c) l)))

(define-test pop! ()
  (let (l '(a b c))
    (test= 'c (pop! l))
    (test= 'b (pop! l))
    (test= 'a (pop! l))
    (test= nil (pop! l))))

(define-test last ()
  (test= 3 (last '(1 2 3)))
  (test= nil (last ()))
  (test= 'c (last '(a b c))))

(define-test join ()
  (test= '(1 2 3) (join '(1 2) '(3)))
  (test= '(1 2) (join () '(1 2)))
  (test= () (join () ())))

(define-test map ()
  (test= '(1) (map (fn (x) x) '(1)))
  (test= '(2 3 4) (map (fn (x) (+ x 1)) '(1 2 3))))

(define-test sub ()
  (test= '(b c) (sub '(a b c) 1))
  (test= '(b c) (sub '(a b c d) 1 3))
  (test= "uux" (sub "quux" 1))
  (test= "uu" (sub "quux" 1 3))
  (test= "" (sub "quux" 5)))

(define-test search ()
  (test= 0 (search "abc" "a"))
  (test= 2 (search "abcd" "cd"))
  (test= nil (search "abc" "z")))

(define-test split ()
  (test= (list "a") (split "a" ","))
  (test= (list "a" "") (split "a," ","))
  (test= (list "a" "b") (split "a,b" ",")))

(define-test reduce ()
  (test= 6 (reduce (fn (a b) (+ a b)) '(1 2 3)))
  (test= '(1 (2 3))
	      (reduce
	       (fn (a b) (list a b))
	       '(1 2 3)))
  (test= '(1 2 3 4 5)
	      (reduce
	       (fn (a b) (join a b))
	       '((1) (2 3) (4 5)))))

(define-test list* ()
  (test= () (list*))
  (test= '(2 3) (list* '(2 3)))
  (test= '(1 2 3) (list* 1 '(2 3)))
  (let (a 17 b '(5))    
    (test= '(5) (list* b))
    (test= '(17 5) (list* a b))
    (test= '((5) 5) (list* b b))))

(define-test type ()
  (test= true (string? "abc"))
  (test= false (string? 17))
  (test= false (string? '(a)))
  (test= false (string? true))
  (test= false (string? (table)))
  (test= false (number? "abc"))
  (test= true (number? 17))
  (test= false (number? '(a)))
  (test= false (number? true))
  (test= false (number? (table)))
  (test= false (boolean? "abc"))
  (test= false (boolean? 17))
  (test= false (boolean? '(a)))
  (test= true (boolean? true))
  (test= false (boolean? (table)))
  (test= false (function? 17))
  (test= false (function? "foo"))
  (test= false (function? '(a)))
  (test= false (function? (table)))
  (test= true (function? (fn () 17)))
  (test= false (list? "abc"))
  (test= false (list? 17))
  (test= true (list? '(a)))
  (test= false (list? true))
  (test= false (list? (table)))
  (test= false (table? "abc"))
  (test= false (table? 17))
  (test= false (table? '(a)))
  (test= false (table? true))
  (test= true (table? (table))))

(define-test apply ()
  (test= 4 (apply (fn (a b) (+ a b)) '(2 2)))
  (test= '(2 2) (apply (fn (a...) a) '(2 2))))

(define-test eval ()
  (let (f (fn (x) (eval (compile (macroexpand x)))))
    (test= 4 (f '(+ 2 2)))
    (test= 5 (f '(let (a 3) (+ 2 a))))))

(define-test parameters ()
  (let (f (fn (a (b c)) (list a b c)))
    (test= '(1 2 3) (f 1 '(2 3)))
    (set! f (fn (a (b c...) d...) (list a b c d)))
    (test= '(1 2 (3 4) (5 6 7)) (f 1 '(2 3 4) 5 6 7))
    (test= '(3 4) ((fn (a b c...) c) 1 2 3 4))
    (test= '((3 4) (5 6 7))
           ((fn (w (x y...) z...) (list y z))
            1 '(2 3 4) 5 6 7))))
