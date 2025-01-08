# FAST NOTE: Use LineDB/the [managed partitioned array] for all aspects of gpt3.5 - 4 in the 'gpt4' POST route.
## DATE OF FAST NOTE: 2023/04/15 - April 15th, 2023 (on a Saturday).

#### QUICK NOTES:
# GPT 3.5+ SL CHATBOT USING The Ruby Programming Language's 'openai' gem.
# --------------------------------------------------------------------------------
# Ruby is by that Japanese Guy Matz, who is a genius, and the creator of Ruby which uses C in the lower level.
# --------------------------------------------------------------------------------
# First Updated and tested to pretty much work: 4/13/2023 - 2023-04-13 - April 13th, 2023 (on a Thursday).
# --------------------------------------------------------------------------------
## VERSION: 4.0.1a - SL.rb (second life chatbot and chat logger [to partitioned array/linedb])
# INFO: This is the main file for the SL chatbot and chat logger, located at /api/sl in the routing tree /api/sl/gpt4, to prepare for gpt3.5+.
# --------------------------------------------------------------------------------
# --------------------------------------------------------------------------------
## VERSION: 4.0.2a - REFER TO FAST NOTE; CHANGING AROUND PROMPTS
# TODO: Important: use LineDB (etc) like the Managed Partitoned Array to further integrate OpenAI with Second Life etc. WORK ON THIS ASAP AT HOME. (2023/04/15 - 11:59 AM)
## VERSION: 4.0.3a - REFER TO FAST NOTE; CHANGING AROUND PROMPTS
# FINISHED: Added "/openai: " (blank space too before the prompt and message (at the end)) to the prompt, so that it is easier to tell what is the prompt and what is the response.
# EXAMPLE: "/openai: Hello, how are you?" (prompt) "I am good, how are you?" (response)
require 'date'
require 'open-uri'
require 'nokogiri'
require 'json'
require 'base64'
require 'uri'
require 'oj'
require_relative 'log'



# require 'openuri'
# TODO: escape the messages, because when you have a \ in the string it will break the json
#

def escape(avatar_message)
  strings = avatar_message.split
  strings.each do |string|
    string.gsub!('\\', '\\\\\\\\') # Escape the escape character \
    string.gsub!(':', '\\:')
    string.gsub!('[', '\\[')
    string.gsub!(']', '\\]')
    string.gsub!('{', '\\{')
    string.gsub!('}', '\\}')
    string.gsub!("'", "\\'")
    string.gsub!('"', '\\"')
    string.gsub!('.', '\\.')
  end
  strings.join(' ')
end

def unescape(avatar_message)
  strings = avatar_message.split
  strings.each do |string|
    string.gsub!('\\\\\\\\', '\\') # Unescape the escape character \ first
    string.gsub!('\\:', ':')
    string.gsub!('\\[', '[')
    string.gsub!('\\]', ']')
    string.gsub!('\\{', '{')
    string.gsub!('\\}', '}')
    string.gsub!("\\'", "'")
    string.gsub!('\\"', '"')
    string.gsub!('\\.', '.')
  end
  strings.join(' ')
end

# https:://pokemon..com"
class CGMFS
  def list_by!; end

  def parse(key, value)
    "<b>#{key}</b> - #{value}"
  end

  hash_branch '/api', 'sl' do |r| # ss: screenshot
    @r = r
    log(" server called: #{r.path}")
    r.is 'view' do
      r.get do
        @area = r.params['simulator'] # work on params to gather only data from a specific location, pending a refactoring
        @captured_by = r.params['captured_by']
        view('sl_data', engine: 'html.erb', layout: 'layout.html')
      end
    end

    r.is 'get_numerology_of_combined_chat' do
      r.get do
        num_map = { a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 8, i: 9,
                    j: 1, k: 2, l: 3, m: 4, n: 5, o: 6, p: 7, q: 8, r: 9,
                    s: 1, t: 2, u: 3, v: 4, w: 5, x: 6, y: 7, z: 8 }
        # @area = r.params['simulator'] # work on params to gather only data from a specific location, pending a refactoring
        # @captured_by = r.params['captured_by']
        # database_arr = @@sl_db.data_arr
        numbers = 0
        0.upto(@@sl_db.max_partition_archive_id) do |archive_id|
          #log("loaded partition archive id #{archive_id}")
          @all = @@sl_db.load_from_archive!(partition_archive_id: archive_id)
          @all.data_arr.each do |hash|
            log("hash['message'] = #{hash['message']}")
            if (!hash['message'].nil? || hash['message'] != '') && !hash['message'].nil?
              numbers += convert_word_to_number(Base64.urlsafe_decode64(hash['message']), num_map)
            end
          end
        end
        @all = nil
        numbers.to_s
        # view('sl_data', engine: 'html.erb', layout: 'layout.html')
        #         =begin
        # loop do
        #  print 'Enter avatar name in one lowercase word: '
        #  search = gets.chomp
        #  puts "#{search.capitalize}'s number is: #{convert_word_to_number(search, num_map)}\n"
        #  print 'Reg Numerology Number: '
        # end
        #=end
      end
    end

    r.on 'add' do
      r.get do
        r.params.to_s
      end
      r.post do
        # log("server called: #{r.params}")
        @parsed_data = JSON.parse("[#{request.body.read}]")
        @message = ''
        @captured_by = ''
        @avatar_name = ''
        # @url_data = URI.extract(request.body.read)

        @parsed_data.each_with_index do |data, index|
          # log("upper level called")
          # log("@max_capacity #{@@sl_db.max_capacity}")
          # log("@data_arr size: #{@@sl_db.data_arr.size}")
          # log("@latest_id: #{@@sl_db.latest_id}")
          @message += unescape(Base64.urlsafe_decode64(data['message']))

          @captured_by = data['captured_by']
          @avatar_name = data['avatar_name'] # implement better version later

          #  log(@@telegram_logger.send_message("adding sl entry test"))

          #@@line_db
          #@@line_db["secondlife_ai"].pad(database_name: "secondlife_database", database_table: "secondlife_table")
          #@@line_db["secondlife_ai"].pad(database_name: "secondlife_database", database_table: "secondlife_table") do |hash|
          #  hash['timestamp'] = Time.at(data['timestamp']).utc.localtime('-07:00').to_s
          #  hash['avatar_name'] = data['avatar_name']
          #  hash['avatar_id'] = data['avatar_id']
          #  hash['message'] = @message
          #  hash['x_pos'] = data['x_pos']
          #  hash['y_pos'] = data['y_pos']
          #  hash['z_pos'] = data['z_pos']
          #  hash['sim_name'] = data['sim_name']
          #  hash['captured_by'] = @captured_by || 'not_implemented'
          #end
          #@@line_db["secondlife_ai"].pad(database_name: "secondlife_database", database_table: "secondlife_table").save_everything_to_file!
          log("SL_MESSAGE: #{@avatar_name}: #{@message}", filename: '/home/midscore_io/cgmfs/routes/sl/sl.log')

          # log("entry: #{entry}")

        end
      end
    end
  end
end
