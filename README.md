acts_as_statement
=================

Reified statements for RDF.rb (designed for Ruby on Rails)

Example
-------

# /app/models/rdf_statement.rb

require 'acts_as_statement'

class RdfStatement < ActiveRecord::Base
  acts_as_statement
end
