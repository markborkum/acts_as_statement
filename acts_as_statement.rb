require 'active_record'

require 'digest/md5'

require 'rdf'
require 'rdf/ntriples'

module ActiveRecord
  module Acts
    module Statement
      def self.included(base)
        base.send(:extend, ActiveRecord::Acts::Statement::ClassMethods)
      end

      module ClassMethods
        ##
        # Initialization.
        #
        # @param  [Hash{Symbol => Object}] options
        # @option options [Array{String}]          :column_names 
        # @option options [Proc]                   :hexdigest_column_name
        # @option options [Proc]                   :hexdigest
        # @option options [String]                 :null
        # @option options [ActiveRecord::Relation] :scope
        # @yield [repository]  
        # @yieldparam [RDF::Repository] repository
        # @yieldreturn [void]
        # @return [void]
        def acts_as_statement(options = {}, &block)
          return if acts_as_statement?

          ##
          # Returns an array of column names.
          #
          # @return [Array{String}]
          cattr_accessor :acts_as_statement_column_names
          self.acts_as_statement_column_names = options[:column_names].presence || %w{subject predicate object context}

          ##
          # Returns a block that returns the hexdigest-counterpart of supplied `column_name`.
          #
          # @return [Proc]
          cattr_accessor :acts_as_statement_proc_for_hexdigest_column_name_for
          self.acts_as_statement_proc_for_hexdigest_column_name_for = options[:hexdigest_column_name].presence || ::Proc.new { |column_name| column_name.to_s[0...1] }

          ##
          # Returns a block that returns the hexdigest of the supplied `value`. 
          #
          # @return [Proc]
          cattr_accessor :acts_as_statement_proc_for_hexdigest_for
          self.acts_as_statement_proc_for_hexdigest_for = options[:hexdigest].presence || ::Proc.new { |value| Digest::MD5.hexdigest(value.to_s) }

          ## 
          # Returns the null value (default: "false").
          #
          # We cannot use NULL (the constant), as SQLite considers NULLs as distinct from each
          # other when using the uniqueness constraint, i.e., SQLite would allow us to insert 
          # duplicate statements using the NULL context (which would be bad!)
          #
          # Furthermore, we cannot use "" (the empty string), as this may be confused with
          # an empty value with the xsd:string datatype.
          #
          # Finally, the serialized null value must be distinct from all other serializations.
          #
          # @return [String]
          cattr_accessor :acts_as_statement_null
          self.acts_as_statement_null = options[:null].presence || false.to_s

          ##
          # Returns the default scope for instances of this class. 
          #
          # @return [ActiveRecord::Relation]
          cattr_accessor :acts_as_statement_scope
          self.acts_as_statement_scope = options[:scope].presence || scoped

          ## 
          # Helper methods
          #
          # @see http://viewsourcecode.org/why/hacking/seeingMetaclassesClearly.html
          (class << self; self; end).instance_eval do
            ##
            # Helper method that returns `true` if the supplied `serialized` value is null. Otherwise, returns `false`.
            #
            # @param  [Object, #to_s] serialized
            # @return [true, false]
            # @see #acts_as_statement_null
            send(:define_method, :acts_as_statement_null?) do |serialized|
              acts_as_statement_null.presence && (acts_as_statement_null.to_s == serialized.to_s)
            end

            ##
            # Helper method that returns the supplied `unserialized` value in the serialized format.
            #
            # @param  [Object] unserialized
            # @return [Object]
            # @see RDF::NTriples::Writer#serialize
            send(:define_method, :acts_as_statement_serialize) do |unserialized|
              RDF::NTriples::Writer.serialize(unserialized).presence || acts_as_statement_null
            end

            ##
            # Helper method that returns the supplied `serialized` value in the unserialized format.
            #
            # @param  [Object] serialized
            # @return [Object]
            # @see RDF::NTriples::Writer#unserialize
            send(:define_method, :acts_as_statement_unserialize) do |serialized|
              acts_as_statement_null?(serialized) ? nil : RDF::NTriples::Reader.unserialize(serialized)
            end

            ##
            # Helper method that returns the hexdigest-counterpart of supplied `column_name`.
            #
            # @param  [String, #to_s] column_name
            # @return [String]
            # @see #acts_as_statement_proc_for_hexdigest_column_name_for
            send(:define_method, :acts_as_statement_hexdigest_column_name_for) do |column_name|
              acts_as_statement_proc_for_hexdigest_column_name_for.call(column_name)
            end

            ##
            # Helper method that returns the hexdigest of the supplied `value`.
            #
            # @param  [Object, #to_s] value
            # @return [String]
            # @see #acts_as_statement_proc_for_hexdigest_for
            send(:define_method, :acts_as_statement_hexdigest_for) do |value|
              acts_as_statement_proc_for_hexdigest_for.call(value)
            end

            ##
            # Helper method that returns the hexdigest of the value of {#acts_as_statement_null}.
            #
            # @return [String]
            # @see #acts_as_statement_null
            send(:define_method, :acts_as_statement_hexdigest_for_null) do 
              acts_as_statement_hexdigest_for(acts_as_statement_null)
            end

            ##
            # Helper method that extracts the values of each column from the supplied `object`; returns a Hash.
            #
            # @param  [Object] object
            # @param  [Hash{Symbol => Object}] options
            # @option options [Symbol, #to_s] :with_value 
            # @return [Hash{Symbol => Object}]
            # @see #acts_as_statement_column_names
            send(:define_method, :acts_as_statement_column_name_values_as_hash) do |object, *args|
              options = args.extract_options!

              acts_as_statement_column_names.inject({}) { |acc, column_name|
                value = object.send(column_name.to_sym)

                if %w{serialize unserialize}.include?(options[:with_value].to_s)
                  value = send(:"acts_as_statement_#{options[:with_value]}", value)
                end

                acc[column_name.to_sym] = value
                acc
              }
            end

            ##
            # Helper method that extracts the values of each column from the supplied `object`; returns an Array.
            #
            # @param  [Object] object
            # @param  [Hash{Symbol => Object}] options
            # @option options [Integer, #to_i] :truncate
            # @return [Array{Object}]
            # @see #acts_as_statement_column_name_values_as_hash
            send(:define_method, :acts_as_statement_column_name_values_as_array) do |object, *args|
              options = args.extract_options!

              values_as_hash = acts_as_statement_column_name_values_as_hash(object, options)

              ::Range.new(0, (options[:truncate].presence || column_names.length).to_i - 1, false).collect { |column_name_idx|
                values_as_hash[acts_as_statement_column_names[column_name_idx].to_sym]
              }
            end
          end

          ##
          # Prevent mass-assignment of hexdigest columns, i.e., only allow mass-assignment of columns that hold a `value`. 
          attr_accessible *acts_as_statement_column_names

          if (all_column_names = acts_as_statement_column_names.collect { |column_name| [column_name, acts_as_statement_hexdigest_column_name_for(column_name)] }.flatten.collect(&:to_sym)).any?
            ##
            # Prevent re-assignment of all columns. 
            attr_readonly *all_column_names

            ##
            # Ensures that the hexdigest-counterpart of each column is present.  
            #
            # @param  [ActiveRecord::Base] record
            # @return [void]
            before_validation do |record|
              acts_as_statement_column_names.each do |column_name|
                record.send(:"#{record.class.acts_as_statement_hexdigest_column_name_for(column_name)}=", record.class.acts_as_statement_hexdigest_for(record.send(column_name.to_sym)))
              end
            end

            ##
            # Ensures that all columns are present before new records are persisted. 
            validates_presence_of *all_column_names
          end

          acts_as_statement_column_names.each do |column_name|
            ##
            # Named scope that returns a relation that enumerates all records that match the supplied `value` for the supplied `column_name`.
            #
            # @param  [RDF::Term, true, false, nil] value
            # @return [ActiveRecord::Relation]
            # @see #acts_as_statement_scope
            send(:scope, :"with_#{column_name}", ::Proc.new { |value|
              relation = acts_as_statement_scope

              if value.nil? || value.is_a?(RDF::Query::Variable)
                relation
              elsif hexdigest_column = arel_table[acts_as_statement_hexdigest_column_name_for(column_name).to_sym]
                case value
                  when FalseClass then relation.where(hexdigest_column.eq(acts_as_statement_hexdigest_for_null))
                  when TrueClass  then relation.where(hexdigest_column.eq(acts_as_statement_hexdigest_for_null).not)
                  else relation.where(hexdigest_column.eq(acts_as_statement_hexdigest_for(acts_as_statement_serialize(value))))
                end
              else
                relation.where(0)
              end
            })
          end

          ##
          # Named scope that returns a relation that enumerates all records that match the supplied `statement`.
          #
          # @param  [RDF::Statement, #to_statement] statement
          # @return [ActiveRecord::Relation]
          # @see #acts_as_statement_scope
          send(:scope, :for_statement, ::Proc.new { |statement|
            statement = statement.to_statement if statement.respond_to?(:to_statement)

            acts_as_statement_column_names.inject(acts_as_statement_scope) { |relation, column_name|
              relation.send(:"with_#{column_name}", statement.send(column_name.to_sym))
            }
          })

          ##
          # Named scope that returns a relation that enumerates all records that match the supplied `triple`.
          #
          # @param  [Array{Object}, #to_triple] triple
          # @return [ActiveRecord::Relation]
          # @see #acts_as_statement_scope
          send(:scope, :for_triple, ::Proc.new { |triple|
            triple = triple.to_triple if triple.respond_to?(:to_triple)

            ::Range.new(0, 2, false).inject(acts_as_statement_scope) { |relation, column_name_idx|
              relation.send(:"with_#{acts_as_statement_column_names[column_name_idx]}", triple[column_name_idx])
            }
          })

          ##
          # Named scope that returns a relation that enumerates all records that match the supplied `quad`.
          #
          # @param  [Array{Object}, #to_quad] quad
          # @return [ActiveRecord::Relation]
          # @see #acts_as_statement_scope
          send(:scope, :for_quad, ::Proc.new { |quad|
            quad = quad.to_quad if quad.respond_to?(:to_quad)

            ::Range.new(0, 3, false).inject(acts_as_statement_scope) { |relation, column_name_idx|
              relation.send(:"with_#{acts_as_statement_column_names[column_name_idx]}", quad[column_name_idx])
            }
          })

          ##
          # As the penultimate stage, now that the necessary helper methods have been defined
          # we can define the class- and instance-level methods. 
          send(:extend, ActiveRecord::Acts::Statement::SingletonMethods)
          send(:include, ActiveRecord::Acts::Statement::InstanceMethods)

          ##
          # Finally, if a block is supplied, emulate RDF.rb semantics by yielding the instance
          # of {RDF::Repository} for this class.
          block.call(repository) if block_given?

          return
        end

        ##
        # Always returns {false}. 
        #
        # @return [false]
        def acts_as_statement?
          false
        end
      end

      module SingletonMethods
        ##
        # Always returns {true}.
        #
        # @return [true]
        def acts_as_statement?
          true
        end

        ##
        # Find or create the supplied `statements` (in the order that they were supplied).
        #
        # @param  [RDF::Statement, Array{RDF::Statement}, #each_statement, #each] statements
        # @return [Array{ActsAsStatement::Concern}]
        def intern(statements)
          if method_name = ((statements.respond_to?(:each_statement) && :each_statement) || (statements.respond_to?(:each) && :each))
            output = []
            attributes_for_replacements = []

            statements.send(method_name) do |statement|
              if match = for_statement(statement).first
                output << match
              else
                output << attributes_for_replacements.length

                attributes_for_replacements << acts_as_statement_column_name_values_as_hash(statement, :with_value => :serialize)
              end
            end

            replacements = create(attributes_for_replacements)

            output.collect { |statement|
              case statement
                when ::Fixnum then replacements[statement]
                else statement
              end
            }
          else
            intern([statements]).first
          end
        end

        ##
        # Returns the repository for instances of this class.
        #
        # @return [RDF::Repository]
        def repository
          @@acts_as_statement_repository ||= begin
            repository = RDF::Repository.new

            statement_class = self

            ## 
            # Helper methods (optimized to use ActiveRecord)
            #
            # @see http://viewsourcecode.org/why/hacking/seeingMetaclassesClearly.html
            (class << repository; self; end).instance_eval do
              send(:include, ActiveRecord::Acts::Statement::Repository)
              send(:define_method, :acts_as_statement_class) { statement_class }
              send(:private, :acts_as_statement_class) 

              statement_class.acts_as_statement_column_names.each do |column_name|
                ##
                # @public
                # @see RDF::Enumerable#subjects, RDF::Enumerable#predicates, RDF::Enumerable#objects, RDF::Enumerable#contexts
                send(:define_method, column_name.to_s.pluralize.to_sym) do |*args|
                  options = args.extract_options!

                  column = acts_as_statement_class.arel_table[column_name.to_sym]

                  hexdigest_column_name = acts_as_statement_class.acts_as_statement_hexdigest_column_name_for(column_name)
                  hexdigest_column = acts_as_statement_class.arel_table[hexdigest_column_name.to_sym]

                  relation = acts_as_statement_class.acts_as_statement_scope
                  relation = relation.select(column)
                  relation = relation.where(hexdigest_column.eq(acts_as_statement_class.acts_as_statement_hexdigest_for_null).not)

                  unless options[:unique] == false
                    relation = relation.uniq(true)
                  end

                  ## 
                  # Helper methods (for lazy "unserialization")
                  #
                  # @see http://viewsourcecode.org/why/hacking/seeingMetaclassesClearly.html
                  (class << relation; self; end).instance_eval do
                    send(:define_method, :acts_as_statement_class) { statement_class }
                    send(:define_method, :acts_as_statement_column_name) { column_name }
                    send(:define_method, :acts_as_statement_hexdigest_column_name) { hexdigest_column_name }
                    send(:private, :acts_as_statement_class, :acts_as_statement_column_name, :acts_as_statement_hexdigest_column_name)

                    send(:define_method, :to_a) do
                      logging_query_plan do
                        exec_queries
                      end

                      # Lazy "unserialization" of records
                      if loaded?
                        instance_variable_set(:"@records", instance_variable_get(:"@records").collect { |record|
                          record.send(acts_as_statement_column_name.to_sym)
                        }.collect { |value|
                          acts_as_statement_class.acts_as_statement_unserialize(value)
                        })
                      end
                    end

                    unless options[:unique] == false
                      send(:alias_method, :calculate_without_acts_as_statement_class, :calculate)

                      send(:define_method, :calculate_with_acts_as_statement_class) do |*args|
                        calculate_with_acts_as_statement_class_options = args.extract_options!

                        calculate_with_acts_as_statement_class_operation = args.shift
                        calculate_with_acts_as_statement_class_column_name = args.shift

                        if calculate_with_acts_as_statement_class_column_name.nil?
                          calculate_with_acts_as_statement_class_options.merge!(:distinct => true)

                          calculate_with_acts_as_statement_class_column_name = acts_as_statement_hexdigest_column_name
                        end

                        uniq(false).calculate_without_acts_as_statement_class(calculate_with_acts_as_statement_class_operation, calculate_with_acts_as_statement_class_column_name, calculate_with_acts_as_statement_class_options)
                      end

                      send(:alias_method, :calculate, :calculate_with_acts_as_statement_class)
                    end
                  end

                  relation
                end

                ##
                # @public
                # @see RDF::Enumerable#enum_subject, RDF::Enumerable#enum_predicate, RDF::Enumerable#enum_object, RDF::Enumerable#enum_context
                send(:alias_method, :"enum_#{column_name}", column_name.to_s.pluralize.to_sym)
                send(:alias_method, :"enum_#{column_name.to_s.pluralize}", :"enum_#{column_name}")

                ##
                # @public
                # @see RDF::Enumerable#has_subject?, RDF::Enumerable#has_predicate?, RDF::Enumerable#has_object?, RDF::Enumerable#has_context?
                send(:define_method, :"has_#{column_name}?") do |value|
                  acts_as_statement_class.send(:"with_#{column_name}", value).any?
                end

                ##
                # @public
                # @see RDF::Enumerable#each_subject, RDF::Enumerable#each_predicate, RDF::Enumerable#each_object, RDF::Enumerable#each_context
                send(:define_method, :"each_#{column_name}") do
                  if block_given?
                    send(column_name.to_s.pluralize.to_sym).each do |value|
                      yield(value)
                    end
                  end
                  send(:"enum_#{column_name}")
                end
              end
            end

            repository
          end
        end
      end

      module InstanceMethods
        ##
        # @public
        # @see ActiveModel::Serialization#serializable_hash
        def serializable_hash(options = nil)
          hexdigest_column_names = self.class.acts_as_statement_column_names.collect { |column_name| self.class.acts_as_statement_hexdigest_column_name_for(column_name).to_s }

          options ||= {}

          only = ([options[:only]].flatten.compact.collect(&:to_s) - hexdigest_column_names).sort.uniq.collect(&:to_sym)
          except = ([options[:except]].flatten.compact.collect(&:to_s) + hexdigest_column_names).sort.uniq.collect(&:to_sym)
          methods = ([options[:methods]].flatten.compact.collect(&:to_s) - hexdigest_column_names).sort.uniq.collect(&:to_sym)

          super(options.merge({
            :only => only.empty? ? nil : only,
            :except => except.empty? ? nil : except,
            :methods => methods.empty? ? nil : methods,
          }))
        end

        ##
        # Returns an instance of RDF::Statement with the same values as this instance.
        #
        # @return [RDF::Statement]
        def to_statement
          values = self.class.acts_as_statement_column_name_values_as_hash(self, :with_value => :unserialize)

          RDF::Statement.new(values[:subject], values[:predicate], values[:object], { :context => values[:context] })
        end

        ##
        # Returns a triple using the values of this instance.
        #
        # @return [Array{Object}]
        def to_triple
          # to_statement.to_triple
          self.class.acts_as_statement_column_name_values_as_array(self, :truncate => 3, :with_value => :unserialize)
        end

        ##
        # Returns a quad using the values of this instance.
        #
        # @return [Array{Object}]
        def to_quad
          # to_statement.to_quad
          self.class.acts_as_statement_column_name_values_as_array(self, :truncate => 4, :with_value => :unserialize)
        end
      end
    
      class Transaction < RDF::Transaction
        def initialize(repository, *args, &block)
          super(*args)

          @acts_as_statement_repository = repository

          if block_given?
            case block.arity
              when 1 then block.call(self)
              else instance_eval(&block)
            end
          end
        end

        protected

        ##
        # @protected
        # @see RDF::Repository#query
        def query(*args)
          @acts_as_statement_repository.query(*args)
        end
      end

      module Repository
        ##
        # @public
        # @see RDF::Repository#supports?
        def supports?(feature)
          case feature.to_sym
            when :context then true # statement contexts / named graphs
            when :inference then false # forward-chaining inference
            else false
          end
        end

        ##
        # @public
        # @see RDF::Countable#count
        def count
          acts_as_statement_class.count
        end

        ##
        # @public
        # @see RDF::Countable#empty?
        def empty?
          count == 0
        end

        ##
        # @public
        # @see RDF::Durable#durable?
        def durable?
          true
        end

        ##
        # @public
        # @see RDF::Enumerable#statements
        def statements
          relation = acts_as_statement_class.acts_as_statement_scope
          acts_as_statement_lazy!(relation, :to_statement)
          relation
        end

        ##
        # @public
        # @see RDF::Enumerable#has_statement?
        def has_statement?(statement)
          acts_as_statement_class.for_statement(statement).any?
        end

        ##
        # @public
        # @see RDF::Enumerable#each_statement
        def each_statement(&block)
          if block_given?
            acts_as_statement_class.acts_as_statement_scope.each do |statement|
              block.call(statement.to_statement)
            end
          end
          enum_statement
        end
        alias_method :each, :each_statement

        ##
        # @public
        # @see RDF::Enumerable#triples
        def triples
          relation = acts_as_statement_class.acts_as_statement_scope
          acts_as_statement_lazy!(relation, :to_triple)
          relation
        end

        ##
        # @public
        # @see RDF::Enumerable#has_triple?
        def has_triple?(triple)
          acts_as_statement_class.for_triple(triple).any?
        end

        ##
        # @public
        # @see RDF::Enumerable#each_triple
        def each_triple(&block)
          if block_given?
            acts_as_statement_class.acts_as_statement_scope.each do |statement|
              block.call(statement.to_triple)
            end
          end
          enum_triple
        end

        ##
        # @public
        # @see RDF::Enumerable#quads
        def quads
          relation = acts_as_statement_class.acts_as_statement_scope
          acts_as_statement_lazy!(relation, :to_quad)
          relation
        end

        ##
        # @public
        # @see RDF::Enumerable#has_quad?
        def has_quad?(quad)
          acts_as_statement_class.for_quad(quad).any?
        end

        ##
        # @public
        # @see RDF::Enumerable#each_quad
        def each_quad(&block)
          if block_given?
            acts_as_statement_class.acts_as_statement_scope.each do |statement|
              block.call(statement.to_quad)
            end
          end
          enum_quad
        end

        protected

        ##
        # @protected
        # @see RDF::Repository#begin_transaction
        def begin_transaction(context)
          ActiveRecord::Acts::Statement::Transaction.new(self, :context => context)
        end

        ##
        # @protected
        # @see RDF::Queryable#query_pattern
        def query_pattern(pattern, &block)
          if block_given?
            acts_as_statement_class.for_statement(pattern).each do |statement|
              block.call(statement.to_statement)
            end
          end

          return
        end

        ##
        # @protected
        # @see RDF::Mutable#insert_statement
        def insert_statement(statement)
          acts_as_statement_class.intern(statement)

          return
        end

        ##
        # @protected
        # @see RDF::Mutable#insert_statements
        def insert_statements(statements)
          acts_as_statement_class.intern(statements)

          return
        end

        ##
        # @protected
        # @see RDF::Mutable#delete_statement
        def delete_statement(statement)
          # As `nil` has wildcard semantics, we must ensure that statements which do
          # not assert a `context` have this attribute set to `false`. 
          statement.context ||= false

          acts_as_statement_class.for_statement(statement).destroy_all

          return
        end

        ##
        # @protected
        # @see RDF::Mutable#delete_statements
        def delete_statements(statements)
          if statements == self
            clear_statements
          else
            statements.send(statements.respond_to?(:each_statement) ? :each_statement : :each) do |statement|
              delete_statement(statement)
            end
          end

          return
        end

        ##
        # @protected
        # @see RDF::Mutable#clear_statements
        def clear_statements
          acts_as_statement_class.destroy_all

          return
        end

        private

        ##
        # Returns a class that responds to `acts_as_statement?`.
        #
        # @return [Class, #acts_as_statement?]
        # @raise  [NotImplementedError] always
        def acts_as_statement_class
          raise NotImplementedError.new("#{self.class}#acts_as_statement_class")
        end

        ##
        # Uses meta-programming to add lazy-loading semantics to the {#to_a} method of the supplied `relation`.
        #
        # @param  [ActiveRelation::Relation, #to_a] relation
        # @param  [Symbol, #to_sym] method_name
        # @return [void]
        # @see http://viewsourcecode.org/why/hacking/seeingMetaclassesClearly.html
        def acts_as_statement_lazy!(relation, method_name)
          ## 
          # Helper methods
          #
          # @see http://viewsourcecode.org/why/hacking/seeingMetaclassesClearly.html
          (class << relation; self; end).instance_eval do
            send(:define_method, :acts_as_statement_method_name) { method_name }
            send(:private, :acts_as_statement_method_name)

            send(:define_method, :to_a) do
              logging_query_plan do
                exec_queries
              end

              # Lazy-calling semantics for `method_name`
              if loaded?
                instance_variable_set(:"@records", instance_variable_get(:"@records").collect(&acts_as_statement_method_name.to_sym))
              end
            end
          end

          return
        end
      end
    end
  end
end

module RDF
  class Query::Pattern
    ##
    # @public
    # @see RDF::Query::Pattern#solution
    def solution(statement)
      RDF::Query::Solution.new do |solution|
        solution[subject.to_sym]   = statement.subject   if   subject.is_a?(RDF::Query::Variable)
        solution[predicate.to_sym] = statement.predicate if predicate.is_a?(RDF::Query::Variable)
        solution[object.to_sym]    = statement.object    if    object.is_a?(RDF::Query::Variable)

        # Ensure the presence of a binding for the `context` of each {RDF::Statement} instance, 
        # which may be `nil`.  Of course, receiving a `nil` response is infinitely better than
        # raising a {NoMethodError}!
        solution[:context] = statement.context
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::Statement)
