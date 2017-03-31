require 'zlib'
require 'stringio'
require 'mime/types'

module EvilProxy

  module Utils

    #
    # Utilities for handling content
    #
    module Content
      extend self

      def content_length(body_io)
        case body_io
        when Tempfile, IO then
          body_io.stat.size
        else
          body_io.length
        end
      end

      def body_for_response(response)
        body_io = StringIO.new(response.body)
        length = response.content_length || content_length(body_io)
        return body_io, 0 if length == 0

        content_encoding = response.header['content-encoding']
        out_io = case content_encoding
                 when nil, 'none', '7bit', "" then
                   body_io
                 when 'deflate' then
                   content_encoding_inflate(body_io)
                 when 'gzip', 'x-gzip' then
                   content_encoding_gunzip(body_io)
                 else
                   raise EvilProxy::Error,
                     "unsupported content-encoding: #{content_encoding}"
                 end

        out_io.flush
        out_io.rewind

        return out_io.read, length
      rescue Zlib::Error => e
        message = "error handling content-encoding #{response.header['content-encoding']}"
        message << " #{e.message} (#{e.class})"
        raise EvilProxy::Error, message
      ensure
        if Tempfile === body_io and
          (StringIO === out_io or (out_io and out_io.path != body_io.path)) then
          body_io.close!
        end
      end

      def content_encoding_gunzip(body_io)
        zio = Zlib::GzipReader.new(body_io)
        out_io = auto_io 'mechanize-gunzip', 16384, zio
        zio.finish

        return out_io
      rescue Zlib::Error => gz_error
        log.warn "unable to gunzip response: #{gz_error} (#{gz_error.class})" if
        log

        body_io.rewind
        body_io.read 10

        begin
          log.warn "trying raw inflate on response" if log
          return inflate body_io, -Zlib::MAX_WBITS
        rescue Zlib::Error => e
          log.error "unable to inflate response: #{e} (#{e.class})" if log
          raise
        end
      ensure
        # do not close a second time if we failed the first time
        zio.close if zio and !(zio.closed? or gz_error)
        body_io.close unless body_io.closed?
      end

			##
			# Creates a new output IO by reading +input_io+ in +read_size+ chunks.  If
			# the output is over the max_file_buffer size a Tempfile with +name+ is
			# created.
			#
			# If a block is provided, each chunk of +input_io+ is yielded for further
			# processing.
			def auto_io(name, read_size, input_io)
				out_io = StringIO.new.set_encoding(Encoding::BINARY)

				until input_io.eof? do
					if StringIO === out_io and use_tempfile? out_io.size then
						new_io = make_tempfile name
						new_io.write out_io.string
						out_io = new_io
					end

					chunk = input_io.read read_size
					chunk = yield chunk if block_given?

					out_io.write chunk
				end

				out_io.rewind

				out_io
			end

			def inflate(compressed, window_bits = nil)
				inflate = Zlib::Inflate.new window_bits

				out_io = auto_io('evil-inflate', 1024, compressed) do |chunk|
					inflate.inflate chunk
				end

				inflate.finish

				out_io
			ensure
				inflate.close if inflate.finished?
			end

		end


	end
end
