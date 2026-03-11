;;;; cl-oracle/validator.lisp - Outlier detection
;;;; Statistical methods for filtering invalid price observations

(in-package #:cl-oracle)

;;; ============================================================================
;;; Configuration
;;; ============================================================================

(defparameter *zscore-threshold* 2.5d0
  "Z-score threshold for outlier detection.")

(defparameter *mad-threshold* 3.5d0
  "MAD threshold multiplier for outlier detection.")

(defparameter *iqr-multiplier* 1.5d0
  "IQR multiplier for outlier detection.")

;;; ============================================================================
;;; Z-Score Filter
;;; ============================================================================

(defun z-score-filter (observations &optional (threshold *zscore-threshold*))
  "Filter outliers using Z-score method.

   Removes observations whose z-score exceeds the threshold.
   Z-score = (value - mean) / std-dev

   RETURNS:
   (values filtered rejected)"
  (if (< (length observations) 3)
      (values observations nil)
      (let* ((values (mapcar #'observation-value observations))
             (mean (calculate-mean values))
             (std-dev (calculate-std-deviation values mean))
             (filtered nil)
             (rejected nil))

        (if (< std-dev 1.0d-10)
            ;; No variance, keep all
            (values observations nil)
            (progn
              (dolist (obs observations)
                (let ((z-score (/ (abs (- (observation-value obs) mean)) std-dev)))
                  (if (> z-score threshold)
                      (push obs rejected)
                      (push obs filtered))))
              (values (nreverse filtered) (nreverse rejected)))))))

;;; ============================================================================
;;; IQR Filter
;;; ============================================================================

(defun iqr-filter (observations &optional (multiplier *iqr-multiplier*))
  "Filter outliers using Interquartile Range (IQR) method.

   Removes observations outside [Q1 - k*IQR, Q3 + k*IQR].

   RETURNS:
   (values filtered rejected)"
  (if (< (length observations) 4)
      (values observations nil)
      (let ((values (mapcar #'observation-value observations)))
        (multiple-value-bind (q1 q3 iqr) (calculate-iqr values)
          (let ((lower-bound (- q1 (* multiplier iqr)))
                (upper-bound (+ q3 (* multiplier iqr)))
                (filtered nil)
                (rejected nil))
            (dolist (obs observations)
              (let ((v (observation-value obs)))
                (if (or (< v lower-bound) (> v upper-bound))
                    (push obs rejected)
                    (push obs filtered))))
            (values (nreverse filtered) (nreverse rejected)))))))

;;; ============================================================================
;;; MAD Filter
;;; ============================================================================

(defun mad-filter (observations &optional (threshold *mad-threshold*))
  "Filter outliers using Median Absolute Deviation (MAD) method.

   More robust than z-score for non-normal distributions.
   Uses modified z-score = 0.6745 * (value - median) / MAD

   RETURNS:
   (values filtered rejected)"
  (if (< (length observations) 3)
      (values observations nil)
      (let* ((values (mapcar #'observation-value observations))
             (median (calculate-median values))
             (mad (calculate-mad values median))
             (filtered nil)
             (rejected nil))

        (if (< mad 1.0d-10)
            ;; No deviation, keep all
            (values observations nil)
            (progn
              (dolist (obs observations)
                (let* ((v (observation-value obs))
                       ;; Modified z-score using MAD
                       (mod-z (/ (* 0.6745d0 (abs (- v median))) mad)))
                  (if (> mod-z threshold)
                      (push obs rejected)
                      (push obs filtered))))
              (values (nreverse filtered) (nreverse rejected)))))))

;;; ============================================================================
;;; Main Outlier Detection
;;; ============================================================================

(defun detect-outliers (observations &optional (method :mad))
  "Detect and filter outliers using specified method.

   PARAMETERS:
   - observations: List of observation structures
   - method: Detection method (:zscore, :iqr, :mad, :none)

   RETURNS:
   (values filtered rejected)"
  (if (eq method :none)
      (values observations nil)
      (case method
        (:zscore (z-score-filter observations))
        (:iqr (iqr-filter observations))
        (:mad (mad-filter observations))
        (otherwise (mad-filter observations)))))

;;; ============================================================================
;;; Deviation Checking
;;; ============================================================================

(defun check-deviation (old-value new-value)
  "Calculate percentage deviation between two values.
   Returns absolute deviation as a ratio (0.0 - 1.0+)."
  (if (or (null old-value) (zerop old-value))
      0.0d0
      (ensure-double (abs (/ (- new-value old-value) old-value)))))

(defun deviation-exceeded-p (feed-name proposed-value)
  "Check if proposed value exceeds feed's deviation threshold.

   RETURNS:
   (values exceeded-p deviation-ratio threshold)"
  (let* ((feed (get-feed feed-name))
         (current (price-feed-value feed))
         (threshold (price-feed-deviation-threshold feed))
         (deviation (check-deviation current proposed-value)))
    (values (> deviation threshold) deviation threshold)))
