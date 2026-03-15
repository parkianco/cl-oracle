;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0

;;;; cl-oracle/feed.lisp - Price feed abstraction
;;;; Core data structures for price feeds and sources

(in-package #:cl-oracle)

;;; ============================================================================
;;; Configuration Parameters
;;; ============================================================================

(defparameter *default-heartbeat* 3600
  "Default heartbeat interval in seconds (1 hour).")

(defparameter *default-deviation-threshold* 0.01d0
  "Default deviation threshold for updates (1%).")

(defparameter *default-min-sources* 3
  "Default minimum number of sources required.")

(defparameter *max-history-size* 1000
  "Maximum number of historical price entries to retain.")

;;; ============================================================================
;;; Conditions
;;; ============================================================================

(define-condition oracle-error (error)
  ((message :initarg :message :reader oracle-error-message))
  (:report (lambda (c s)
             (format s "Oracle error: ~A" (oracle-error-message c)))))

(define-condition feed-not-found-error (oracle-error)
  ()
  (:default-initargs :message "Feed not found"))

(define-condition stale-data-error (oracle-error)
  ()
  (:default-initargs :message "Data is stale"))

(define-condition insufficient-sources-error (oracle-error)
  ()
  (:default-initargs :message "Insufficient sources for aggregation"))

;;; ============================================================================
;;; Price Entry (History)
;;; ============================================================================

(defstruct (price-entry (:constructor make-price-entry))
  "A single historical price entry."
  (timestamp 0 :type (integer 0))
  (value 0.0d0 :type double-float)
  (confidence 0.0d0 :type double-float)
  (num-sources 0 :type (integer 0)))

;;; ============================================================================
;;; Price Source
;;; ============================================================================

(defstruct (price-source (:constructor %make-price-source))
  "A registered price data source."
  (name "" :type string)
  (weight 1.0d0 :type double-float)
  (enabled t :type boolean)
  (last-value 0.0d0 :type double-float)
  (last-update 0 :type (integer 0))
  (fetch-count 0 :type (integer 0))
  (error-count 0 :type (integer 0)))

(defun make-price-source (&key (name "") (weight 1.0d0) (enabled t))
  "Create a new price source."
  (%make-price-source
   :name name
   :weight (ensure-double weight)
   :enabled enabled
   :last-update (current-timestamp)))

;;; ============================================================================
;;; Observation
;;; ============================================================================

(defstruct (observation (:constructor %make-observation))
  "A single price observation from a source."
  (source "" :type string)
  (value 0.0d0 :type double-float)
  (timestamp 0 :type (integer 0))
  (weight 1.0d0 :type double-float))

(defun make-observation (&key source (value 0.0d0) timestamp (weight 1.0d0))
  "Create a new observation."
  (%make-observation
   :source (or source "")
   :value (ensure-double value)
   :timestamp (or timestamp (current-timestamp))
   :weight (ensure-double weight)))

;;; ============================================================================
;;; Price Feed
;;; ============================================================================

(defstruct (price-feed (:constructor %make-price-feed))
  "A price feed aggregating multiple sources."
  (name "" :type string)
  (value 0.0d0 :type double-float)
  (timestamp 0 :type (integer 0))
  (confidence 0.0d0 :type double-float)
  (decimals 8 :type (integer 0 18))
  (heartbeat 3600 :type (integer 1))
  (deviation-threshold 0.01d0 :type double-float)
  (min-sources 3 :type (integer 1))
  (sources (make-hash-table :test 'equal) :type hash-table)
  (history nil :type list)
  (pending-observations nil :type list))

(defun make-price-feed (&key name (decimals 8)
                             (heartbeat *default-heartbeat*)
                             (deviation-threshold *default-deviation-threshold*)
                             (min-sources *default-min-sources*))
  "Create a new price feed."
  (%make-price-feed
   :name name
   :decimals decimals
   :heartbeat heartbeat
   :deviation-threshold (ensure-double deviation-threshold)
   :min-sources min-sources
   :timestamp (current-timestamp)))

;;; ============================================================================
;;; Global Registry
;;; ============================================================================

(defvar *feeds* (make-hash-table :test 'equal)
  "Global registry of price feeds.")

(defun create-feed (name &key (decimals 8)
                              (heartbeat *default-heartbeat*)
                              (deviation-threshold *default-deviation-threshold*)
                              (min-sources *default-min-sources*))
  "Create and register a new price feed."
  (when (gethash name *feeds*)
    (error 'oracle-error :message (format nil "Feed ~A already exists" name)))
  (let ((feed (make-price-feed :name name
                               :decimals decimals
                               :heartbeat heartbeat
                               :deviation-threshold deviation-threshold
                               :min-sources min-sources)))
    (setf (gethash name *feeds*) feed)
    feed))

(defun get-feed (name)
  "Get a feed by name, or signal feed-not-found-error."
  (or (gethash name *feeds*)
      (error 'feed-not-found-error)))

(defun remove-feed (name)
  "Remove a feed from the registry."
  (remhash name *feeds*))

(defun list-feeds ()
  "List all registered feed names."
  (let ((names nil))
    (maphash (lambda (k v) (declare (ignore v)) (push k names)) *feeds*)
    names))

(defun feed-exists-p (name)
  "Check if feed exists."
  (not (null (gethash name *feeds*))))

;;; ============================================================================
;;; Source Management
;;; ============================================================================

(defun register-source (feed-name source-name &key (weight 1.0d0))
  "Register a source for a feed."
  (let ((feed (get-feed feed-name)))
    (setf (gethash source-name (price-feed-sources feed))
          (make-price-source :name source-name :weight weight))
    t))

(defun unregister-source (feed-name source-name)
  "Unregister a source from a feed."
  (let ((feed (get-feed feed-name)))
    (remhash source-name (price-feed-sources feed))))

(defun enable-source (feed-name source-name)
  "Enable a source."
  (let* ((feed (get-feed feed-name))
         (source (gethash source-name (price-feed-sources feed))))
    (when source
      (setf (price-source-enabled source) t))))

(defun disable-source (feed-name source-name)
  "Disable a source."
  (let* ((feed (get-feed feed-name))
         (source (gethash source-name (price-feed-sources feed))))
    (when source
      (setf (price-source-enabled source) nil))))

(defun list-sources (feed-name)
  "List all sources for a feed."
  (let ((feed (get-feed feed-name))
        (sources nil))
    (maphash (lambda (k v) (declare (ignore k)) (push v sources))
             (price-feed-sources feed))
    sources))

(defun source-active-p (feed-name source-name)
  "Check if source is active."
  (let* ((feed (get-feed feed-name))
         (source (gethash source-name (price-feed-sources feed))))
    (and source (price-source-enabled source))))

;;; ============================================================================
;;; Staleness Check
;;; ============================================================================

(defun price-stale-p (feed-name)
  "Check if feed data is stale (exceeds heartbeat)."
  (let ((feed (get-feed feed-name)))
    (> (timestamp-age (price-feed-timestamp feed))
       (price-feed-heartbeat feed))))

;;; ============================================================================
;;; History Management
;;; ============================================================================

(defun add-to-history (feed value confidence num-sources)
  "Add a price entry to feed history."
  (let ((entry (make-price-entry :timestamp (current-timestamp)
                                 :value (ensure-double value)
                                 :confidence (ensure-double confidence)
                                 :num-sources num-sources)))
    (push entry (price-feed-history feed))
    ;; Trim history if too large
    (when (> (length (price-feed-history feed)) *max-history-size*)
      (setf (price-feed-history feed)
            (take *max-history-size* (price-feed-history feed))))
    entry))

(defun get-historical-prices (feed-name &key (count 100) start-time end-time)
  "Get historical prices for a feed."
  (let ((feed (get-feed feed-name))
        (results nil))
    (dolist (entry (price-feed-history feed))
      (when (and (or (null start-time) (>= (price-entry-timestamp entry) start-time))
                 (or (null end-time) (<= (price-entry-timestamp entry) end-time))
                 (< (length results) count))
        (push entry results)))
    (nreverse results)))
