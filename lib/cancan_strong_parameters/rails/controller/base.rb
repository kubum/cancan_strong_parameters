class ActionController::Base
  # Use this with CanCan's load_resource to permit a set of params before
  # it tries to build or update a resource with them.
  #
  # Usage:
  #   class BooksController < ApplicationController
  #     load_resource :book
  #     permit_params book: [:title, :isbn]
  #   end
  #
  # Or:
  #   class BooksController < ApplicationController
  #     load_resource
  #     permit_params :title, :isbn
  #   end
  #
  # the second form should work in the simple case where you don't have to
  # supply a resource name for #load_resource
  #
  def self.permit_params *keys
    filter_strong_params :permit, [:create, :update], keys
  end

  # Like permit_params, but only applies to create action
  #
  def self.permit_params_on_create *keys
    filter_strong_params :permit, :create, keys
  end

  # Like permit_params, but only applies to update action
  #
  def self.permit_params_on_update *keys
    filter_strong_params :permit, :update, keys
  end

  # Like permit_params, but marks the params required
  #
  def self.require_params *keys
    filter_strong_params :require, [:create, :update], keys
  end

  # Like require_params, but only applies to create action
  #
  def self.require_params_on_create *keys
    filter_strong_params :require, :create, keys
  end

  # Like require_params, but only applies to update action
  #
  def self.require_params_on_update *keys
    filter_strong_params :require, :update, keys
  end

  # Does a permit! at every level of the params to let everything through
  #
  def self.permit_all_params options = {}
    prepend_before_filter options.reverse_merge(:only => [:create, :update]) do
      self.params.deep_permit!
    end
  end

  def self.filter_strong_params method, actions, keys # :nodoc:
    hash = keys.extract_options!
    keys.flatten!
    
    # Handle attributes if permitted attributes are given for nested models
    if (hash.present? && keys.present?) || (hash.select{|k,v| v.is_a?(Array)} == hash)
      prepend_before_filter :only => actions do
        resource_name = self.class.resource_name
        hash = self.class.attributized(hash)
        self.params[resource_name] = params[resource_name].send method, *[*keys.flatten, hash]
      end
    elsif hash.present?
      prepend_before_filter :only => actions do
        self.params.merge! params.send(method, hash)
      end
    else
      prepend_before_filter :only => actions do
        resource_name = self.class.resource_name
        if params.has_key?(resource_name)
          self.params[resource_name] = params[resource_name].send method, *keys
        else
          self.params = params.send method, *keys
        end
      end
    end
  end

  def self.resource_name
    self.to_s.sub("Controller", "").underscore.split('/').last.singularize
  end

  def self.attributized(hash)
    Hash.new.tap do |h|
      hash.each do |k,v|
        h[:"#{k}_attributes"] = v
      end
    end
  end
  
  def self.hashified(whitelist)
    hash = whitelist.extract_options! if whitelist.is_a?(Array)
    array = whitelist.dup    
    whitelist = (hash || {}) if hash
    array.map {|v| whitelist[v] = true }
    
    whitelist
  end
end

module ActionController
  class Parameters < ActiveSupport::HashWithIndifferentAccess
    def deep_permit!
      self.each do |key, value|
        if value.is_a?(Hash)
          if !value.respond_to?(:permit!)
            self[key] = value = ActionController::Parameters.new(value)
          end
          value.deep_permit!
        end
      end
      permit!
    end
  end
end
