load 'kill_server.rb'

exec('puma -C config/puma-localserver.rb &')
puts 'Puma server restarted.'
