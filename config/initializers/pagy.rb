# Pagy initializer
# See https://ddnexus.github.io/pagy/docs/api/pagy#variables

require 'pagy/extras/overflow'

# Items per page (default: 20)
Pagy::DEFAULT[:items] = 25

# How to handle overflow (page number > last page)
Pagy::DEFAULT.freeze
