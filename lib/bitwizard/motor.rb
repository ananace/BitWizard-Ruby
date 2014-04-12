module BitWizard
	module Boards

		class Motor < Board

			#Create an instance of a Motor board
			#
			# @param [Hash] options A Hash of options.
			def initialize(options={})
				options = {
					:bus => :spi
				}.merge(options)
				options = options.merge({
					:type => "#{options[:bus]}_motor".to_sym,
				})

				super(options)
			end

			#Start spinning a motor on a specific port
			#
			# @param [Symbol] port The port to spin (:A or :B)
			# @param [Number] value The direction and speed of the motor (-255..255)
			def motor_start(port, value)
				raise ArgumentError.new("Port must be :A or :B") unless port == :A or port == :B
				raise ArgumentError.new("Value must be a number beween -255 and 255") unless (-255..255).include? value

				basereg = 0x20
				basereg = 0x30 if port == :B

				if value < 0 then
					write(basereg+1, -value)
				elsif value > 0 then
					write(basereg+1, value)
				else
					write(basereg+2, 1)
				end
			end

			#Stop spinning a motor on a specific port
			#
			# This is the same as running start_motor with the value 0
			#
			# @param [Symbol] port The port to stop (:A or :B)
			def motor_stop(port)
				raise ArgumentError.new "Port must be :A or :B" unless port == :A or port == :B

				motor_start(port, 0)
			end

			#Read the current position of the stepper motor
			#
			# @return [Number] The current stepper position
			def stepper_position
				read(0x40, 4).pack("l>")[0]
			end
			#Set the current position of the stepper motor, without actually moving it
			#
			# @param [Number] position The new position of the stepper motor
			def stepper_position=(position)
				write(0x40, [position].pack("l>"))
			end

			#Read the target position of the stepper motor
			#
			# @return [Number] The target position of the stepper
			def stepper_target
				read(0x41, 4).pack("l>")[0]
			end
			#Set the target position of the stepper motor
			#
			# @param [Number] position The target position for the stepper motor
			def stepper_target=(position)
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

			#Read a PWM value from a port
			#
			# @param [Symbol] port The port to read from (1..4)
			# @return [Number] The PWM value on the port
			def [](port)
				raise ArgumentError.new "Port must be an integer between 1 and 4" unless port.is_a? Fixnum and (1..4).include? port

				read(0x50+(port-1), 1)[0]
			end

			#Set a PWM value from a port
			#
			# @param [Number] port The port to set (1..4)
			# @param [Number] value The PWM value to set on the port (0..255)
			def []=(port, value)
				raise ArgumentError.new "Port must be an integer between 1 and 4" unless port.is_a? Fixnum and (1..4).include? port

				write(0x50+(port-1), value)
			end

		end

	end

	Known_Boards[/(spi|i2c)_motor/] = {
		:default_address => 0x90,
		:constructor => Proc.new { |options| BitWizard::Boards::Motor.new options },
		:features => [ :motor, :stepper, :pwm ]
	}

end