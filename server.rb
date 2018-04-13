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

	# Now, block waiting for a connection.
	# We get a separate connection socket because we can
	# accept many simultaneously connections and communicate
	# with them separately.
	conn_sock, addr_info = socket.accept

	# Read up to this many bytes from the source.
	# We may receive less, which needs to be dealt with.
	conn = Connection.new(conn_sock)
	p read_request(conn)
end

class Connection

	def initialize(conn_sock)
		@conn_sock = conn_sock
		@buffer = ""
	end

	def read_line
		read_until("\r\n")
	end

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

main