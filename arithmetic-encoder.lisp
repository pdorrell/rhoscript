;;;; arithmetic-encoder.lisp -- an arithmetic encoder for rhoScript

;;;; Copyright (C) 2013, Nicholas Carlini <nicholas@carlini.com>.
;;;;
;;;; This file is part of rhoScript.
;;;;
;;;; rhoScript is free software: you can redistribute it and/or modify
;;;; it under the terms of the GNU General Public License as published by
;;;; the Free Software Foundation, either version 3 of the License, or
;;;; (at your option) any later version.
;;;;
;;;; rhoScript is distributed in the hope that it will be useful,
;;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;;; GNU General Public License for more details.
;;;;
;;;; You should have received a copy of the GNU General Public License
;;;; along with rhoScript.  If not, see <http://www.gnu.org/licenses/>.

(defun point-in-range (point low high)
  (and
   (>= point low)
   (< point high)))

(defun point-in-range-o (point low high)
  (and
   (>= point low)
   (<= point high)))

(defun arithmetic-encode (symbols weighted-possibles)
  (labels ((pick-point-in (low high)
;	     (format t "pick in ~a ~a~%" low high)
	     (assert (< low high))
	     (let ((point (/ 1 2))
		   (step (/ 1 2))
		   (midpoint (/ (+ low high) 2))
		   (emit nil))
	       (loop while (not (and (point-in-range-o (+ point step) low high)
				     (point-in-range-o (- point step) low high)))  do

;		    (print (point-in-range midpoint point (+ point step)))

		    (if (point-in-range midpoint point (+ point step))
			(progn
			  (setf point (+ point (/ step 2)))
			  (push 1 emit))
			(if (point-in-range midpoint (- point step) point)
			    (progn
			      (setf point (- point (/ step 2)))
			      (push 0 emit))
			    (error "out of range?")))
		    (setf step (/ step 2)))
	       emit)))
;    (print "setup done")
  (let ((low 0)
	(high 1))
    (loop for element in symbols for weighted-possible in weighted-possibles do
;	 (print 'iter)
;	 (print element)
;	 (print weighted-possible)
;	 (print (assoc element weighted-possible :test 'equalp))
	 (assert (< low high))
	 (let ((total-weight 0) (lower-weight 0) (this-weight 0))
	   (if (eq (car weighted-possible) :geometric-mode)
	       (let ((geometric-value (second weighted-possible)))
		 (setf total-weight (/ 1 (- 1 geometric-value)))
		 (setf lower-weight (/ (- (expt geometric-value element) 1) 
				       (- geometric-value 1)))
		 (setf this-weight (expt geometric-value element)))
	       (progn
		 (setf total-weight (loop for el in weighted-possible sum (cadr el)))
		 (setf lower-weight (loop for el in weighted-possible 
				      while (not (equalp (car el) element))
				      sum (cadr el)))
		 (setf this-weight (cadr (assoc element weighted-possible :test 'equalp)))))
;	   (print element)
	   (assert (numberp this-weight))
	   (assert (> this-weight 0))
;	   (format t "~%ENCODE WEIGHTS ~a, ~a and ~a~%" total-weight lower-weight this-weight)
	   
	   (let* ((distance-outer (- high low))
		  (new-low-offset (* (/ lower-weight total-weight) distance-outer))
		  (new-high-offset (* (/ this-weight total-weight) distance-outer)))
;	     (format t "~a ~a ~a~%" distance-outer new-low-offset new-high-offset)
;	     (print "sdf")
	     (setf low (+ low new-low-offset))
	     (setf high (+ low new-high-offset)))))
;	     (format t "~%After ~a we have ~a ~a." element low high))))
;    (print "done step 1")
    (pick-point-in low high))))

(defun arithmetic-decode-preprocess (number)
  (let ((real-number 0)
	(step (/ 1 2)))
    (loop for el in (reverse number) do
	 (if (= el 1)
	     (setf real-number (+ real-number step)))
	 (setf step (/ step 2)))
    (setf real-number (+ real-number step))
    real-number))
    
(defun arithmetic-decode (number weighted-possible)
  (let ((total-weight 0)
	(it 0) (sumsofar 0)
	(decoding nil)
	(splitfactor 0))
    (if (eq (car weighted-possible) :geometric-mode)
	(let* ((geometric-value 1)
	       (base-geometric-value (second weighted-possible)))
	  (setf total-weight (/ 1 (- 1 base-geometric-value)))
;	  (print total-weight)
	  (loop while (< (/ sumsofar total-weight) number) do
;	       (format t "tick ~a ~a ~a~%" (+ .0 (/ sumsofar total-weight)) it number)
	       (setf sumsofar (+ sumsofar geometric-value))
	       (incf it)
	       (setf geometric-value (* geometric-value base-geometric-value)))
	  (setf decoding (list (1- it)))
;	  (print (list 'qqq sumsofar geometric-value))
;	  (format t "number now ~a" number)
	  (setf number (- number (/ (- sumsofar (/ geometric-value base-geometric-value))
				       total-weight)))
;	  (format t "number then ~a" number)
	  (setf splitfactor (/ (/ geometric-value base-geometric-value) total-weight))
	  (setf number (/ number splitfactor)))
;	  (format t "number finally ~a" number))
	(progn
	  (setf total-weight (loop for el in weighted-possible sum (cadr el)))
	  (loop
	     for el in weighted-possible 
	     while (< sumsofar number) do
	       (setf sumsofar (+ sumsofar (/ (cadr el) total-weight)))
	       (incf it))
	  (setf decoding (nth (1- it) weighted-possible))
;	  (format t "~%Decoded to ~a" decoding)
;	  (format t "number now ~a" number)
	  (setf number (- number 
			  (- sumsofar (/ (cadr decoding) total-weight))))
;	  (format t " number then ~a" number)
	  (setf splitfactor (/ (cadr decoding) total-weight))
	  (setf number (/ number splitfactor))))
;	  (format t "number finally ~a~%" number)))
      (list number splitfactor (car decoding))))

(defun arithmetic-decode-loop (number weighted-possible)
  (let* ((elt (arithmetic-decode number weighted-possible))
	 (number (car elt))
	 (res (cdr elt)))
    (if (not (eq res (caar (last weighted-possible))))
	(cons res (arithmetic-decode-loop number weighted-possible))
	(list res))))

(defun arithmetic-extract-n-bits (input length)
  (let ((resulting-bits nil))
    (loop for i from 1 to length do
	 (let* ((next-token (uncompress-once-from input '((0 1) (1 1)))))
	   (use-up-data input)
	   (push next-token resulting-bits)))
    (reverse resulting-bits)))

;flb: 
;     2 3 4 5 6
(defun find-lower-bound (int)
  (let ((x 0) (step 2))
    (loop while (<= (+ x (expt 2 step)) int) do
	 (setf x (+ x (expt 2 step)))
	 (incf step))
    (values step x)))

(defun arithmetic-encode-integer (int)
  (labels ((get-bits (num)
	     (if (eq num 0) nil
		 (cons (if (oddp num) 1 0) (get-bits (floor (/ num 2))))))
	   (pad (int n)
	     (if (< (length int) n)
		 (pad (append int '(0)) n)
		 int)))
    (multiple-value-bind (steps bound) (find-lower-bound int)
      (values (- steps 2) (pad (get-bits (- int bound)) steps)))))

(defun arithmetic-decode-integer (bits)
  (+
   (reduce (lambda (a b) (+ (* a 2) b))
	   (reverse bits) 
	   :initial-value 0)
   (loop for i from 2 to (1- (length bits)) sum (expt 2 i))))

(defclass compressed-data nil
    ((data :accessor get-compressed-data :initarg :data)
     (remaining :accessor get-remaining :initarg :remaining)
     (next-data :accessor get-next-data :initform nil)
     (next-size :accessor get-next-size :initform 0)))

(defmethod make-compressed-data (data)
  (make-instance 'compressed-data 
		 :data (arithmetic-decode-preprocess data)
		 :remaining (expt 2 (length data))))

(defmethod uncompress-once-from ((comp compressed-data) weights)
  (let ((decdata (arithmetic-decode (get-compressed-data comp) weights)))
    (setf (get-next-data comp) (first decdata))
    (setf (get-next-size comp) (second decdata))
    (third decdata)))

(defmethod use-up-data ((comp compressed-data))
  (setf (get-compressed-data comp) (get-next-data comp))
  (setf (get-remaining comp) (* (get-remaining comp) (get-next-size comp))))

; Mathematically provably safe when no item takes more than 1/2 of the total space.
(defmethod has-more-data ((comp compressed-data))
  (< 3.33 (log (get-remaining comp) 2)))


