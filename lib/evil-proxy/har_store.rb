require 'yaml'
require 'har'

EvilProxy::MITMProxyServer.class_eval do
  attr_reader :store

  when_initialize do
    clean_store
  end

  when_shutdown do
    # dump_store
  end

  before_request do |req|
    @started_date_time = Time.now
    puts "BEFORE REQUEST"
  end

  before_response do |req, res|

    # TODO: Get the title

    page = HAR::Page.new({
      :id => req.unparsed_uri,
      :started_date_time => @started_date_time.iso8601,
      :title => "undefined",
      :page_timings => []
    }, [])

    query_string = req.query.map {|name, val|
      HAR::Record.new(:name => name, :value => val)
    }

    # TODO
    post_data = nil # HAR::PostData.new({})

    request = HAR::Request.new(
      :method => req.request_method,
      :url => req.unparsed_uri,
      :http_version => req.http_version.to_s,
      :cookies => har_cookies(req),
      :headers => har_headers(req),
      :query_string => query_string,
      :post_data => post_data,
      :headers_size => -1,
      :body_size => req.body ? req.body.bytesize : 0
    )

    content = HAR::Content.new(
      :mime_type => res.content_type,
      # TODO
      :encoding => '',
      # TODO
      # "compression": {"type": "integer"},
      :text => res.body,
      :size => res.content_length
    )

    response = HAR::Response.new(
      :status => res.status,
      :status_text => res.status_line,
      :cookies => har_cookies(res),
      :headers => har_headers(res),
      # TODO: How do we handle this?
      # "redirectURL" : {"type": "string", "required": true},
      :redirect_url => '',
      :headers_size => -1,
      :body_size => res.body.bytesize,
      :http_version => res.http_version.to_s,
      :content => content
    )

    entry = HAR::Entry.new(
      :pageref => page.id,
      :started_date_time => @started_date_time.iso8601,
      :time => Time.now - @started_date_time,
      :request => request,
      :response => response,
      :timings => [], # TODO
      :cache => [] # TODO
    )

    puts "******************"
    puts entry.to_json
    @store.pages << page
    @store.entries << entry
    puts "******************"

    # @store << [ req, res ] if match_store_filter req, res
  end

  def har_cookies(r)
    r.cookies.each do |cookie|
      binding.pry
    end
  end

  def har_headers(r)
    r.header.map { |name, val| HAR::Record.new(:name => name, :value => Array(val).join(" ")) }
  end

  def store_filter &block
    @store_filter = block
  end

  def match_store_filter req, res
    return true unless @store_filter
    instance_exec req, res, &@store_filter
  end

  def clean_store
    # "log": {
    #     "type": "object",
    #     "properties": {
    #         "version": {"type": "string", "required": true},
    #         "creator": {"$ref": "creatorType", "required": true},
    #         "browser": {"$ref": "browserType", "required": true},
    #         "pages": {"type": "array", "items": {"$ref": "pageType"}},
    #         "entries": {"type": "array", "items": {"$ref": "entryType"}, "required": true},
    #         "comment": {"type": "string"}
    #     }
    # }
    @store = HAR::Log.new(
      :version => EvilProxy::VERSION,
      :creator => {
        :name => "Evil",
        :version => EvilProxy::VERSION
      }
    )

  end

  def dump_store(filename = "store.har")
    # previous_store = YAML.load(File.read(filename)) || [] rescue []
    # File.open filename, "w" do |file|
    #   file.puts YAML.dump(previous_store + store_as_params)
    # end

    har = HAR::Archive.new(
      :log => @store
    )
    File.open(filename, 'w') do |file|
      file.puts har.to_json
    end
    # clean_store
  end

end
