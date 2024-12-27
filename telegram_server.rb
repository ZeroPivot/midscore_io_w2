require 'telegram_bot'

bot = TelegramBot.new(token: '5641593028:AAHzTWyj2f-P4WalK3gUFSV061cqsYvjrMk')
channel_id = TelegramBot::Channel.new(id: '-1001852752618') # Midscore IO API group
message = TelegramBot::OutMessage.new
message.chat = channel_id

loop do
  message = bot.get_updates.last
  if message.text == '/start'
    message.text = "Hello, #{message.from.first_name}"
    message.send_with(bot)
  end
end
# loop do
# bot.get_updates(fail_silently: true).each do |message|
#   puts "@#{message.from.username}: #{message.text}"
#   command = message.get_command_for(bot)
#
#   message.reply do |reply|
#     case command
#     when /\/start/i
#       reply.text = "Hi, #{message.from.first_name}!"
#     when /\/stop/i
#       reply.text = "Bye, #{message.from.first_name}!"
#     else
#       reply.text = "Sorry, #{message.from.first_name}. I don't understand #{command}."
#     end
#     reply.send_with(bot)
#   end
# end
# end
# Path: telegram_server.rb
