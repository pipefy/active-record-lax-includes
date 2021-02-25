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
    return result unless result.nil?

    Rails.configuration.respond_to?(:active_record_lax_includes_enabled) &&
      Rails.configuration.active_record_lax_includes_enabled
  end

  module Base
    def association(name)
      association = association_instance_get(name)

      if association.nil?
        if (reflection = self.class._reflect_on_association(name))
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
      when Symbol, String
        preloaders_for_one(association, records, scope, polymorphic_parent)
      else
        raise ArgumentError, "#{association.inspect} was not recognised for preload"
      end
    end

    def preloaders_for_hash(association, records, scope, polymorphic_parent) # rubocop:disable Metrics/MethodLength
      association.flat_map do |parent, child|
        grouped_records(parent, records, polymorphic_parent).flat_map do |reflection, reflection_records|
          loaders = preloaders_for_reflection(reflection, reflection_records, scope)
          recs = loaders.flat_map(&:preloaded_records).uniq
          child_polymorphic_parent = reflection && reflection.options[:polymorphic]
          loaders.concat(Array.wrap(child).flat_map do |assoc|
            preloaders_on assoc, recs, scope, child_polymorphic_parent
          end)
          loaders
        end
      end
    end

    def preloaders_for_one(association, records, scope, polymorphic_parent)
      grouped_records(association, records, polymorphic_parent)
        .flat_map do |reflection, reflection_records|
          preloaders_for_reflection reflection, reflection_records, scope
        end
    end

    def preloaders_for_reflection(reflection, records, scope)
      records.group_by { |record| record.association(reflection.name).klass }.map do |rhs_klass, rs|
        loader = preloader_for(reflection, rs, rhs_klass).new(rhs_klass, rs, reflection, scope)
        loader.run self
        loader
      end
    end

    def grouped_records(association, records, polymorphic_parent) # rubocop:disable Metrics/CyclomaticComplexity
      h = {}
      records.reject(&:nil?).each do |record|
        reflection = record.class._reflect_on_association(association)
        if (ActiveRecord.lax_includes_enabled? && polymorphic_parent) &&
           !reflection || !record.association(association).klass
          next
        end

        (h[reflection] ||= []) << record
      end
      h
    end

    def preloader_for(reflection, owners, rhs_klass)
      if legacy_active_record?
        return super(reflection, owners, ActiveRecord.lax_includes_enabled? ? Class : rhs_klass)
      end

      super(reflection, owners)
    end

    def legacy_active_record?
      @legacy_active_record ||=
        Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('5.2')
    end
  end
end

require 'active_record'

ActiveRecord.extend ActiveRecordLaxIncludes
ActiveRecord::Base.prepend ActiveRecordLaxIncludes::Base
ActiveRecord::Associations::Preloader.prepend ActiveRecordLaxIncludes::Preloader

begin
  require 'bullet'

  module Bullet
    class << self
      alias _enable= enable=

      # rubocop:disable Metrics/MethodLength
      def enable=(enable)
        _enable = enable

        ::ActiveRecord::Associations::Preloader.undef_method(:preloaders_for_one)
        ::ActiveRecord::Associations::Preloader.prepend(
          Module.new do
            def preloaders_for_one(association, records, scope, polymorphic_parent)
              if Bullet.start?
                records.compact!
                unless /^HABTM_/.match?(records.first.class.name)
                  records.each do |record|
                    Bullet::Detector::Association.add_object_associations(record, association)
                  end

                  Bullet::Detector::UnusedEagerLoading.add_eager_loadings(records, association)
                end
              end
              super
            end
          end
        )
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
rescue LoadError # rubocop:disable Lint/SuppressedException
end
