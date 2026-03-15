;;;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;;;; SPDX-License-Identifier: Apache-2.0

;;;; cl-oracle - Package Definition
;;;; Standalone price oracle framework with multi-source aggregation

(in-package #:cl-user)

(defpackage #:cl-oracle
  (:use #:cl)
  (:export
   ;; ==========================================================================
   ;; Core Types
   ;; ==========================================================================

   ;; Price Feed
   #:price-feed
   #:make-price-feed
   #:price-feed-name
   #:price-feed-value
   #:price-feed-timestamp
   #:price-feed-confidence
   #:price-feed-decimals
   #:price-feed-heartbeat
   #:price-feed-deviation-threshold
   #:price-feed-min-sources
   #:price-feed-history
   #:price-feed-p

   ;; Price Source
   #:price-source
   #:make-price-source
   #:price-source-name
   #:price-source-weight
   #:price-source-enabled
   #:price-source-last-value
   #:price-source-last-update
   #:price-source-error-count
   #:price-source-p

   ;; Observation
   #:observation
   #:make-observation
   #:observation-source
   #:observation-value
   #:observation-timestamp
   #:observation-weight
   #:observation-p

   ;; ==========================================================================
   ;; Feed Management
   ;; ==========================================================================

   #:create-feed
   #:get-feed
   #:remove-feed
   #:list-feeds
   #:feed-exists-p

   ;; ==========================================================================
   ;; Source Management
   ;; ==========================================================================

   #:register-source
   #:unregister-source
   #:enable-source
   #:disable-source
   #:list-sources
   #:source-active-p

   ;; ==========================================================================
   ;; Price Operations
   ;; ==========================================================================

   #:submit-observation
   #:get-price
   #:get-price-with-metadata
   #:get-historical-prices
   #:price-stale-p

   ;; ==========================================================================
   ;; Aggregation
   ;; ==========================================================================

   #:aggregate
   #:calculate-median
   #:calculate-mean
   #:calculate-weighted-mean
   #:trimmed-mean

   ;; ==========================================================================
   ;; Outlier Detection
   ;; ==========================================================================

   #:detect-outliers
   #:z-score-filter
   #:iqr-filter
   #:mad-filter

   ;; ==========================================================================
   ;; Statistics
   ;; ==========================================================================

   #:calculate-variance
   #:calculate-std-deviation
   #:calculate-mad
   #:calculate-iqr
   #:calculate-confidence

   ;; ==========================================================================
   ;; TWAP/VWAP
   ;; ==========================================================================

   #:twap
   #:vwap

   ;; ==========================================================================
   ;; Deviation Checking
   ;; ==========================================================================

   #:check-deviation
   #:deviation-exceeded-p

   ;; ==========================================================================
   ;; Configuration
   ;; ==========================================================================

   #:*default-heartbeat*
   #:*default-deviation-threshold*
   #:*default-min-sources*
   #:*zscore-threshold*
   #:*iqr-multiplier*
   #:*mad-threshold*
   #:*max-history-size*

   ;; ==========================================================================
   ;; Conditions
   ;; ==========================================================================

   #:oracle-error
   #:oracle-error-message
   #:feed-not-found-error
   #:stale-data-error
   #:insufficient-sources-error))
