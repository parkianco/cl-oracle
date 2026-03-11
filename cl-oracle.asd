;;;; cl-oracle.asd - Price Oracle Framework
;;;; Standalone price feed oracle with multi-source aggregation and outlier detection

(asdf:defsystem #:cl-oracle
  :description "Price Oracle Framework - Multi-source aggregation with outlier detection"
  :author "CLPIC Project"
  :license "MIT"
  :version "0.1.0"
  :serial t
  :components ((:file "package")
               (:module "src"
                :serial t
                :components ((:file "util")
                             (:file "feed")
                             (:file "aggregator")
                             (:file "validator")
                             (:file "oracle")))))

(asdf:defsystem #:cl-oracle/test
  :description "Tests for cl-oracle"
  :depends-on (#:cl-oracle)
  :components ((:module "test"
                :components ((:file "test-oracle")))))
