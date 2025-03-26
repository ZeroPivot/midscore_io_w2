load 'kill_server.rb'

exec('puma -C config/puma-nginx-production-workers.rb &')
puts 'Puma server restarted.'
