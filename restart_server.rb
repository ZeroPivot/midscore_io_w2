load 'kill_server.rb'

exec('puma -C config/puma-nginx-production.rb &')
puts 'Puma server restarted.'
