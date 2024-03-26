`pkill -f puma`
exec('puma -C config/puma-nginx-production-hud.rb &')
puts 'Puma server restarted.'
