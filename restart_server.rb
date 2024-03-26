`pkill -f puma`
exec('puma -C config/puma-localserver.rb &')
puts 'Puma server restarted.'
