;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package #:cl-oracle)

;;; Core types for cl-oracle
(deftype cl-oracle-id () '(unsigned-byte 64))
(deftype cl-oracle-status () '(member :ready :active :error :shutdown))
