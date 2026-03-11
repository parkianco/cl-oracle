;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: BSD-3-Clause

;;;; cl-oracle/oracle.lisp - Main oracle interface
;;;; High-level API for price oracle operations

(in-package #:cl-oracle)

;;; ============================================================================
;;; Observation Submission
;;; ============================================================================

(defun submit-observation (feed-name source-name value &key timestamp)
  "Submit a price observation from a source.

   PARAMETERS:
   - feed-name: Name of the feed
   - source-name: Name of the source
   - value: Observed price value
   - timestamp: Optional observation timestamp

   RETURNS:
   The created observation"
  (let* ((feed (get-feed feed-name))
         (sources (price-feed-sources feed))
         (source (gethash source-name sources)))

    ;; Auto-register source if not exists
    (unless source
      (register-source feed-name source-name)
      (setf source (gethash source-name sources)))

    ;; Check source is enabled
    (unless (price-source-enabled source)
      (error 'oracle-error
             :message (format nil "Source ~A is disabled" source-name)))

    (let ((obs (make-observation :source source-name
                                 :value value
                                 :timestamp (or timestamp (current-timestamp))
                                 :weight (price-source-weight source))))
      ;; Add to pending observations
      (push obs (price-feed-pending-observations feed))

      ;; Update source stats
      (setf (price-source-last-value source) (ensure-double value))
      (setf (price-source-last-update source) (current-timestamp))
      (incf (price-source-fetch-count source))

      obs)))

;;; ============================================================================
;;; Price Retrieval
;;; ============================================================================

(defun get-price (feed-name)
  "Get the current aggregated price for a feed.

   Automatically aggregates pending observations if available,
   otherwise returns the stored value.

   RETURNS:
   Price as double-float

   ERRORS:
   - Signals stale-data-error if data exceeds heartbeat"
  (let ((feed (get-feed feed-name)))
    ;; Check staleness
    (when (price-stale-p feed-name)
      (error 'stale-data-error))

    ;; Process pending observations if any
    (process-pending-observations feed)

    (price-feed-value feed)))

(defun get-price-with-metadata (feed-name)
  "Get price with full metadata.

   RETURNS:
   (values price timestamp confidence num-sources)"
  (let ((feed (get-feed feed-name)))
    (process-pending-observations feed)
    (values (price-feed-value feed)
            (price-feed-timestamp feed)
            (price-feed-confidence feed)
            (hash-table-count (price-feed-sources feed)))))

;;; ============================================================================
;;; Internal Processing
;;; ============================================================================

(defun process-pending-observations (feed)
  "Process pending observations and update feed value."
  (let ((pending (price-feed-pending-observations feed)))
    (when (and pending (>= (length pending) (price-feed-min-sources feed)))
      ;; Aggregate observations
      (multiple-value-bind (value confidence filtered-count rejected-count)
          (aggregate pending :method :median :outlier-method :mad)
        (declare (ignore rejected-count))

        ;; Update feed
        (setf (price-feed-value feed) value)
        (setf (price-feed-timestamp feed) (current-timestamp))
        (setf (price-feed-confidence feed) confidence)

        ;; Add to history
        (add-to-history feed value confidence filtered-count)

        ;; Clear pending
        (setf (price-feed-pending-observations feed) nil)

        t))))

;;; ============================================================================
;;; Batch Operations
;;; ============================================================================

(defun submit-batch (feed-name observations)
  "Submit multiple observations at once.

   PARAMETERS:
   - feed-name: Name of the feed
   - observations: List of (source-name . value) pairs

   RETURNS:
   Number of observations submitted"
  (loop for (source . value) in observations
        do (submit-observation feed-name source value)
        count t))

(defun aggregate-now (feed-name &key (method :median) (outlier-method :mad))
  "Force immediate aggregation of pending observations.

   RETURNS:
   (values new-price confidence filtered-count rejected-count)"
  (let* ((feed (get-feed feed-name))
         (pending (price-feed-pending-observations feed)))

    (when (< (length pending) (price-feed-min-sources feed))
      (error 'insufficient-sources-error
             :message (format nil "Need ~D sources, have ~D"
                             (price-feed-min-sources feed)
                             (length pending))))

    (multiple-value-bind (value confidence filtered-count rejected-count)
        (aggregate pending :method method :outlier-method outlier-method)

      ;; Update feed
      (setf (price-feed-value feed) value)
      (setf (price-feed-timestamp feed) (current-timestamp))
      (setf (price-feed-confidence feed) confidence)

      ;; Add to history
      (add-to-history feed value confidence filtered-count)

      ;; Clear pending
      (setf (price-feed-pending-observations feed) nil)

      (values value confidence filtered-count rejected-count))))

;;; ============================================================================
;;; Convenience Functions
;;; ============================================================================

(defun quick-price (feed-name sources)
  "Quick one-shot price aggregation without persistent state.

   PARAMETERS:
   - feed-name: Identifier for the price (e.g., \"BTC/USD\")
   - sources: List of (source-name . value) pairs

   RETURNS:
   (values price confidence)

   Example:
   (quick-price \"BTC/USD\" '((\"binance\" . 42000)
                              (\"coinbase\" . 42050)
                              (\"kraken\" . 41990)))"
  (let ((observations (loop for (source . value) in sources
                           collect (make-observation :source source
                                                    :value value))))
    (multiple-value-bind (price confidence)
        (aggregate observations)
      (values price confidence))))

;;; ============================================================================
;;; Inspection
;;; ============================================================================

(defun feed-status (feed-name)
  "Get detailed status of a feed.

   RETURNS:
   Property list with feed status"
  (let ((feed (get-feed feed-name)))
    (list :name (price-feed-name feed)
          :value (price-feed-value feed)
          :timestamp (price-feed-timestamp feed)
          :confidence (price-feed-confidence feed)
          :stale-p (price-stale-p feed-name)
          :staleness-seconds (timestamp-age (price-feed-timestamp feed))
          :heartbeat (price-feed-heartbeat feed)
          :deviation-threshold (price-feed-deviation-threshold feed)
          :min-sources (price-feed-min-sources feed)
          :num-sources (hash-table-count (price-feed-sources feed))
          :pending-count (length (price-feed-pending-observations feed))
          :history-count (length (price-feed-history feed)))))

(defun clear-all-feeds ()
  "Clear all registered feeds. For testing."
  (clrhash *feeds*)
  t)
