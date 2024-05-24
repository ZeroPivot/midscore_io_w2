require 'tzinfo'

# Get the current version from the file
current_version = File.read('version.txt').to_f

# Increment the version by 0.1
new_version = (current_version + 0.1).round(1).to_s

# Add the decimal point if necessary
new_version += '.0' unless new_version.include?('.')

# Write the new version to the file
File.open('version.txt', 'w') do |file|
  file.puts new_version
end

# Get the current timestamp
puts "Current version: #{current_version}"
puts "New version: #{new_version}"


# Get the current timestamp in Pacific Time
timezone = TZInfo::Timezone.get('America/Los_Angeles')
timestamp = timezone.now.strftime("%Y-%m-%d %H:%M:%S")
puts "Timestamp: #{timestamp} Pacific Time"

# Write the new version and timestamp to the file
File.open('version.txt', 'w') do |file|
  file.puts "#{new_version}"
  file.puts "#{timestamp}"
end
