#!/usr/bin/env ruby

def rvm_installed?
  system('command -v rvm >/dev/null 2>&1')
end

def install_rvm
  return if rvm_installed?
  puts 'Installing RVM...'
  system('gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB')
  system('curl -sSL https://get.rvm.io | bash -s stable')
  puts 'RVM installed successfully!'
  puts 'Please close and reopen your terminal, then rerun this script to continue.'
  exit
end

def install_ruby_versions
  puts 'Installing commonly used Ruby versions...'
  %w[2.7 3.0 3.1 3.2].each do |version|
    puts "Installing Ruby #{version}..."
    system("bash -c 'source ~/.rvm/scripts/rvm && rvm install ruby-#{version}'")
  end
end

def setup_default_ruby
  puts 'Setting default Ruby version to 3.2...'
  system("bash -c 'source ~/.rvm/scripts/rvm && rvm use 3.2 --default'")
end

# Main installation process
begin
  install_rvm
  puts 'Would you like to install Ruby versions now? (y/n)'
  if gets.strip.downcase == 'y'
    install_ruby_versions
    setup_default_ruby
    puts "Installation complete! Run 'source ~/.rvm/scripts/rvm' to start using RVM."
  end
rescue StandardError => e
  puts "An error occurred: #{e.message}"
end
