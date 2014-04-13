BitWizard-Ruby [![Gem Version](https://badge.fury.io/rb/bitwizard.svg)](http://badge.fury.io/rb/bitwizard)
==============

Ruby library for controlling the BitWizard boards (over both SPI and I2C, though only SPI is tested for now)

Installation
------------

Just run ```# gem install bitwizard``` as root to install the library.


Examples
-------

Reading PWM values from a spi_3fets board would be something as simple as;
```ruby
require 'bitwizard'

board = BitWizard::Board.detect :address => 0x8a
puts "#{board.type}:"
(1..3).each do |i|
  puts "  #{board[i]}"
end
```

If you want to use the i2c version of the board all you would have to do is add ```:bus => :i2c```
```ruby
board = BitWizard::Board.detect :address => 0x8a, :bus => :i2c
```

You can also use the ```bitwizardctl``` utility to perform simple actions without writing your own software, things like;
 - Reading/Writing PWM values
 - Getting/Setting stepper position/target/delay
 - Spinning/Stopping motors
