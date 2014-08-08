class Chef
  class Resource::RedmineUser < Resource
    identity_attr :user_identifier

    attr_writer :exists
    def initialize(user_identifier, run_context = nil)
      super

      # Set the resource name and provider
      @resource_name = :redmine_user
      @provider = Provider::RedmineUser

      # Set default actions and allowed actions
      @action = :create
      @allowed_actions.push(:create, :delete, :update)

      # Set the name attribute and default attributes
      @user_identifier = user_identifier

      # State attributes that are set by the provider
      @exists = false
    end

    def mail(arg = nil)
      set_or_return(:mail, arg, :kind_of => String)
    end
    
    def new_login(arg = nil)
      set_or_return(:new_login, arg, :kind_of => String)
    end
    
    def password(arg = nil)
      set_or_return(:password, arg, :kind_of => String)
    end

    def first_name(arg = nil)
      set_or_return(:first_name, arg, :kind_of => String)
    end

    def last_name(arg = nil)
      set_or_return(:last_name, arg, :kind_of => String)
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
    def user_identifier(arg = nil)
      set_or_return(:user_identifier, arg, :kind_of => String)
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
  class Provider::RedmineUser < Provider
    require 'json'

    require_relative '_helper'
    include Redmine::Helper

    def load_current_resource
      @current_resource ||= Resource::RedmineUser.new(new_resource.user_identifier)

      if current_user
        @current_resource.exists = true
        @current_resource.user_identifier(current_user[:user_identifier])
        @current_resource.first_name(current_user[:first_name])
        @current_resource.last_name(current_user[:last_name])
        @current_resource.new_login(current_user[:new_login])
        @current_resource.mail(current_user[:mail])
        @current_resource.password(current_user[:password])
        @current_resource.connection(current_user[:connection])
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
      current_resource.last_name == new_resource.last_name &&
      current_resource.first_name == new_resource.first_name &&
      current_resource.password == new_resource.password &&
      current_resource.mail == new_resource.mail &&
      current_resource.user_identifier == new_resource.user_identifier
        Chef::Log.debug("#{new_resource} exists - skipping")
      else
        wait_until_ready!
        Chef::Log.info("Create User #{new_resource}")
        #actually create foo
        redmine = RestClient::Resource.new( new_resource.connection[:host], { :user => new_resource.connection[:username] , :password => new_resource.connection[:password]})

        #createUser
        user = { :user =>  { :login => new_resource.user_identifier, 
          :password => new_resource.password, 
          :mail => new_resource.mail, 
          :firstname =>new_resource.first_name, 
          :lastname => new_resource.last_name}}.to_json
        response = redmine['/users.json'].post user, :content_type => 'application/json'

      end
    end

    #
    # Create the given user.
    #
    def action_update
      if false
     #check if user is existent in redmine
      else
        wait_until_ready!
        Chef::Log.info("Update User #{new_resource}")
        #actually create foo
        redmine = RestClient::Resource.new( new_resource.connection[:host], { :user => new_resource.connection[:username] , :password => new_resource.connection[:password]})

        #createUser
        user = { :user =>  { :login => new_resource.new_login , :password => new_resource.password,  :mail => new_resource.mail, :firstname =>new_resource.first_name, :lastname => new_resource.last_name}}.to_json
        response = redmine["/users/#{getUserId redmine, new_resource.user_identifier}.json"].put user, :content_type => 'application/json'
      end
    end

    #
    # Delete the given user.
    #
    def action_delete
      if current_resource.exists?
        Chef::Log.info("Delete User #{new_resource}")
      else
        Chef::Log.debug("#{new_resource} does not exist - skipping")
      end
    end

    private

    #
    # Loads the local user into a hash
    #
    def current_user
      return @current_user if @current_user

      Chef::Log.debug "Load #{new_resource} user information"
      json = {}
      # we need to check if the user already exists
      #json = getUser(@new_resource.user_identifier)

      return nil if json.nil? || json.empty?

      @current_user = JSON.parse(json, :symbolize_names => true)
      @current_user
    end
  end
end
