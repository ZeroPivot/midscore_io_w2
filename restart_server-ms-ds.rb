`pkill -f puma`
exec('puma -C config/puma-nginx-midscore-io-digitalocean.rb &')
puts 'Puma server restarted.'
