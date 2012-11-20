module ProjectRazor
  module BrokerPlugin
    module Chef
      class Context
        attr_reader :install_sh_url, :chef_version, :validation_key, :chef_bin

        def initialize(options)
          @install_sh_url         = options[:install_sh_url] ||
                                    "http://opscode.com/chef/install.sh"
          @chef_version           = options[:chef_version] ||
                                    ""
          @validation_key         = options[:validation_key]
          @chef_server_url        = options[:chef_server_url]
          @validation_client_name = options[:validation_client_name] ||
                                    "chef-validator"
          @bootstrap_environment   = options[:bootstrap_environment] ||
                                    "_default"
          @run_list               = Array(options[:run_list])
          @chef_bin               = options[:chef_bin] ||
                                    "chef-client"
        end

        def config_content
          <<-CONFIG.gsub(/^ {12}/, '')
            log_level               :info
            log_location            STDOUT
            chef_server_url         "#{@chef_server_url}"
            validation_client_name  "#{@validation_client_name}"
          CONFIG
        end

        def first_boot
          { :run_list => @run_list }
        end

        def start_chef
          "#{@chef_bin} -j /etc/chef/first-boot.json -E #{@bootstrap_environment}"
        end

        def get_binding
          binding
        end
      end
    end
  end
end
