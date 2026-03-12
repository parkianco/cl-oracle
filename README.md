# cl-oracle

A standalone Common Lisp price oracle framework with multi-source aggregation and outlier detection.

## Features

- **Multi-source Price Feeds**: Aggregate prices from multiple data sources
- **Outlier Detection**: Z-score, IQR, and MAD-based filtering
- **Statistical Aggregation**: Median, mean, weighted mean, trimmed mean
- **TWAP/VWAP**: Time-weighted and volume-weighted average price calculations
- **Deviation Monitoring**: Track price deviations and staleness
- **Zero Dependencies**: Pure Common Lisp, no external libraries required

## Installation

Load with ASDF:

```lisp
(asdf:load-system :cl-oracle)
```

## Quick Start

```lisp
(use-package :cl-oracle)

;; Quick one-shot aggregation
(quick-price "BTC/USD"
             '(("binance" . 42000)
               ("coinbase" . 42050)
               ("kraken" . 41990)))
;; => 42000.0d0, 0.95 (price, confidence)

;; Create a persistent feed
(create-feed "ETH/USD" :decimals 8 :min-sources 3)

;; Register sources
(register-source "ETH/USD" "binance" :weight 1.0)
(register-source "ETH/USD" "coinbase" :weight 0.9)
(register-source "ETH/USD" "kraken" :weight 0.8)

;; Submit observations
(submit-observation "ETH/USD" "binance" 2500.0)
(submit-observation "ETH/USD" "coinbase" 2505.0)
(submit-observation "ETH/USD" "kraken" 2498.0)

;; Get aggregated price
(get-price "ETH/USD")
;; => 2500.0d0
```

## API Reference

### Feed Management

- `(create-feed name &key decimals heartbeat deviation-threshold min-sources)` - Create a new price feed
- `(get-feed name)` - Get feed by name
- `(remove-feed name)` - Remove a feed
- `(list-feeds)` - List all feed names
- `(feed-exists-p name)` - Check if feed exists

### Source Management

- `(register-source feed-name source-name &key weight)` - Register a price source
- `(unregister-source feed-name source-name)` - Remove a source
- `(enable-source feed-name source-name)` - Enable a source
- `(disable-source feed-name source-name)` - Disable a source
- `(list-sources feed-name)` - List all sources for a feed

### Price Operations

- `(submit-observation feed-name source-name value &key timestamp)` - Submit a price observation
- `(get-price feed-name)` - Get current aggregated price
- `(get-price-with-metadata feed-name)` - Get price with timestamp, confidence, and source count
- `(get-historical-prices feed-name &key count start-time end-time)` - Get price history
- `(quick-price name sources)` - One-shot aggregation without persistent state

### Aggregation

- `(aggregate observations &key method outlier-method)` - Aggregate observations
  - Methods: `:median`, `:mean`, `:weighted`, `:trimmed`
  - Outlier methods: `:zscore`, `:iqr`, `:mad`, `:none`
- `(calculate-median values)` - Calculate median
- `(calculate-mean values)` - Calculate arithmetic mean
- `(calculate-weighted-mean observations)` - Calculate weighted mean
- `(trimmed-mean values &optional trim-percentage)` - Calculate trimmed mean

### Outlier Detection

- `(detect-outliers observations &optional method)` - Filter outliers
- `(z-score-filter observations &optional threshold)` - Z-score based filtering
- `(iqr-filter observations &optional multiplier)` - IQR based filtering
- `(mad-filter observations &optional threshold)` - MAD based filtering

### Statistics

- `(calculate-variance values)` - Sample variance
- `(calculate-std-deviation values)` - Standard deviation
- `(calculate-mad values)` - Median Absolute Deviation
- `(calculate-iqr values)` - Interquartile Range (returns q1, q3, iqr)
- `(calculate-confidence values)` - Confidence score based on agreement

### TWAP/VWAP

- `(twap feed-name &key window start-time end-time)` - Time-Weighted Average Price
- `(vwap feed-name &key window start-time end-time volume-data)` - Volume-Weighted Average Price

### Configuration Parameters

- `*default-heartbeat*` - Default update interval (3600 seconds)
- `*default-deviation-threshold*` - Default deviation trigger (0.01 = 1%)
- `*default-min-sources*` - Default minimum sources (3)
- `*zscore-threshold*` - Z-score outlier threshold (2.5)
- `*iqr-multiplier*` - IQR outlier multiplier (1.5)
- `*mad-threshold*` - MAD outlier threshold (3.5)
- `*max-history-size*` - Maximum history entries (1000)

## Testing

```lisp
(asdf:load-system :cl-oracle/test)
(cl-oracle/test:run-tests)
```

## License

MIT License - see LICENSE file.

## Origin

