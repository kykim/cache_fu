module ActsAsCached
  module ClassMethods
    def belongs_to_cached(association_id, options = {})
      self.belongs_to(association_id, options)
      reflection = self.reflections[association_id]

      define_method("cached_#{reflection.name}") do |*params|
        force_reload = params.first unless params.empty?
        cached_association = instance_variable_get("@cached_#{reflection.name}")
        if cached_association.nil? || force_reload
          begin
            cached_association = reflection.klass.get_cache( self.attributes[reflection.primary_key_name] )
          rescue ActiveRecord::RecordNotFound
            cached_association = nil
          end

          if cached_association.nil?
            instance_variable_set("@cached_#{reflection.name}", nil)
            return nil
          end
          instance_variable_set("@cached_#{reflection.name}", cached_association)
        end

        cached_association
      end
    end

    def has_one_cached(association_id, options = {})
      self.has_one(association_id, options)
      reflection = self.reflections[association_id]

      define_method("cached_#{reflection.name}") do |*params|
        force_reload = params.first unless params.empty?
        cached_association_id = CACHE.get( "#{self.cache_key}:#{reflection.name}_id" )
        if cached_association_id.nil? || force_reload
          begin
            cached_association = send(reflection.name)
          rescue ActiveRecord::RecordNotFound
            cached_association = nil
          end

          return nil  if cached_association.nil?
          CACHE.set( "#{self.cache_key}:#{reflection.name}_id", cached_association.id )
          cached_association.set_cache
        end

        cached_association
      end
    end

    def has_many_cached(association_id, options = {})
      self.has_many(association_id, options)
      reflection = self.reflections[association_id]
      singular_reflection = reflection.klass.name.downcase

      ids_reflection = "#{singular_reflection}_ids"
      define_method("cached_#{ids_reflection}") do |*params|
        force_reload = params.first unless params.empty?
        cached_association = CACHE.get( "#{self.cache_key}:#{ids_reflection}" )
        if cached_association.nil? || force_reload
          begin
            cached_association = send(ids_reflection)
          rescue ActiveRecord::RecordNotFound
            cached_association = nil
          end

          return nil  if cached_association.nil?
          CACHE.set( "#{self.cache_key}:#{ids_reflection}", cached_association )
        end

        cached_association
      end

      define_method("cached_#{reflection.name}") do |*params|
        puts reflection.inspect
        cached_association_ids = send("cached_#{ids_reflection}", *params)
        cached_association = cached_association_ids.map{ |id| reflection.klass.get_cache(id) }
        cached_association
      end
    end
  end
end
