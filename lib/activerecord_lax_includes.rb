# frozen_string_literal: true

module ActiveRecordLaxIncludes
  def lax_includes
    Thread.current[:active_record_lax_includes_enabled] = true
    yield
  ensure
    Thread.current[:active_record_lax_includes_enabled] = false
  end

  def lax_includes_enabled?
    result = Thread.current[:active_record_lax_includes_enabled]
    if result.nil?
      result =
        Rails.configuration.respond_to?(:active_record_lax_includes_enabled) &&
        Rails.configuration.active_record_lax_includes_enabled
    end
    result
  end

  module Base
    def association(name)
      association = association_instance_get(name)

      if association.nil?
        if reflection = self.class._reflect_on_association(name)
          association = reflection.association_class.new(self, reflection)
          association_instance_set(name, association)
        elsif !ActiveRecord.lax_includes_enabled?
          raise ActiveRecord::AssociationNotFoundError.new(self, name)
        end
      end

      association
    end
  end

  module Preloader
    private

    def preloaders_on(association, records, scope, polymorphic_parent = false)
      case association
      when Hash
        preloaders_for_hash(association, records, scope, polymorphic_parent)
      when Symbol
        preloaders_for_one(association, records, scope, polymorphic_parent)
      when String
        preloaders_for_one(association.to_sym, records, scope, polymorphic_parent)
      else
        raise ArgumentError, "#{association.inspect} was not recognised for preload"
      end
    end

    def preloaders_for_hash(association, records, scope, polymorphic_parent)
      association.flat_map do |parent, child|
        loaders = preloaders_for_one parent, records, scope, polymorphic_parent
        recs = loaders.flat_map(&:preloaded_records).uniq

        reflection = records.first.class._reflect_on_association(parent)
        polymorphic_parent = reflection && reflection.options[:polymorphic]

        loaders.concat Array.wrap(child).flat_map { |assoc|
          preloaders_on assoc, recs, scope, polymorphic_parent
        }
        loaders
      end
    end

    def preloaders_for_one(association, records, scope, polymorphic_parent)
      grouped =
        grouped_records(association, records, ActiveRecord.lax_includes_enabled? && polymorphic_parent)

      grouped.flat_map do |reflection, klasses|
        klasses.map do |rhs_klass, rs|
          loader = preloader_for(reflection, rs, rhs_klass).new(rhs_klass, rs, reflection, scope)
          loader.run self
          loader
        end
      end
    end

    def preloader_for(reflection, rs, rhs_klass)
      return super if legacy_active_record?

      super(reflection, rs)
    end

    def legacy_active_record?
      ActiveRecord::VERSION::MAJOR < 5
    end

    def grouped_records(association, records, polymorphic_parent)
      h = {}
      records.each do |record|
        next unless record
        next if polymorphic_parent && !record.class._reflect_on_association(association)

        assoc = record.association(association)
        next unless assoc.klass

        klasses = h[assoc.reflection] ||= {}
        (klasses[assoc.klass] ||= []) << record
      end
      h
    end
  end
end

require 'active_record'

ActiveRecord.extend ActiveRecordLaxIncludes
ActiveRecord::Base.prepend ActiveRecordLaxIncludes::Base
ActiveRecord::Associations::Preloader.prepend ActiveRecordLaxIncludes::Preloader
