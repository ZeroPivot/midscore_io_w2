require 'discordrb'
my_bot = DIscordrb::Bot.new token: 'MTAyMzI1NjIzODkxNTU5NjQxMA.GVFN7f.ADyUvCV5A5DgEeGKoc5kDvF0NkbrPrO3ycrC7U',
                            prefix: '!'
p mybot.invite_url
my_bot.run true # true indicates that this bot is a "bot account", as opposed to a regular user account.
