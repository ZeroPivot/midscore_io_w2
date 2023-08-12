# load "kill_server.rb"
exec('rerun --dir . -- "puma -C config/puma-nginx-production.rb"')
