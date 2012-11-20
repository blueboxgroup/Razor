require 'erb'
require 'yaml'
require 'net/ssh'
require 'project_razor/broker/chef/context'

module ProjectRazor
  module BrokerPlugin
    class ChefClient < ProjectRazor::BrokerPlugin::Base
      include ProjectRazor::Logging

      def initialize(hash)
        super

        @plugin = :chef_client
        @description = "Opscode Chef (chef-client)"
        @hidden = false
        from_hash(hash)
      end

      def agent_hand_off(options = {})
        return false unless validate_agent_options(options)

        output = ssh_exec(ssh_command, options)

        if output =~ /^Razor chef bootstrap completed\.$/
          :broker_success
        else
          :broker_fail
        end
      end

      def validate_agent_options(options)
        [:username, :password, :ipaddress].each do |attr|
          return false if options[attr].nil?
        end
        true
      end

      def ssh_exec(command, opts)
        options = { :user_known_hosts_file => '/dev/null' }.merge(opts)
        [:metadata, :uuid].each { |attr| options.delete(attr) }
        host = options.delete(:ipaddress)
        user = options.delete(:username)

        result = ""
        Net::SSH.start(host, user, options) do |ssh|
          result = ssh.exec!(command)
        end
        logger.debug "chef_client bootstrap output:\n---\n#{result}\n---"
        result
      end

      def ssh_command
        "bash -c '#{bootstrap_script}' |& tee /tmp/chef_client_init.log"
      end

      def bootstrap_script
        erb_template = File.join(File.dirname(__FILE__), "chef/bootstrap.sh.erb")
        script = ERB.new(IO.read(erb_template)).result(chef_context)
        logger.debug "chef_client bootstrap script:\n---\n#{script}\n---"
        script
      end

      def chef_context
        ProjectRazor::BrokerPlugin::Chef::Context.new(yaml_config.merge({
          :chef_server_url  => @servers.first,
          :chef_version     => @broker_version
        })).get_binding
      end

      def yaml_config
        yaml_file = File.join($razor_root, "conf/chef_client_#{@name}.yml")

        if File.exist?(yaml_file)
          logger.debug "Loading chef_client config from #{yaml_file}"
          config = YAML.load(IO.read(yaml_file))
        else
          logger.warn "chef_client config could not be loaded from #{yaml_file}"
          config = Hash.new
        end

        # convert string to keys to symbols
        Hash[config.map{|(k,v)| [k.to_sym,v]}]
      end
    end
  end
end
