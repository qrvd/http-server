require "socket"

def main

	# Internet socket over TCP
	socket = Socket.new(:INET, :STREAM)

	# Set an option on the socket itself, that makes it easy
	# to kill and restart it without complaints
	socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)

	# Here we'll be.
	socket.bind(Addrinfo.tcp("127.0.0.1", 9000))

	# Now listen. Number of incoming connections that can be
	# queued under the current one
	socket.listen(0)

	connections = []

	loop do
		# Now, block waiting for a connection.
		# We get a separate connection socket because we can
		# accept many simultaneously connections and communicate
		# with them separately.
		conn_sock, addr_info = socket.accept
		connections << Thread.new do
			conn = Connection.new(conn_sock)
			request = read_request(conn)
			respond_for_request(conn_sock, request)
			conn_sock.close
		end
	end

	connections.map(&:join)
end

class Connection

	def initialize(conn_sock)
		@conn_sock = conn_sock
		@buffer = ""
	end

	def read_line
		read_until("\r\n")
	end

	# Read up to this many bytes from the source, at a time.
	# We may receive less, which is dealt with in `read_until`.
	BUFFER_CHUNK_SIZE = 7

	def read_until(string)
		until @buffer.include?(string)

			# Read more than one byte at a time,
			# to not waste resources.
			@buffer += @conn_sock.recv(BUFFER_CHUNK_SIZE)
		end

		# Split into the piece we want, separated
		# by the rest. Split removes the separator from the result.
		result, @buffer = @buffer.split(string, 2)
		result
	end

end

def read_request(conn)
	request_line = conn.read_line
	method, path, version = request_line.split(" ")
	headers = {}

	# Read the headers
	loop do
		line = conn.read_line()
		if line.empty?
			break
		end

		# Not spec compliant (linear whitespace!) but whatevs.
		key, value = line.split(/:\s*/, 2)
		headers[key] = value
	end
	Request.new(method, path, headers)
end

Request = Struct.new(:method, :path, :headers)

def respond(conn_sock, status_code, content)
	status_text =
	{
		200 => "OK",
		404 => "Not Found"
	}.fetch(status_code)

	# No additional arguments, so 0.
	conn_sock.send("HTTP/1.1 #{status_code} #{status_text}\r\n", 0)
	conn_sock.send("Content-Length: #{content.length}\r\n", 0)
	conn_sock.send("\r\n", 0)
	conn_sock.send(content, 0)
end

def respond_for_request(conn_sock, request)

	# This is unsafe but it works.
	path = Dir.getwd + request.path

	if File.exists?(path)
		if File.executable_real?(path)
			content = `#{path}`
		elsif path.end_with? ".rb"
			content = `ruby #{path}`
		else
			content = File.read(path)
		end
		status_code = 200
	else
		status_code = 404
		content = ""
	end

	respond(conn_sock, status_code, content)
end

main