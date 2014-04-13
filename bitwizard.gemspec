Gem::Specification.new do |s|
	s.name = "bitwizard"
	s.version = "0.0.4"

	s.authors = [ "Alexander \"Ace\" Olofsson" ]
	s.date = "2014-04-12"
	s.summary = "Ruby library for BitWizard boards"
	s.description = "Ruby library for controlling the BitWizard boards over SPI and I2C"
	s.email = "ace@haxalot.com"
	s.homepage = "https://github.com/ace13/BitWizard-Ruby"
	s.executables << "bitwizardctl"
	s.files = [
		"lib/bitwizard.rb",
		*Dir["lib/bitwizard/*.rb"]
	]
	s.license = "MIT"

	s.add_runtime_dependency 'pi_piper'
end