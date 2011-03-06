$0 = "puppetmasterd"
require 'puppet'

ARGV << "--rack"
require 'puppet/application/puppetmasterd'
run Puppet::Application[:puppetmasterd].run
