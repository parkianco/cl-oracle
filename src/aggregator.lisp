;;;; cl-oracle/aggregator.lisp - Multi-source aggregation
;;;; Statistical aggregation methods for price data

(in-package #:cl-oracle)

;;; ============================================================================
;;; Basic Statistics
;;; ============================================================================

(defun calculate-mean (values)
  "Calculate arithmetic mean of a list of numbers."
  (if (null values)
      0.0d0
      (ensure-double (/ (reduce #'+ values :initial-value 0) (length values)))))

(defun calculate-median (values)
  "Calculate median of a list of numbers.
   Resistant to outliers, ideal for Byzantine-tolerant price aggregation."
  (if (null values)
      0.0d0
      (let* ((sorted (sorted-copy values #'<))
             (n (length sorted))
             (mid (floor n 2)))
        (ensure-double
         (if (oddp n)
             (nth mid sorted)
             (/ (+ (nth (1- mid) sorted) (nth mid sorted)) 2))))))

(defun calculate-variance (values &optional mean)
  "Calculate sample variance of a list of numbers."
  (if (or (null values) (< (length values) 2))
      0.0d0
      (let* ((m (or mean (calculate-mean values)))
             (squared-diffs (mapcar (lambda (v) (expt (- v m) 2)) values)))
        (ensure-double (/ (reduce #'+ squared-diffs) (1- (length values)))))))

(defun calculate-std-deviation (values &optional mean)
  "Calculate sample standard deviation."
  (sqrt (calculate-variance values mean)))

(defun calculate-mad (values &optional median)
  "Calculate Median Absolute Deviation (MAD).
   More robust than standard deviation for outlier detection."
  (if (or (null values) (< (length values) 2))
      0.0d0
      (let* ((med (or median (calculate-median values)))
             (deviations (mapcar (lambda (v) (abs (- v med))) values)))
        (calculate-median deviations))))

(defun calculate-iqr (values)
  "Calculate Interquartile Range (IQR).
   Returns (values q1 q3 iqr)."
  (if (< (length values) 4)
      (values 0.0d0 0.0d0 0.0d0)
      (let* ((sorted (sorted-copy values #'<))
             (n (length sorted))
             (q1-idx (floor n 4))
             (q3-idx (floor (* 3 n) 4))
             (q1 (ensure-double (nth q1-idx sorted)))
             (q3 (ensure-double (nth q3-idx sorted))))
        (values q1 q3 (- q3 q1)))))

;;; ============================================================================
;;; Weighted Aggregation
;;; ============================================================================

(defun calculate-weighted-mean (observations)
  "Calculate weighted mean from observations."
  (if (null observations)
      0.0d0
      (let ((weighted-sum 0.0d0)
            (weight-sum 0.0d0))
        (dolist (obs observations)
          (let ((v (observation-value obs))
                (w (observation-weight obs)))
            (incf weighted-sum (* v w))
            (incf weight-sum w)))
        (if (< weight-sum 1.0d-10)
            (calculate-mean (mapcar #'observation-value observations))
            (ensure-double (/ weighted-sum weight-sum))))))

(defun trimmed-mean (values &optional (trim-percentage 0.1d0))
  "Calculate trimmed mean by removing percentage from each end.
   More robust than arithmetic mean while preserving more data than median."
  (if (< (length values) 3)
      (calculate-mean values)
      (let* ((sorted (sorted-copy values #'<))
             (n (length sorted))
             (trim-count (floor (* n trim-percentage)))
             (trimmed (subseq sorted trim-count (- n trim-count))))
        (if (null trimmed)
            (calculate-median values)
            (calculate-mean trimmed)))))

;;; ============================================================================
;;; Confidence Calculation
;;; ============================================================================

(defun calculate-confidence (values)
  "Calculate confidence score based on agreement among values.
   Lower coefficient of variation = higher confidence."
  (if (or (null values) (< (length values) 2))
      0.0d0
      (let* ((mean (calculate-mean values))
             (std-dev (calculate-std-deviation values mean))
             (cv (safe-divide std-dev (abs mean))))
        ;; Lower CV = higher confidence, scaled to 0-1
        (clamp (- 1.0d0 (* cv 10)) 0.0d0 1.0d0))))

;;; ============================================================================
;;; Main Aggregation Function
;;; ============================================================================

(defun aggregate (observations &key (method :median) (outlier-method :mad))
  "Aggregate observations into a single value.

   PARAMETERS:
   - observations: List of observation structures
   - method: Aggregation method (:median, :mean, :weighted, :trimmed)
   - outlier-method: Outlier detection (:zscore, :iqr, :mad, :none)

   RETURNS:
   (values aggregated-value confidence filtered-count rejected-count)"
  (when (null observations)
    (return-from aggregate (values 0.0d0 0.0d0 0 0)))

  ;; Filter outliers first
  (multiple-value-bind (filtered rejected)
      (detect-outliers observations outlier-method)

    (when (null filtered)
      (return-from aggregate (values 0.0d0 0.0d0 0 (length rejected))))

    (let* ((values (mapcar #'observation-value filtered))
           (aggregated
             (case method
               (:median (calculate-median values))
               (:mean (calculate-mean values))
               (:weighted (calculate-weighted-mean filtered))
               (:trimmed (trimmed-mean values))
               (otherwise (calculate-median values))))
           (confidence (calculate-confidence values)))

      (values (ensure-double aggregated)
              confidence
              (length filtered)
              (length rejected)))))

;;; ============================================================================
;;; TWAP Calculation
;;; ============================================================================

(defun twap (feed-name &key (window 3600) start-time end-time)
  "Calculate Time-Weighted Average Price.

   TWAP weights each price by the duration it was current,
   reducing impact of price manipulation.

   RETURNS:
   (values twap num-samples time-span)"
  (let* ((now (current-timestamp))
         (end-ts (or end-time now))
         (start-ts (or start-time (- end-ts window)))
         (history (get-historical-prices feed-name
                                         :start-time start-ts
                                         :count 100000)))

    (when (null history)
      (return-from twap (values nil 0 0)))

    ;; Sort by timestamp oldest first
    (setf history (sorted-copy history #'< :key #'price-entry-timestamp))

    (let ((weighted-sum 0.0d0)
          (total-duration 0)
          (prev-ts start-ts)
          (prev-price (price-entry-value (first history))))

      (dolist (entry history)
        (let* ((ts (price-entry-timestamp entry))
               (price (price-entry-value entry))
               (duration (max 0 (- ts prev-ts))))
          (incf weighted-sum (* prev-price duration))
          (incf total-duration duration)
          (setf prev-ts ts)
          (setf prev-price price)))

      ;; Account for time from last price to end
      (let ((final-duration (max 0 (- end-ts prev-ts))))
        (incf weighted-sum (* prev-price final-duration))
        (incf total-duration final-duration))

      (if (zerop total-duration)
          (values prev-price 1 0)
          (values (/ weighted-sum total-duration)
                  (length history)
                  total-duration)))))

;;; ============================================================================
;;; VWAP Calculation
;;; ============================================================================

(defun vwap (feed-name &key (window 86400) start-time end-time volume-data)
  "Calculate Volume-Weighted Average Price.

   VWAP weights prices by trading volume for more accurate
   averaging in liquid markets.

   RETURNS:
   (values vwap total-volume num-samples)"
  (let* ((now (current-timestamp))
         (end-ts (or end-time now))
         (start-ts (or start-time (- end-ts window)))
         (history (get-historical-prices feed-name
                                         :start-time start-ts
                                         :count 100000)))

    (when (null history)
      (return-from vwap (values nil 0 0)))

    ;; Without volume data, fall back to equal weighting
    (unless volume-data
      (let* ((values (mapcar #'price-entry-value history))
             (n (length values))
             (sum (reduce #'+ values)))
        (return-from vwap (values (/ sum n) n n))))

    ;; VWAP with volume weighting
    (let ((pv-sum 0.0d0)
          (v-sum 0.0d0)
          (volume-map (make-hash-table)))

      (dolist (vd volume-data)
        (setf (gethash (car vd) volume-map) (cdr vd)))

      (dolist (entry history)
        (let* ((ts (price-entry-timestamp entry))
               (price (price-entry-value entry))
               (volume (or (gethash ts volume-map) 1)))
          (incf pv-sum (* price volume))
          (incf v-sum volume)))

      (if (zerop v-sum)
          (values nil 0 0)
          (values (/ pv-sum v-sum) v-sum (length history))))))
