#
# Cookbook Name:: jenkins
# Library:: helper
#
# Author:: Seth Vargo <sethvargo@gmail.com>
#
# Copyright 2013-2014, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'open-uri'
require 'timeout'

module Redmine
  module Helper
    class RedmineNotReady < StandardError
      def initialize(endpoint, timeout)
        super
      end
    end

    #
    # {URI.join} is a fucking nightmare. It rarely works. Using +File.join+ is
    # cool for URLs, until someone is running on Windows and their URLs use the
    # wrong slashes. This method attempts to cleanly join URI/URL segments into
    # a cleanly normalized URL that the libraries can use when constructing
    # URIs.
    #
    # @param [Array<String>] parts
    #   the list of parts to join
    #
    def uri_join(*parts)
      parts = parts.compact.map(&URI.method(:escape))
      URI.parse(parts.join('/')).normalize.to_s
    end

    private

    #
    # The global timeout for the executor.
    #
    # @return [Fixnum]
    #
    def timeout
      node['redmine']['executor']['timeout']
    end

    #
    # Boolean method to determine if proxy timeout was supplied.
    #
    # @return [Boolean]
    #
    def timeout_given?
      !!node['redmine']['executor']['timeout']
    end

    #
    # The URL endpoint for the Jenkins master.
    #
    # @return [String]
    #
    def endpoint
      "http://127.0.0.1" + node['redmine']['url_postfix']
      # master['endpoint'] = "http://#{node['jenkins']['master']['host']}:#{node['jenkins']['master']['port']}"
    end

    #
    # Since the Jenkins service returns immediately and the actual Java process
    # is started in the background, we block the Chef Client run until the
    # service endpoint(s) are _actually_ ready to accept requests.
    #
    # This method will effectively "block" the current thread until the Jenkins
    # master is ready to accept CLI and HTTP requests.
    #
    # @raise [JenkinsNotReady]
    #   if the Jenkins master does not respond within (+timeout+) seconds
    #
    def wait_until_ready!
      Timeout.timeout(timeout) do
        begin
          Chef::Log.debug "trying to open #{endpoint}"
          open(endpoint)
        rescue SocketError,
        Errno::ECONNREFUSED,
        Errno::ECONNRESET,
        Errno::ENETUNREACH,
        OpenURI::HTTPError => e
          # If authentication has been enabled, the server will return an HTTP
          # 403. This is "OK", since it means that the server is actually
          # ready to accept requests.
          return if e.message =~ /^403/
          Chef::Log.debug("Redmine is not accepting requests - #{e.message}")
          sleep(0.5)
          retry
        end
      end
    rescue Timeout::Error
      raise RedmineNotReady.new(endpoint, timeout)
    end

    def getUserId( site, name)
      id = -1;
      begin
        response = site["/users.json"].get
        locations = JSON.parse(response.body)['users'].each do |x|
          if x["login"] == name
            id = x['id']
          end
        end
      rescue => e
        log "Error while retreiving user id: "+ e.inspect
      end
      return id
    end

    def getProjectId( site, identifier )
      id = -1;
      begin
        response = site["/projects.json"].get
        locations = JSON.parse(response.body)['projects'].each do |x|
          if x["identifier"] == identifier
            id = x['id']
          end
        end
      rescue => e
        puts "Error while retreiving project id: "+ e.inspect
      end
      return id
    end

    # roles [1, 2, 3] 1= manager, 2= dev, 3 = reporter
    def addUser2Project( site, name, identifier, roles )
      log "Adding user to project "
      uid = getUserId site, name
      pid = getProjectId site, identifier
      membership = { :membership =>  { :user_id => uid , :role_ids => roles}}.to_json
      puts membership
      begin
        puts "/projects/#{pid}/memberships.json"
        response = site["/projects/#{pid}/memberships.json"].post membership, :content_type => 'application/json'
      rescue => e
        puts "Error while adding user to project: "+ e.inspect
      end
    end
  end
end
