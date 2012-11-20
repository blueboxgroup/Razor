#!/usr/bin/env rspec
require 'project_razor/broker/chef/context'

describe ProjectRazor::BrokerPlugin::Chef::Context do
  let(:klass) { ProjectRazor::BrokerPlugin::Chef::Context }

  before do
    @options = {
      :install_sh_url => "http://mirror.example.com/install.sh",
      :chef_version => "10.16.2",
      :validation_key => "valkeyffff",
      :chef_server_url => "https://chef.example.com:843",
      :validation_client_name => "mycorp-validator",
      :run_list => [ "role[cool_beans]" ]
    }
    @context = klass.new(@options)
  end

  describe "#install_sh_url" do
    it "returns the url" do
      @context.install_sh_url.should eq(
        "http://mirror.example.com/install.sh")
    end

    it "defaults to the opscode url" do
      @options.delete(:install_sh_url)
      klass.new(@options).install_sh_url.should eq(
        "http://opscode.com/chef/install.sh")
    end
  end

  describe "#chef_version" do
    it "returns the version" do
      @context.chef_version.should eq("10.16.2")
    end

    it "generates an empty string when not initialized with a version" do
      @options.delete(:chef_version)
      klass.new(@options).chef_version.should be_empty
    end
  end

  describe "#validation_key" do
    it "returns the validation key string" do
      @context.validation_key.should eq("valkeyffff")
    end
  end

  describe "#config_content" do
    it "generates config content containing a log_level" do
      @context.config_content.should match(/^log_level\s+/)
    end

    it "generates config content containing a log_location" do
      @context.config_content.should match(/^log_location\s+/)
    end

    it "generates config content containing a chef_server_url" do
      @context.config_content.should match(%r{^chef_server_url\s+"https://chef\.example\.com:843"$})
    end

    it "generates config content containing a validation_client_name" do
      @context.config_content.should match(%r{^validation_client_name\s+"mycorp-validator"$})
    end

    it "generates config content containing a validation_client_name defaulting to chef-validator" do
      @options.delete(:validation_client_name)
      klass.new(@options).config_content.should match(%r{^validation_client_name\s+"chef-validator"$})
    end
  end

  describe "#first_boot" do
    it "generates a hash containing the run_list" do
      @context.first_boot[:run_list].should eq(["role[cool_beans]"])
    end

    it "generates a hash defaulting to an empty run_list" do
      @options.delete(:run_list)
      klass.new(@options).first_boot[:run_list].should eq([])
    end
  end

  describe "#start_chef" do
    it "generates a chef command string" do
      @context.start_chef.should eq(
        "chef-client -j /etc/chef/first-boot.json -E _default")
    end

    it "generates a chef command string given a custom binary" do
      @options[:chef_bin] = "/opt/chef/bin/chef-solo"
      klass.new(@options).start_chef.should eq(
        "/opt/chef/bin/chef-solo -j /etc/chef/first-boot.json -E _default")
    end

    it "generates a chef command string given a custom environment" do
      @options[:bootstrap_environment] = "production"
      klass.new(@options).start_chef.should eq(
        "chef-client -j /etc/chef/first-boot.json -E production")
    end
  end
end
