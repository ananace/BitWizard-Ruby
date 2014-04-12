module BitWizard
	module Boards

		class FETs < Board

			attr_reader :num_FETs

			#Create an instance of a FET board
			#
			# @param [optional, Hash] options A Hash of options.
			# @option options [Number] :num The number of FETs on the board (3 or 7)
			def initialize(options={})
				options = {
					:num => 3,
					:bus => :spi
				}.merge(options)
				options = options.merge({
					:type => "#{options[:bus]}_#{options[:num]}fets".to_sym,
				})

				raise ArgumentError.new "Number of FETs must be 3 or 7" unless options[:num] == 3 or options[:num] == 7

				super(options)

				@num_FETs = options[:num]
			end

			#Enables Pulse Width Modulation on the specified port
			#
			# @param [Number|Array] port The port/ports to enable PWM on
			def pwm_enable(*port)
				case port.count
				when 0
					raise ArgumentError.new "wrong number of arguments"
				when 1
					port = port.first
				end

				if port.is_a? Array then
					port.each do |port|
						enablePWM! port
					end
					return true
				end
				raise ArgumentError.new "Port must be an integer between 1 and #{@num_FETs}" unless port.is_a? Fixnum and (1..@num_FETs).include? port

				port = 2**(port-1)

				curPWM = read(0x5f, 1)[0]
				tgtPWM = curPWM | port
				write(0x5f, tgtPWM)

				true
			end

			#Disables Pulse Width Modulation on the specified port
			#
			# @param [Number|Array] port The port/ports to disable PWM on
			def pwm_disable(*port)
				case port.count
				when 0
					raise ArgumentError.new "wrong number of arguments"
				when 1
					port = port.first
				end

				if port.is_a? Array then
					port.each do |port|
						disablePWM! port
					end
					return true
				end
				raise ArgumentError.new "Port must be an integer between 1 and #{@num_FETs}" unless port.is_a? Fixnum and (1..@num_FETs).include? port

				port = 2**(port-1)

				curPWM = read(0x5f, 1)[0]
				tgtPWM = curPWM & ~port
				write(0x5f, tgtPWM)

				true
			end

			#Returns the ports that have PWM enabled
			#
			# @return [Array] An array containing the port numbers with PWM enabled
			def pwm_enabled?
				curPWM = read(0x5f, 1)[0]

				ret = []
				(1..@num_FETs).each do |port|
					ret << port if curPWM & 2**(port-1) > 0
				end
				ret
			end

			#Checks if a port has PWM enabled
			#
			# @param [Number] port The port to check
			# @return [Boolean] Is the port enabled for PWM control
			def pwm_enabled?(port)
				pwm_enabled?.include? port
			end	

			#Read the current position of the stepper motor
			#
			# @return [Number] The current stepper position
			def stepper_position
				read(0x40, 4).pack("C*").unpack("l>")[0]
			end
			#Set the current position of the stepper motor, without actually moving it
			#
			# @param [Number] position The new position of the stepper motor
			def stepper_position=(position)
				raise ArgumentError.new "Position must be an integer" unless position.is_a? Fixnum

				write(0x40, [position].pack("l>"))
			end

			#Read the target position of the stepper motor
			#
			# @return [Number] The target position of the stepper
			def stepper_target
				read(0x41, 4).pack("C*").unpack("l>")[0]
			end
			#Set the target position of the stepper motor
			#
			# @param [Number] position The target position for the stepper motor
			def stepper_target=(position)
				raise ArgumentError.new "Position must be an integer" unless position.is_a? Fixnum

				write(0x41, [position].pack("l>"))
			end
			
			#Read the step delay of the stepper motor
			# 
			# @return [Number] The stepdelay in tenths of a millisecond
			def stepper_delay
				read(0x43, 1)[0]
			end
			#Set the step delay of the stepper motor
			#
			# @param [Number] delay The new stepdelay, in tenths of a millisecond (maximum 255 - 25ms between steps)
			def stepper_delay=(delay)
				raise ArgumentError.new "Delay must be an integer between 0 and 255" unless delay.is_a? Fixnum and (0..255).include? delay

				write(0x43, delay)
			end

			#Returns the PWM value on the specified port
			#
			# @param [Number] port The port to read the value from
			# @return [Number] The PWM value on the port (0..255)
			def [](port)
				raise ArgumentError.new "Port must be an integer between 1 and #{@num_FETs}" unless port.is_a? Fixnum and (1..@num_FETs).include? port

				return read(0x50 + (port-1), 1)[0]
			end

			#Sets the PWM value on the specified port
			#
			# @param [Number] port The port to set the value on
			# @param [Number] value The PWM value to set (0..255)
			def []=(port, value)
				raise ArgumentError.new "Port must be an integer between 1 and #{@num_FETs}" unless port.is_a? Fixnum and (1..@num_FETs).include? port
				raise ArgumentError.new "Value must be an integer between 0 and 255" unless value.is_a? Fixnum and (0..255).include? value

				write(0x50 + (port-1), value)
			end

		end

	end

	Known_Boards[/(spi|i2c)_3fets/] = {
		:default_address => 0x8a,
		:constructor => Proc.new { |options| BitWizard::Boards::FETs.new options.merge({ :num => 3 }) },
		:features => [ :inputs, :outputs, :stepper, :pwm ]
	}
	Known_Boards[/(spi|i2c)_7fets/] = {
		:default_address => 0x88,
		:constructor => Proc.new { |options| BitWizard::Boards::FETs.new options.merge({ :num => 7 }) },
		:features => [ :inputs, :outputs, :stepper, :pwm ]
	}

end