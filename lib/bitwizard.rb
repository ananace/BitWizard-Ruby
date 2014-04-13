require 'pi_piper'

module BitWizard

	class Board

		#Detects the type of board on the given address and creates the correct handler class for it.
		#
		# @param [Number] address The address to check.
		# @param [optional, Hash] options A Hash of options.
		# @option options [Symbol] :bus The type of bus the board is connected on. (:spi or :i2c)
		# @option options [Logger] :logger A logger you want to attach to the board.
		def Board.detect(options)
			options = {
				:address => -1,
				:bus => :spi,
				:logger => NullLogger.new
			}.merge(options).merge({
				:type => :auto_detect,
				:skip_check => false
			})

			options[:logger] = NullLogger.new unless options[:logger]

			temp = BitWizard::Board.new options
			correct = temp.known_board[:constructor].call(options.merge({:skip_check => true})) if temp.valid?

			correct.instance_variable_set(:@type, temp.type)
			correct.instance_variable_set(:@version, temp.version)
			correct.instance_variable_set(:@known_board, temp.known_board)

			correct
		end

		attr_reader :type, :version, :address, :bus, :known_board
		attr_accessor :logger

		#Creates a generic board handle for reading and writing directly.
		#
		# @param [Hash] options A hash of options.
		# @option options [Fixnum] :address The address of the board. (0x00..0xff)
		# @option options [Symbol] :type The board type, defaults to auto detecting. (identifier)
		# @option options [Symbol] :bus The bus it's connected to. (:spi or :i2c)
		# @option options [Boolean] :skip_check Skip the self check that runs on creation.
		# @option options [Logger] :logger Add a logger here to log data that's sent and received.
		def initialize(options)
			options = {
				:address => -1,
				:type => :auto_detect,
				:bus => :spi,
				:skip_check => false,
				:logger => NullLogger.new
			}.merge(options)

			raise ArgumentError.new "Bus must be :spi or :i2c." unless options[:bus] == :spi or options[:bus] == :i2c

			@logger = options[:logger]
			@address = options[:address]
			@type = options[:type]
			@bus = options[:bus]

			self_check! unless options[:skip_check]
		end

		#Returns if the board has a valid communication address
		def valid?
			return false if @address == -1 or @type == :auto_detect
			true
		end

		#Writes a value to the board, either a single byte or several in the form of a string
		#
		# @param [Number] reg The registry address to write to
		# @param [Number|String] value The data to write to the board
		def write(reg, value)
			raise ArgumentError.new "#{reg} is not a valid register, must be a number between 0x00..0xff" unless reg.is_a? Fixnum and (0..255).include? reg
			raise ArgumentError.new "#{value} is not a valid value, must be a single byte or a string" unless (value.is_a? Fixnum and (0..255).include? value) or (value.is_a? String)

			value = value.unpack("C*") if value.is_a? String
			return spi_write(reg, value) if @bus == :spi
			return i2c_write(reg, value) if @bus == :i2c
		end

		#Reads a value from the board
		#
		# @param [Number] reg The registry address to read from
		# @param [Number] count The number of bytes to read
		def read(reg, count)
			raise ArgumentError.new "#{reg} is not a valid register, must be a number between 0x00..0xff" unless reg.is_a? Fixnum and (0..255).include? reg

			return spi_read(reg, count) if @bus == :spi
			return i2c_read(reg, count) if @bus == :i2c
		end

		#Changes the boards address
		#
		# The new address needs to follow these criteria;
		#   * Must be a 8-bit number between 0x00 and 0xff
		#   * Must not have it's least significant bit set
		#
		# @param [Number] new_address The new address of the board
		def address=(new_address)
			raise ArgumentError.new "#{new_address} is not a valid address" unless new_address.is_a? Fixnum and (0..255).include? new_address and new_address|1 != new_address

			old_address = @address
			@address = new_address
			identifier = read(0x01, 20).pack("C*").split("\0")[0]
			@address = old_address

			Known_Boards.each do |name, data|
				if name =~ identifier then
					raise ArgumentError.new "Another board (#{identifier}) already exists on #{new_address}!"
				end
			end

			write 0xf1, 0x55
			write 0xf2, 0xaa
			write 0xf0, new_address

			@address = new_address
		end

		private

		class NullLogger
			def debug(*) end
		end

		#Performs a self check of the board
		#
		# This includes contacting the board and checking that it's of the correct type.
		def self_check!
			found_board = nil
			Known_Boards.each do |name, data|
				if name =~ @type then
					@address = data[:default_address] unless (0..255).include? @address
					found_board = {
						:name => name,
						:data => data
					}
					break
				end
			end
			raise ArgumentError.new "Don't know what board '#{@type}' is." if not found_board and @type != :auto_detect
			raise ArgumentError.new "Board type is 'auto_detect', but invalid address #{@address} given." if @type == :auto_detect and not (0..255).include? @address

			identifier = read(0x01, 20).pack("C*").split("\0")[0]
			raise ArgumentError.new "No response from board" if identifier.empty?

			if @type == :auto_detect then
				Known_Boards.each do |name, data|
					if name =~ identifier then
						@type, @version = *identifier.split
						@type = @type.to_sym
						@known_board = data
						break
					end
				end

				raise ArgumentError.new "No known board of type '#{identifier}'." if @type == :auto_detect and not identifier.empty?
			else
				Known_Boards.each do |name, data|
					if name =~ identifier then
						@version = identifier.split[1]
						@known_board = data
						raise ArgumentError.new "Board reports type #{real_name}, which does not match #{@type}" unless found_board[:data] == data
						break
					end
				end
			end

			true
		end

		def spi_write(reg, value)
			@logger.debug("SPI [0x#{@address.to_s(16)}] <-- 0x#{reg.to_s(16)}: #{value.is_a? Array and value.pack("C*").inspect or value.inspect}")
			PiPiper::Spi.begin do |spi|
				spi.write @address, reg, *value if value.is_a? Array
				spi.write @address, reg, value unless value.is_a? Array
			end
		end

		def spi_read(reg, count)
			data = PiPiper::Spi.begin do |spi|
				spi.write @address | 1, reg, *Array.new(count, 0)
			end[2..-1]
			@logger.debug("SPI [0x#{@address.to_s(16)}] --> 0x#{reg.to_s(16)}: #{data.pack("C*").inspect}")
			data
		end

		def i2c_write(reg, value)
			@logger.debug("I2C [0x#{@address.to_s(16)}] <-- 0x#{reg.to_s(16)}: #{value.is_a? Array and value.pack("C*").inspect or value.inspect}")
			PiPiper::I2C.begin do |i2c|
				data = [reg]
				data << value unless value.is_a? Array
				data += value if value.is_a? Array

				i2c.write({ :to => @address, :data => data })
			end
		end

		def i2c_read(reg, count)
			data = PiPiper::I2C.begin do |i2c|
				i2c.write({ :to => @address | 1, :data => [reg, *Array.new(count, 0)] })
				i2c.read count
			end
			@logger.debug("I2C [0x#{@address.to_s(16)}] --> 0x#{reg.to_s(16)}: #{data.pack("C*").inspect}")
			data
		end
	end

	#A list of boards the library knows how to handle.
	Known_Boards = {
		
	} unless defined? Known_Boards

end

Dir[File.dirname(__FILE__) + "/bitwizard/*.rb"].each { |file| require file }
