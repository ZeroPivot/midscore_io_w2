# rubocop:disable Style/StringLiterals
# VERSION v0.0.1 - kejento.net edited edition
# EDITS: request_deflection(r) is disabled
require 'roda'
require 'json'
require 'fileutils'
require 'resolv'
require 'tzinfo'
require 'redcarpet'
require 'open-uri'
require 'openai'
require 'date'
require 'bigdecimal'
require 'free-image'
require 'fastimage'
require 'securerandom'
require 'uri'
require 'net/http'
require 'net/https'
require 'yuicompressor'
require 'roda/plugins/assets'


# require 'rack'
# require 'rack/csrf'
require_relative 'require_dir' # for route auto-loading
# Require the entire partitioned array library and managed partitioned array
LATEST_PA_VERSION = "v2.0.0-mpa_v1.2.6-pa_v1.0.0a-mpafc" # deprecated
# require_relative "lib/partitioned_array/#{LATEST_PA_VERSION}/requires" # partitioned array loading; loads the entire library
# require_relative "lib/partitioned_array/lib/managed_partitioned_array"
# require_relative "lib/partitioned_array/lib/file_context_managed_partitioned_array"
require_relative "lib/partitioned_array/lib/line_db" # magnum opus of computer science

require_relative 'lib/shortened/shortened_url' # shortened url class
require_relative "lib/loggers/telegram_logger"
require_relative 'logger'
require_dir "./lib/dir_requires"
# SERVER_IP = 'onemoonpla.net' # default host for now
# SERVER_IP_LOCAL = 'localhost'
# DOMAIN_NAME = 'https://onemoonpla.net'
DEBUG = false
LOCAL = false

## enable Resolv to use DNS (../views/layout.html.erb)
$dns_enabled = false # enable dns

SERVER_MAIN_DOMAIN_NAME = File.open("server_main_domain_name.txt", "r") { |f| f.read.chomp }

# how to zip a file in terminal
# zip -r archive_name.zip folder_to_compress

SERVER_IP = SERVER_MAIN_DOMAIN_NAME
SERVER_IP_LOCAL = 'localhost'
DOMAIN_NAME = "https://#{SERVER_MAIN_DOMAIN_NAME}"

$dog_blog_version = "v3.3.7.0 - Codename: \"The Stimky Sniffa\"" # used in layout.html.erb

DO_TELEGRAM_LOGGING = true # telegram logging

# redirect aritywolf.net to aritywolf's blog on onemoonpla.net; aritywolf.net already is a domain name on onemoonpla.net, among others you can find on digitalocean

class CGMFS < Roda
  # use Rack::Csrf, :check_only => [''], :raise => true
  PATHS_INCLUDE_CSRF = { '/api/screens/upload' => true, '/u/shorten' => true, '/api/file/upload' => true,
                         '/api/text/upload' => true }
  PUBLIC_URL_PATH = :static
  plugin :render, escape_html: false, escape: false
  plugin :multi_route
  plugin :all_verbs
  plugin :hash_routes
  plugin :not_found
  plugin :slash_path_empty
  plugin :public
  plugin :shared_vars
  plugin :exception_page

  plugin :error_handler
  plugin :sessions, secret: 'cgmfs3748w5yuieskrhfakgejgKAYUSGDYFHKGD&*R#at3wLKSGFHgfjgklsdfgjkl'
  plugin :route_csrf, check_request_methods: ['POST'], raise: true # , :check_header => false
  # Documentation: https://roda.jeremyevans.net/rdoc/classes/Roda/RodaPlugins/Assets.html
  # https://rubydoc.info/gems/roda-cj/1.0.3/Roda/RodaPlugins/Csrf
  plugin :assets, css: ['style.css', 'prism.css'], js: ['prism.js']
  compile_assets
  plugin :json
  plugin :json_parser

  # plugin :csrf, :raise=>true, :skip=>['POST:/api/screens']
  # <%= assets(:css) %>
  # <%= assets(:js) %>
  # # hot to fconfig user.name and user.email in git
  # git config --global user.name "John Doe"
  # git config --global user.email

  # PARTITION_AMOUNT = 2 # The initial, + 1
  # OFFSET = 1 # This came with the math, but you can just state the PARTITION_AMOUNT in total and not worry about the offset in the end
  # DB_SIZE = 6 # Caveat: The DB_SIZE is the total # of partitions, but you subtract it by one since the first partition is 0, in code.
  # PARTITION_ADDITION_AMOUNT = 5

  PARTITION_AMOUNT = 9 # The initial, + 1
  OFFSET = 1 # This came with the math, but you can just state the PARTITION_AMOUNT in total and not worry about the offset in the end
  DB_SIZE = 20 # Caveat: The DB_SIZE is th # Caveat: The DB_SIZE is the total # of partitions, but you subtract it by one since the first partition is 0, in code.
  PARTITION_ADDITION_AMOUNT = 2

  @@urls = ManagedPartitionedArray.new(endless_add: true, has_capacity: false, db_size: DB_SIZE,
                                       partition_amount_and_offset: PARTITION_AMOUNT + OFFSET, db_path: './db/url_shorten', db_name: 'url_slice')
  @@urls = @@urls.load_from_archive!
  # @@urls.load_last_entry_from_file!
  # @@urls.load_max_partition_archive_from_file!
  # @@urls.load_partition_archive_id_from_file!

  # TODO: add eo managedpartionedarray: an archiver that archives every entry and refreshes the partitions
  @@sl_db = ManagedPartitionedArray.new(max_capacity: "data_arr_size", db_size: DB_SIZE,
                                        partition_amount_and_offset: PARTITION_AMOUNT + OFFSET, db_path: "./db/sl", db_name: 'sl_slice')
  @@sl_db.allocate
  @@sl_db = @@sl_db.load_from_archive!

  @@test = ManagedPartitionedArray.new(max_capacity: "data_arr_size", db_size: DB_SIZE,
                                       partition_amount_and_offset: PARTITION_AMOUNT + OFFSET, db_path: "./db/sl2", db_name: 'sl_slice2')

  @@telegram_logger = TelegramLogger.new
  if DO_TELEGRAM_LOGGING
    @@telegram_logger.send_message("SERVER MESSAGE: Server has been [re-]started!\nTIME BOOTED: #{Time.now} (server time)")
  end
  # @@sl_db.load_last_entry_from_file!
  # @@sl_db.load_max_partition_archive_from_file!
  # @@sl_db.load_partition_archive_id_from_file!

  @@line_db = LineDB.new
  @@line_db["urls_redir"].pad.new_table!(database_name: "urls_database", database_table: "urls_table")
  @@line_db["blog"].pad.new_table!(database_name: "blog_database", database_table: "blog_table")
  @@line_db["user_blog_database"].pad.new_table!(database_name: "user_name_database",
                                                 database_table: "user_password_table")

  # https://github.com/alexrudall/ruby-openai
  # @@line_db["gpt4"].pad.new_table!(database_name: "gpt4_database", database_table: "gpt4_table")
  @@ai_client = OpenAI::Client.new(
    access_token: "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",
    request_timeout: 100
    # temperature: 0.5,
    # max_tokens: 100,
    # top_p: 1,
    # frequency_penalty: 0,
    # presence_penalty: 0,
    # stop: ["\n", " Human:", " AI:"]

  )

  a1 = Time.now
  @@line_db.databases.each do |db|
    a = Time.now
    puts "Loading database: #{db}..."
    puts '...Loading blog_table.'
    @@line_db[db].pad.new_table!(database_name: 'blog_database', database_table: 'blog_table')
    puts "...Loading blog_pinned_table."
    @@line_db[db].pad.new_table!(database_name: "blog_database", database_table: "blog_pinned_table")
    puts "...Loading blog_profile_table."
    @@line_db[db].pad.new_table!(database_name: "blog_database", database_table: "blog_profile_table")
    puts "...Loading blog_statistics_table."
    @@line_db[db].pad.new_table!(database_name: "blog_database", database_table: "blog_statistics_table")
    puts "...Loading gallery_database + gallery_table."
    @@line_db[db].pad.new_table!(database_name: "gallery_database", database_table: "gallery_table")
    puts "...Loading cache system database..."
    @@line_db[db].pad.new_table!(database_name: "cache_system_database", database_table: "cache_system_table")
    puts "Done."
    b = Time.now
    puts "Time taken to load #{db}: #{b - a} seconds."
  end
  a2 = Time.now
  puts "Done loading all databases and tables!"
  puts "Time taken to load all databases: #{a2 - a1} seconds."

  #   # start line_db's dog blog:: gallery system
  #   @@line_db_gallery = LineDB.new(parent_folder: "./db/dog_gallery", database_folder_name: "dog_gallery_db",
  #   database_file_name: "./db/dog_gallery/dog_gallery_users.db")
  #   @@line_db_gallery.databases.each do |db|
  #     # requirements for gallery_db:
  #     # gallery_database: contains hashes
  #     @@line_db_gallery[db].pad.new_table!(database_name: "gallery_database", database_table: "gallery_table")
  #     # for gallery statistics
  #     @@line_db_gallery[db].pad.new_table!(database_name: "gallery_statistics_database", database_table: "gallery_statistics_table")
  #     puts "Done loading gallery database: #{db}."
  #   end
  #   # end line_db's dog blog:: gallery system

  #  @@

  puts "Lambda database: #{@@line_db.databases}"
  # @line_db[line].pad.new_table!(database_name: "blog_database", database_table: "blog_table")
  # end

  not_found do
    # if honeypot check fails, redirect elswehere
    "error: 404"
  end

  require_dir './cgmfs/routes'
  route do |r|
    # log("request path: #{r.path} ; request host: #{r.host}")

    r.public
    r.assets # for public assets

    # log("route: #{r.path}")
    if r.path == PATHS_INCLUDE_CSRF[r.path] # Known bugs: if there is no slash at the end of the path, it will not work (will override check_csrf! checking)
      check_csrf!
    end
    r.hash_routes
  end
end
# rubocop:enable Style/StringLiterals

# Q: how do I clean my repository working tree?
# A:

# Q: how do I undo the last git command?
# A:
