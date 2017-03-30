require 'spec_helper'
require 'evil-proxy'
require 'evil-proxy/har_store'
require 'json'
require 'uri'
require 'net/https'

# OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

Thread.abort_on_exception=true

module EvilProxy

  RSpec.describe "Storing HAR" do
    let(:server) {
        EvilProxy::MITMProxyServer.new(Port: 8080, Quiet: false)
    }

    before(:each) do
      Thread.new { server.start }
    end

    let(:store) { described_class.new }

    it "saves a request and response to a HAR entry" do
      # proxy = Net::HTTP::Proxy("localhost", 8080)
      # proxy.start(uri.host, uri.port) do |http|
      #   http.request(req)
      # end
      proxy_addr = 'localhost'
      proxy_port = 8080

      uri = URI.parse("https://google.com/")
      http = Net::HTTP.new(uri.host, uri.port, proxy_addr, proxy_port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      uri = URI.parse("https://google.com/")
      req = Net::HTTP::Get.new(uri.request_uri)

      http.request(req)

      server.dump_store

    end

    it "loads a har" do
      har = HAR::Archive.from_file("store.har")
      binding.pry
    end
  end
end
