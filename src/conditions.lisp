;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: Apache-2.0

(in-package #:cl-oracle)

(define-condition cl-oracle-error (error)
  ((message :initarg :message :reader cl-oracle-error-message))
  (:report (lambda (condition stream)
             (format stream "cl-oracle error: ~A" (cl-oracle-error-message condition)))))
