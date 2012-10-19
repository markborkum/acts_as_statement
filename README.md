acts_as_statement: an RDF.rb quad-store for Active Record
=========================================================

This is a pure-Ruby library for working with [Resource Description Framework (RDF)](http://www.w3.org/RDF/) data in [Active Record](http://ar.rubyonrails.org/)-based applications.

* <https://github.com/bendiken/rdf>
* <http://blog.datagraph.org/2010/04/rdf-repository-howto>

Features
--------

* 100% pure Ruby with minimal dependencies and no bloat.
* 100% free and unencumbered [public domain](http://unlicense.org/) software.
* Implements [RDF::Repository](http://rdf.rubyforge.org/RDF/Repository.html) interface as a concern for [ActiveRecord::Base](http://ar.rubyonrails.org/classes/ActiveRecord/Base.html) derivatives. 
* Plays nice with others: compatible with both [RDF.rb](https://github.com/bendiken/rdf) and [Active Record](http://ar.rubyonrails.org/) query interfaces. 

Examples
--------

```ruby
require 'active_record'
require 'acts_as_statement'
```

### Define an ActiveRecord class to represent an RDF quad

```ruby
class RdfStatement < ActiveRecord::Base
  acts_as_statement
end
```

### Define the relational database schema for a quad-store

acts_as_statement uses an indexed, four-column, relational database schema. 

The MD5 check-sum of the empty string "d41d8cd98f00b204e9800998ecf8427e" is used as a substitute for NULL. 

```ruby
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

### Query the quad-store using Active Record query interface

acts_as_statement provides 7x scoped relations:
* __with_subject__: all quads with the specified `subject`.
* __with_predicate__: all quads with the specified `predicate`.
* __with_object__: all quads with the specified `object`.
* __with_context__: all quads with the specified `context`.
* __for_statement__: all quads with the specified [RDF::Statement](http://rdf.rubyforge.org/RDF/Statement.html).
* __for_triple__: all quads with the specified `[subject, predicate, object]` tuple.
* __for_quad__: all quads with the specified `[subject, predicate, object, context]` tuple.

Arguments to "with_*" relations have the following semantics:
* [RDF::URI](http://rdf.rubyforge.org/RDF/URI.html): all quads with the specified URI.
* [RDF::Literal](http://rdf.rubyforge.org/RDF/Literal.html): all quads with the specified literal.
* `true`: all quads with a non-NULL value for the column denoted by (*).
* `false`: all quads with a NULL value for the column denoted by (*).
* `nil`: all quads.

```ruby
# find all quads with the specified subject and any context...
RdfStatement.with_context(nil).with_subject(RDF::URI.new('https://github.com/markborkum/acts_as_statement'))
```

### Query the quad-store using RDF.rb query interface

acts_as_statement implements the [RDF::Repository](http://rdf.rubyforge.org/RDF/Repository.html) interface, so you can use any [RDF.rb](https://github.com/bendiken/rdf) mechanism to query the quad-store. 

```ruby
query = RDF::Query.new({
  RDF::URI.new('https://github.com/markborkum/acts_as_statement') => {
    :predicate => :object,
  },
})

solutions = query.execute(RdfStatement.repository)

solutions.each do |solution|
  puts "predicate=#{solution[:predicate]} object=#{solution[:object]} (context=#{solution[:context]})"
end
```

Documentation
-------------

TODO

Dependencies
------------

* [Ruby](http://ruby-lang.org/) (>= 1.8.7) or (>= 1.8.1 with [Backports][])
* [RDF.rb](https://github.com/bendiken/rdf) (>= 0.3.4)

Installation
------------

TODO

Download
--------

To get a local working copy of the development repository, do:

    % git clone git://github.com/markborkum/acts_as_statement.git

Alternatively, download the latest development version as a tarball as follows:

    % wget https://github.com/markborkum/acts_as_statement/tarball/master
    
Resources
---------

TODO

Mailing List
------------

TODO

Authors
-------

* [Mark Borkum](http://github.com/markborkum) - <http://twitter.com/markborkum>

License
-------

This is free and unencumbered public domain software. For more information,
see <http://unlicense.org/> or the accompanying {file:UNLICENSE} file.
