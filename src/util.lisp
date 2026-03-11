;;;; cl-oracle/util.lisp - Utility functions
;;;; Common helpers for the oracle framework

(in-package #:cl-oracle)

;;; ============================================================================
;;; Time Utilities
;;; ============================================================================

(defun current-timestamp ()
  "Get current Unix-style timestamp."
  (get-universal-time))

(defun timestamp-age (timestamp)
  "Get age of timestamp in seconds."
  (- (current-timestamp) timestamp))

;;; ============================================================================
;;; Numeric Utilities
;;; ============================================================================

(defun ensure-double (x)
  "Coerce number to double-float."
  (coerce x 'double-float))

(defun safe-divide (numerator denominator &optional (default 0.0d0))
  "Safe division returning default if denominator is zero."
  (if (zerop denominator)
      default
      (/ numerator denominator)))

(defun clamp (value min-val max-val)
  "Clamp value to [min-val, max-val] range."
  (max min-val (min max-val value)))

;;; ============================================================================
;;; List Utilities
;;; ============================================================================

(defun take (n list)
  "Take first N elements from list."
  (subseq list 0 (min n (length list))))

(defun sorted-copy (list predicate &key key)
  "Return a sorted copy of list."
  (sort (copy-list list) predicate :key key))
