#!/usr/bin/env ruby
require 'json'
require 'open3'
require 'rubygems/version'

# Use an explicit Developer directory, not the runner image's default symlink.
xcodes = Dir.glob('/Applications/Xcode_*.app').filter_map do |path|
  version = File.basename(path).match(/\AXcode_(\d+(?:\.\d+)*)\.app\z/)
  [Gem::Version.new(version[1]), path] if version
end
abort 'No stable versioned Xcode installation found' if xcodes.empty?
_, xcode = xcodes.max_by { |version, path| [version, path] }
developer = "#{xcode}/Contents/Developer"
ENV['DEVELOPER_DIR'] = developer
output, status = Open3.capture2('xcrun', 'simctl', 'list', '--json')
abort 'Cannot inspect installed simulators' unless status.success?
inventory = JSON.parse(output)
candidates = inventory.fetch('runtimes').filter_map do |runtime|
  next unless runtime['isAvailable'] && runtime['identifier'].include?('.iOS-')
  phones = inventory.fetch('devices').fetch(runtime['identifier'], []).select do |device|
    device['isAvailable'] && device['name'].start_with?('iPhone')
  end
  next if phones.empty?
  # Prefer Pro, then the newest numbered model; never rely on JSON ordering.
  phone = phones.max_by do |device|
    [device['name'][/iPhone (\d+)/, 1].to_i, device['name'].include?('Pro') ? 1 : 0,
     device['name'], device['udid']]
  end
  [Gem::Version.new(runtime.fetch('version')), runtime, phone]
end
abort 'No available iPhone on an installed iOS runtime' if candidates.empty?
_, runtime, phone = candidates.max_by { |version, _, _| version }
puts "Selected #{xcode}: #{phone['name']} / iOS #{runtime['version']} / #{phone['udid']}"
system('xcodebuild', '-version') || abort('Cannot inspect selected Xcode')
File.open(ENV.fetch('GITHUB_ENV'), 'a') do |file|
  file.puts "DEVELOPER_DIR=#{developer}"
  file.puts "SIMULATOR_ID=#{phone['udid']}"
end
