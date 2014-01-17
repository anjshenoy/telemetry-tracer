#!/usr/bin/env ruby 


Dir["#{File.dirname(__FILE__)}/**/*_test.rb"].each { |testcase| load testcase }

