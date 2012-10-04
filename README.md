acts_as_statement
=================

Reified statements for RDF.rb (designed for Ruby on Rails)

Examples
--------

```ruby
# /db/migrate/xxx_create_rdf_statements.rb
class CreateRdfStatements < ActiveRecord::Migration
  def change
    create_table :rdf_statements do |t|
      t.timestamps
      
      # hexdigests
      t.string :s, :null => false, :limit => 32
      t.string :p, :null => false, :limit => 32
      t.string :o, :null => false, :limit => 32
      t.string :c, :null => false, :limit => 32
      
      # quad
      t.text :subject
      t.text :predicate
      t.text :object
      t.text :context
    end
    
    # triplestore indices
    add_index :rdf_statements, :s
    add_index :rdf_statements, :p
    add_index :rdf_statements, :o
    add_index :rdf_statements, [:s, :p]
    add_index :rdf_statements, [:s, :o]
    add_index :rdf_statements, [:p, :o]
    add_index :rdf_statements, [:s, :p, :o]
    
    # quadstore indices
    add_index :rdf_statements, :c
    add_index :rdf_statements, [:s, :c]
    add_index :rdf_statements, [:p, :c]
    add_index :rdf_statements, [:o, :c]
    add_index :rdf_statements, [:s, :p, :c]
    add_index :rdf_statements, [:s, :o, :c]
    add_index :rdf_statements, [:p, :o, :c]
    add_index :rdf_statements, [:s, :p, :o, :c], :unique => true
  end
end
```

```ruby
# /app/models/rdf_statement.rb
require 'acts_as_statement'

class RdfStatement < ActiveRecord::Base
  acts_as_statement
end
```
