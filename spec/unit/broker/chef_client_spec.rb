#!/usr/bin/env rspec
require 'spec_helper'
require 'project_razor/broker/chef_client'

describe ProjectRazor::BrokerPlugin::ChefClient do
  let(:klass) { ProjectRazor::BrokerPlugin::ChefClient }

  let(:ssh_connection) do
    stub("SSH connection").as_null_object
  end

  let(:options) do
    { :username => 'jdoe', :password => 'oops', :ipaddress => '172.16.0.1',
      :uuid => 'i-am-a-uuid', :metadata => Hash.new }
  end

  before do
    @plugin = klass.new({
      '@name' => 'staging',
      '@servers' => [ "https://chef.example.com:987", "http://nope.com" ],
      '@broker_version' => '20.12.2'
    })

    Net::SSH.stub(:start).and_yield(ssh_connection)
  end

  describe "#agent_hand_off" do
    before do
      @plugin.stub(:bootstrap_script)  { "fake_bootstrap" }
    end

    it "invokes the bootstrap over ssh" do
      ssh_connection.should_receive(:exec!).
        with("bash -c 'fake_bootstrap' |& tee /tmp/chef_client_init.log")
      @plugin.agent_hand_off(options)
    end

    it "returns :broker_success on successful bootstrap output" do
      ssh_connection.stub(:exec!) { "\n\nRazor chef bootstrap completed." }
      @plugin.agent_hand_off(options).should eq(:broker_success)
    end

    it "returns :broker_fail when successful output is missing" do
      ssh_connection.stub(:exec!) { "ack, fail, no!" }
      @plugin.agent_hand_off(options).should eq(:broker_fail)
    end

    describe "validation" do
      it "returns FalseClass if :username is not present" do
        options.delete(:username)
        @plugin.agent_hand_off(options).should eq(false)
      end

      it "returns FalseClass if :password is not present" do
        options.delete(:password)
        @plugin.agent_hand_off(options).should eq(false)
      end

      it "returns FalseClass if :ipaddress is not present" do
        options.delete(:ipaddress)
        @plugin.agent_hand_off(options).should eq(false)
      end
    end
  end

  describe "#ssh_exec" do
    before do
      ssh_connection.stub(:exec!) { "ssh output" }
    end

    it "passes ssh options to the session" do
      Net::SSH.should_receive(:start).with('172.16.0.1', 'jdoe',
        { :user_known_hosts_file => '/dev/null', :password => 'oops' })
      @plugin.ssh_exec("startitup", options)
    end

    it "returns the ssh output" do
      @plugin.ssh_exec("startitup", options).should eq("ssh output")
    end

    it "returns an empty result on Net::SSH exceptions" do
      Net::SSH.stub(:start) { raise "uh oh" }
      @plugin.ssh_exec("startitup", options).should be_empty
    end
  end

  describe "#bootstrap_script" do
    it "renders the template containing a chef command at the end" do
      @plugin.bootstrap_script.should match(
        %r{^chef-client -j /etc/chef/first-boot.json -E _default$})
    end

    it "uses the first server in @server as the chef server url" do
      @plugin.bootstrap_script.should match(
        %r{^chef_server_url\s+"https://chef\.example\.com:987"$})
    end

    it "uses @broker_version as the chef version" do
      @plugin.bootstrap_script.should match(
        %r{^version_string="-v 20\.12\.2"$})
    end
  end
end
