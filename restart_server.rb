`pkill -f puma`
exec('puma -C config/puma-local.rb &')
puts 'Puma server restarted.'
