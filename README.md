# Lazy JSON

Lazy JSON skimmer-parser. Ideal for cases where a small part of a large JSON document is accessed.
Super-low memory footprint. Speed depends partly on the structure of the document and the offset
of the portion of interest.

## Installation

In your `Gemfile`:

```
gem 'lazy-json'
```

## Usage

```
require 'lazy-json'

# Attach to document. Zero up-front processing here.
lj = LazyJson.attach(json_str)

# Skim to the value of interest and parse
lj['users'][10627811]['stats']['one_week']['message_count'].parse
```
