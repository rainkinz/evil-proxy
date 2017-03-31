require 'yaml'
require 'har'
require 'nkf'
require 'zlib'
require 'stringio'
require 'mime/types'
require 'base64'

EvilProxy::MITMProxyServer.class_eval do
  attr_reader :store

  attr_reader :current_page

  def new_page(name)
    puts "ADDING NEW PAGE"
    # # TODO: Get the title and page timings
    # title = "Undefined"
    @page_started_at = Time.now
    @current_page = HAR::Page.new({
      :id => name,
      :started_date_time => iso8601(@page_started_at),
      :title => name,
      :page_timings => {}
    }, [])

    store.pages << @current_page
  end

  when_initialize do
    # clean_store
  end

  when_shutdown do
    # dump_store
  end

  before_request do |req|
    @started_date_time = Time.now
  end

  # Converts string +s+ from +code+ to UTF-8.
  def from_native_charset(s, code, ignore_encoding_error = false, log = nil)
    begin
      s.encode(code)
    rescue EncodingError => ex
      log.debug("from_native_charset: #{ex.class}: form encoding: #{code.inspect} string: #{s}") if log
      if ignore_encoding_error
        s.force_encoding(code)
      else
        raise
      end
    end
  end

  def iso8601(date)
    date.iso8601(3) #.gsub(/Z$/, 'z')
  end

  def detect_charset(src)
    if src
      NKF.guess(src) || Encoding::US_ASCII
    else
      Encoding::ISO8859_1.name
    end
  end

  def add_entry(req, res)
    content_type = res.header.fetch("content-type")
    mime_type = MIME::Types[content_type].first

    body, length = EvilProxy::Utils::Content.body_for_response(res)

    encoding = nil

    # TODO: there should always be body for a response right? 301?
    if body
      # if mime_type.binary?
      #   encoding = mime_type.encoding
      # else
      # TODO: Register parsers like mechanize does
      if mime_type.media_type == 'image'
        encoding = 'base64'
        body = Base64.encode64(body)
      else
        encoding = detect_charset(body)
        body = from_native_charset(body, encoding, true)
      end
    end

    query_string = req.query.map {|name, val|
      HAR::Record.new(:name => name, :value => val)
    }

    # TODO
    post_data = nil # HAR::PostData.new({})

    request = HAR::Request.new(
      :method => req.request_method,
      :url => req.request_uri.to_s,
      :http_version => req.http_version.to_s,
      :cookies => har_cookies(req),
      :headers => har_headers(req),
      :query_string => query_string,
      # :post_data => post_data,
      :headers_size => -1,
      :body_size => req.body ? req.body.bytesize : 0
    )

    content = HAR::Content.new(
      :mime_type => res.content_type,
      :encoding => encoding.to_s,
      # TODO
      # "compression": {"type": "integer"},
      :text => body,
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
      :pageref => current_page.id,
      :started_date_time => iso8601(@started_date_time),
      :time => Time.now - @started_date_time,
      :request => request,
      :response => response,
      :timings => {}, # TODO
      :cache => {} # TODO
    )

    puts "BEFORE RESPONSE SAVED HAR: #{req.request_uri}"
    store.entries << entry
    # puts "******************"
    # puts entry.to_json
    # puts "******************"
  end


  before_response do |req, res|
    add_entry(req, res)
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

  def store
    @store ||= clean_store
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
    HAR::Log.new(
      :version => EvilProxy::VERSION,
      :creator => {
        :name => "Evil",
        :version => EvilProxy::VERSION
      }
    )
  end

  def har
    har = HAR::Archive.new(
      :log => store
    )
  end

  def dump_store(filename = "store.har")
    # previous_store = YAML.load(File.read(filename)) || [] rescue []
    # File.open filename, "w" do |file|
    #   file.puts YAML.dump(previous_store + store_as_params)
    # end

    File.open(filename, 'w') do |file|
      file.puts har.to_json
    end
    # clean_store
  end

end
