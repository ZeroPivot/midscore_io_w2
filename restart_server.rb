`pkill -f puma`
exec('puma -C config/puma-nginx-mid.rb &')
puts 'Puma server restarted.'
