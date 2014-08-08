class Chef
  class Resource::RedmineProject < Resource
    identity_attr :project_identifier

    attr_writer :exists
    def initialize(project_identifier, run_context = nil)
      super

      # Set the resource name and provider
      @resource_name = :redmine_project
      @provider = Provider::RedmineProject

      # Set default actions and allowed actions
      @action = :create
      @allowed_actions.push(:create, :delete)

      # Set the name attribute and default attributes
      @project_identifier = project_identifier

      # State attributes that are set by the provider
      @exists = false
    end

    def name(arg = nil)
      set_or_return(:name, arg, :kind_of => String)
    end

    def foo(arg = nil)
      set_or_return(:foo, arg, :kind_of => String)
    end

    def connection(arg = nil)
      set_or_return(:connection, arg, :kind_of=> Hash)
    end

    #
    # The full name of the user to create.
    #
    # @param [String] arg
    # @return [String]
    #
    def project_identifier(arg = nil)
      set_or_return(:project_identifier, arg, :kind_of => String)
    end

    #
    # @return [Boolean]
    #
    def exists?
      !!@exists
    end

  end
end

class Chef
  class Provider::RedmineProject < Provider
    require 'json'

    require_relative '_helper'
    include Redmine::Helper

    def load_current_resource
      @current_resource ||= Resource::RedmineProject.new(new_resource.project_identifier)

      if current_project
        @current_resource.exists = true
        @current_resource.project_identifier(current_project[:project_identifier])
        @current_resource.name(current_project[:name])
        @current_resource.connection(current_project[:connection])
      end
    end

    #
    # This provider supports why-run mode.
    #
    def whyrun_supported?
      true
    end

    #
    # Create the given user.
    #
    def action_create
      if current_resource.exists? &&
      current_resource.name == new_resource.name &&
      current_resource.project_identifier == new_resource.project_identifier
        Chef::Log.debug("#{new_resource} exists - skipping")
      else
        wait_until_ready!
        Chef::Log.info("Create Project #{new_resource.name} at #{new_resource.connection[:host]}")
        #actually create foo
        redmine = RestClient::Resource.new( new_resource.connection[:host], { :user => new_resource.connection[:username] , :password => new_resource.connection[:password]})

        #createProject
        project = { :project =>  { :name => new_resource.name , :identifier => new_resource.project_identifier }}.to_json
        response = redmine["/projects.json"].post project, :content_type => 'application/json'
      end
    end

    #
    # Delete the given user.
    #
    def action_delete
      if current_resource.exists?
        Chef::Log.info("Delete Project #{new_resource}")
      else
        Chef::Log.debug("#{new_resource} does not exist - skipping")
      end
    end

    private

    #
    # Loads the local user into a hash
    #
    def current_project
      return @current_project if @current_project

      Chef::Log.debug "Load #{new_resource} project information"
      json = {}
      # we need to check if the project already exists
      #json = getProject(@new_resource.project_identifier)

      return nil if json.nil? || json.empty?

      @current_project = JSON.parse(json, :symbolize_names => true)
      @current_project
    end
  end
end
