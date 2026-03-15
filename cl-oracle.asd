;; Copyright (c) 2024-2026 Parkian Company LLC. All rights reserved.
;; SPDX-License-Identifier: BSD-3-Clause

;;;; cl-oracle.asd - Price Oracle Framework
;;;; Standalone price feed oracle with multi-source aggregation and outlier detection

(asdf:defsystem #:cl-oracle
  :description "Price Oracle Framework - Multi-source aggregation with outlier detection"
  :author "Park Ian Co"
  :license "Apache-2.0"
  :version "0.1.0"
  :serial t
  :components ((:file "package")
               (:module "src"
                :components ((:file "package")
                             (:file "conditions" :depends-on ("package"))
                             (:file "types" :depends-on ("package"))
                             (:file "cl-oracle" :depends-on ("package" "conditions" "types")))))))

(asdf:defsystem #:cl-oracle/test
  :description "Tests for cl-oracle"
  :depends-on (#:cl-oracle)
  :components ((:module "test"
                :components ((:file "test-oracle")))))
