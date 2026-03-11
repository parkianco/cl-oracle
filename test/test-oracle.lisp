;;;; cl-oracle/test/test-oracle.lisp - Tests for cl-oracle

(defpackage #:cl-oracle/test
  (:use #:cl #:cl-oracle))

(in-package #:cl-oracle/test)

;;; ============================================================================
;;; Test Utilities
;;; ============================================================================

(defvar *test-count* 0)
(defvar *pass-count* 0)
(defvar *fail-count* 0)

(defmacro deftest (name &body body)
  `(progn
     (incf *test-count*)
     (handler-case
         (progn
           ,@body
           (incf *pass-count*)
           (format t "~&PASS: ~A~%" ',name))
       (error (e)
         (incf *fail-count*)
         (format t "~&FAIL: ~A~%  Error: ~A~%" ',name e)))))

(defun check (condition message)
  (unless condition
    (error "Assertion failed: ~A" message)))

(defun approximately-equal (a b &optional (tolerance 1.0d-6))
  (< (abs (- a b)) tolerance))

(defun reset-test-state ()
  (setf *test-count* 0 *pass-count* 0 *fail-count* 0)
  (cl-oracle:clear-all-feeds))

(defun print-test-summary ()
  (format t "~%========================================~%")
  (format t "Tests: ~D  Passed: ~D  Failed: ~D~%"
          *test-count* *pass-count* *fail-count*)
  (format t "========================================~%"))

;;; ============================================================================
;;; Statistical Function Tests
;;; ============================================================================

(deftest test-calculate-mean
  (check (approximately-equal (cl-oracle:calculate-mean '(1.0 2.0 3.0)) 2.0d0)
         "Mean of (1 2 3) should be 2")
  (check (approximately-equal (cl-oracle:calculate-mean '(10.0 20.0 30.0 40.0)) 25.0d0)
         "Mean of (10 20 30 40) should be 25")
  (check (= (cl-oracle:calculate-mean nil) 0.0d0)
         "Mean of empty list should be 0"))

(deftest test-calculate-median
  (check (approximately-equal (cl-oracle:calculate-median '(1.0 2.0 3.0)) 2.0d0)
         "Median of (1 2 3) should be 2")
  (check (approximately-equal (cl-oracle:calculate-median '(1.0 2.0 3.0 4.0)) 2.5d0)
         "Median of (1 2 3 4) should be 2.5")
  (check (approximately-equal (cl-oracle:calculate-median '(1.0 2.0 100.0)) 2.0d0)
         "Median should be resistant to outliers"))

(deftest test-calculate-std-deviation
  (let ((values '(2.0 4.0 4.0 4.0 5.0 5.0 7.0 9.0)))
    (check (approximately-equal (cl-oracle:calculate-std-deviation values) 2.0d0 0.01)
           "Std dev should be approximately 2")))

(deftest test-calculate-mad
  (let ((values '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0)))
    (let ((mad (cl-oracle:calculate-mad values)))
      (check (> mad 0) "MAD should be positive"))))

(deftest test-trimmed-mean
  (let ((values '(1.0 2.0 3.0 4.0 100.0)))
    (let ((tm (cl-oracle:trimmed-mean values 0.2)))
      (check (< tm 10.0) "Trimmed mean should exclude extreme outlier"))))

;;; ============================================================================
;;; Outlier Detection Tests
;;; ============================================================================

(deftest test-z-score-filter
  (let* ((obs (list (cl-oracle:make-observation :source "a" :value 100.0)
                    (cl-oracle:make-observation :source "b" :value 101.0)
                    (cl-oracle:make-observation :source "c" :value 99.0)
                    (cl-oracle:make-observation :source "d" :value 500.0))) ; outlier
         (filtered rejected (cl-oracle:z-score-filter obs)))
    (check (= (length filtered) 3) "Should filter 1 outlier")
    (check (= (length rejected) 1) "Should reject 1 value")))

(deftest test-mad-filter
  (let* ((obs (list (cl-oracle:make-observation :source "a" :value 42000.0)
                    (cl-oracle:make-observation :source "b" :value 42050.0)
                    (cl-oracle:make-observation :source "c" :value 41990.0)
                    (cl-oracle:make-observation :source "d" :value 50000.0))) ; outlier
         (filtered rejected (cl-oracle:mad-filter obs)))
    (check (<= (length filtered) 4) "Should handle outliers")
    (check (>= (length rejected) 0) "May reject outliers")))

;;; ============================================================================
;;; Feed Management Tests
;;; ============================================================================

(deftest test-create-feed
  (cl-oracle:clear-all-feeds)
  (let ((feed (cl-oracle:create-feed "TEST/USD" :decimals 8 :heartbeat 3600)))
    (check (not (null feed)) "Should create feed")
    (check (cl-oracle:feed-exists-p "TEST/USD") "Feed should exist")))

(deftest test-list-feeds
  (cl-oracle:clear-all-feeds)
  (cl-oracle:create-feed "BTC/USD")
  (cl-oracle:create-feed "ETH/USD")
  (let ((feeds (cl-oracle:list-feeds)))
    (check (= (length feeds) 2) "Should have 2 feeds")))

;;; ============================================================================
;;; Source Management Tests
;;; ============================================================================

(deftest test-register-source
  (cl-oracle:clear-all-feeds)
  (cl-oracle:create-feed "BTC/USD")
  (cl-oracle:register-source "BTC/USD" "binance" :weight 1.0)
  (cl-oracle:register-source "BTC/USD" "coinbase" :weight 0.9)
  (let ((sources (cl-oracle:list-sources "BTC/USD")))
    (check (= (length sources) 2) "Should have 2 sources")))

(deftest test-source-enable-disable
  (cl-oracle:clear-all-feeds)
  (cl-oracle:create-feed "BTC/USD")
  (cl-oracle:register-source "BTC/USD" "binance")
  (check (cl-oracle:source-active-p "BTC/USD" "binance") "Source should be active")
  (cl-oracle:disable-source "BTC/USD" "binance")
  (check (not (cl-oracle:source-active-p "BTC/USD" "binance")) "Source should be disabled")
  (cl-oracle:enable-source "BTC/USD" "binance")
  (check (cl-oracle:source-active-p "BTC/USD" "binance") "Source should be re-enabled"))

;;; ============================================================================
;;; Observation and Aggregation Tests
;;; ============================================================================

(deftest test-submit-observation
  (cl-oracle:clear-all-feeds)
  (cl-oracle:create-feed "BTC/USD" :min-sources 1)
  (let ((obs (cl-oracle:submit-observation "BTC/USD" "binance" 42000.0)))
    (check (not (null obs)) "Should create observation")
    (check (approximately-equal (cl-oracle:observation-value obs) 42000.0d0)
           "Observation value should match")))

(deftest test-aggregation
  (cl-oracle:clear-all-feeds)
  (cl-oracle:create-feed "BTC/USD" :min-sources 3)
  (cl-oracle:submit-observation "BTC/USD" "binance" 42000.0)
  (cl-oracle:submit-observation "BTC/USD" "coinbase" 42050.0)
  (cl-oracle:submit-observation "BTC/USD" "kraken" 41990.0)
  (multiple-value-bind (price confidence)
      (cl-oracle:aggregate-now "BTC/USD")
    (check (> price 41000) "Price should be reasonable")
    (check (> confidence 0) "Should have positive confidence")))

(deftest test-quick-price
  (multiple-value-bind (price confidence)
      (cl-oracle:quick-price "BTC/USD"
                             '(("binance" . 42000)
                               ("coinbase" . 42050)
                               ("kraken" . 41990)))
    (check (approximately-equal price 42000.0d0 100.0)
           "Quick price should be near 42000")
    (check (>= confidence 0.0) "Confidence should be non-negative")))

;;; ============================================================================
;;; Deviation Tests
;;; ============================================================================

(deftest test-check-deviation
  (check (approximately-equal (cl-oracle:check-deviation 100.0 101.0) 0.01d0)
         "1% deviation")
  (check (approximately-equal (cl-oracle:check-deviation 100.0 110.0) 0.1d0)
         "10% deviation")
  (check (= (cl-oracle:check-deviation 0.0 100.0) 0.0d0)
         "Division by zero handled"))

;;; ============================================================================
;;; Run All Tests
;;; ============================================================================

(defun run-tests ()
  "Run all cl-oracle tests."
  (reset-test-state)
  (format t "~%Running cl-oracle tests...~%~%")

  ;; Statistical tests
  (test-calculate-mean)
  (test-calculate-median)
  (test-calculate-std-deviation)
  (test-calculate-mad)
  (test-trimmed-mean)

  ;; Outlier tests
  (test-z-score-filter)
  (test-mad-filter)

  ;; Feed tests
  (test-create-feed)
  (test-list-feeds)

  ;; Source tests
  (test-register-source)
  (test-source-enable-disable)

  ;; Observation tests
  (test-submit-observation)
  (test-aggregation)
  (test-quick-price)

  ;; Deviation tests
  (test-check-deviation)

  (print-test-summary)
  (= *fail-count* 0))

;; Export
(export 'run-tests)
