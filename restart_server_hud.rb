load 'kill_server.rb'

exec('puma -C config/puma-nginx-production-hud.rb &')
puts 'Puma server restarted.'
