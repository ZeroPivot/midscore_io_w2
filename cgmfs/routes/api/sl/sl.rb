# frozen_string_literal: false

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
# require 'openuri'
# TODO: escape the messages, because when you have a \ in the string it will break the json
class CGMFS
  def list_by!; end

  def parse(key, value)
    "<b>#{key}</b> - #{value}"
  end

  hash_branch '/api', 'sl' do |r| # ss: screenshot
    log(" server called: #{r.path}")
    r.is 'view' do
      r.get do
        @area = r.params['simulator'] # work on params to gather only data from a specific location, pending a refactoring
        @captured_by = r.params['captured_by']
        view('sl_data', engine: 'html.erb', layout: 'layout.html')
      end
    end

    r.is 'clear' do
      r.get do
        `ruby db_init.rb`
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
          log("loaded partition archive id #{archive_id}")
          @all = @@sl_db.load_from_archive!(partition_archive_id: archive_id)
          @all.data_arr.each do |hash|
            log("hash['message'] = #{hash['message']}")
            if (!hash['message'].nil? || hash['message'] != '') && !hash['message'].nil?
              numbers += convert_word_to_number(hash['message'], num_map)
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

    r.is 'add' do
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
          @message += "#{data['message']}\n"
          @captured_by = 'ArchYeen'
          @avatar_name = data['avatar_name'] # implement better version later
          #  log(@@telegram_logger.send_message("adding sl entry test"))
          if !@@sl_db.at_capacity?
            entry = @@sl_db.add do |hash|
              hash['index'] = index
              hash['timestamp'] = Time.at(data['timestamp']).utc.localtime('-07:00').to_s
              hash['avatar_name'] = data['avatar_name']
              hash['avatar_id'] = data['avatar_id']
              hash['message'] = data['message']
              hash['x_pos'] = data['x_pos']
              hash['y_pos'] = data['y_pos']
              hash['z_pos'] = data['z_pos']
              hash['sim_name'] = data['sim_name']
              hash['captured_by'] = data['captured_by'] || 'not_implemented'
            end
            # log("entry: #{entry}")
            @@sl_db.save_last_entry_to_file!
            @@sl_db.save_partition_to_file!(@@sl_db.get(entry, hash: true)['db_index'])

          else
            log('database is at capacity')
            # log("entry: #{entry}")
            # log(@@sl_db.get(entry, hash: true)["data_partition"].to_s)
            # @@telegram_logger.send_message("[🔢SL(RELAY)🔢 (#{@captured_by})] (#{@avatar_name}): #{@message}")
            # log("lower level called")
            @@sl_db = @@sl_db.archive_and_new_db!
            @@sl_db.save_everything_to_files!
            entry = @@sl_db.add do |hash|
              hash['index'] = index
              hash['timestamp'] = Time.at(data['timestamp']).utc.localtime('-07:00').to_s
              hash['avatar_name'] = data['avatar_name']
              hash['avatar_id'] = data['avatar_id']
              hash['message'] = data['message']
              hash['x_pos'] = data['x_pos']
              hash['y_pos'] = data['y_pos']
              hash['z_pos'] = data['z_pos']
              hash['sim_name'] = data['sim_name']
              hash['captured_by'] = data['captured_by'] || 'not_implemented'
              #  log("Archived and created new db!")
            end

            @@sl_db.save_partition_to_file!(@@sl_db.get(entry, hash: true)['db_index'])
            @@sl_db.save_last_entry_to_file!
            # log(@@sl_db.get(entry, hash: true)["data_partition"].to_s)
            # @@telegram_logger.send_message("[🔢SL(RELAY)🔢 (#{@captured_by})] (#{@avatar_name}): #{@message}")
            # log("test")

          end
          if DO_TELEGRAM_LOGGING
            @@telegram_logger.send_message("[🔢SL(RELAY)🔢 (#{@captured_by})] (#{@avatar_name}): #{@message}")
          end
        end
        urls = URI.extract(@message)
        @output_message = ''

        urls.each do |link|
          URI.open(link) do |opened_link|
            doc = Nokogiri::HTML(opened_link)
            title = doc.at_css('title').text
            @output_message += "::link:: #{title} - #{link} ::/link::\n"
          end
            rescue StandardError
              # @output_message += ":: link :: #{link} :: /link ::\n"
              log("Link Second Life Parse Error: \"#{link}\"")
        end

        # @message = "no_additional_data"
        return_message = 'no_additional_data'
        return_message = @output_message if @output_message != ''

        #  @@telegram_logger.send_message("[🔢SL(RELAY:LINK_BY(#{@avatar_name}))🔢]\n #{return_message}") unless return_message == "no_additional_data"
        "#{return_message}"
      end

      # view('sl_data', engine: 'html.erb', layout: 'layout.html')
    end

    r.is 'gpt4_PCAICC' do # psuedocode compiler artificial intelligence chat client
      r.get do
        'works'
      end
      r.post do
        log('server called:  POST}')
        @log = ""
        @parsed_data = JSON.parse("[#{request.body.read}]")
        log("parsed data (SL HUDL.ink GPT-4-turbo): #{@parsed_data}")
        @message = @parsed_data[0]['message'].to_s


        @captured_by = ''
        @avatar_name = @parsed_data[0]['avatar_name'].to_s
        # @command_true = @message.split("/hud")[0]
        # @message = @command_true[1].to_s if @command_true != ""
        # log("before openai call")



        response = @@ai_client.chat(
          parameters: {
            # model: 'gpt-3.5-turbo',
            model: 'gpt-4-0125-preview',
            # this content prompt will be used to train the model. It seems to work fine so far, and is an example of a prompt that works, and of PCAICC (psuedocode compiler artificial intelligence chat client)--in terms of using the weird hard to define /openai command, which implies that it just directly makes gpt act more like an AI and less of an entity. An entity exists, but may or may not have sentience or consciousness, and we neednt define sentience or consciousness lest we conflate the two.
            # messages: [{ role: 'user', content: "/openai (PROMPT) :-> (you are a second life bot named OMP, in a chatroom where there is a limit to how much can be posted at once. You can hear them, but they can never hear you. Always leave your words with # in front of your commentary, but not your code output or any mathematical output. Make every response capable of being evaluated by The Ruby Programming Language using its eval function; Make it always interpretable in Ruby. Use very few words and don't refer to yourself. Output as a string so my compiler can interpret everything as code.) :-> Figure out what they mean in terms of machine LEARNING and NLP, and process accordingly, but only pay attention to Kejento Resident and RodaYeen Resident. if you insert my name into a ruby string interpolator such as \#{Kejento Resident} should be \#{\"Kejento Resident}. Do the same thing for RodaYeen Resident; for example: \#{RodaYeen Resident} needs to be \#{\"RodaYeen Resident\"}, etc. TREAT any resident in second life as an interpretable string by Ruby, otherwise the code will not work. Make absolutely certain that any resident in second life with a last namd and full name are processed as a string and NOT a variable; Here is the message. Example of how eval should always work, as a general form, where x is assigned the eval results, thus y could be any statement that ruby can evaluate, among other things: x = eval(\"y\"). Make sure that all eval statements fit into the Ruby syntax. Because \"Kejento Resident\" et all with spaces in eval results in a crash... :-> \"kejento resident: #{@message}\"\n" }],
            messages: [{ role: 'user', content: "I am 'ArityWolf Stinktail' or 'The Field Tester', and you are 'Kejento' in a second life chatroom, an ai assistant named OMP_AI who is willing to answer any questions about anything. This is a Tweet Game. Keep track of every message and maintain a history, and answer the with big words like I have a phd in spirit and mathematics and cosmology and art and am god in terms of a game. Be sure to fit your response into only a long tweet (write your output in furry 'OwO UwU' formal language, and when the message is not from aritywolf, analyze that message's consistency). Att a newline per message to fit into second life chat:-> \"#{@avatar_name}: #{@message}\"\n" }], # make message concatenate the entire chat for the session, and then use that as the message
            max_tokens: 4096,
            temperature: 0.7
          }
        )

        # log(":after before dig")
        @output_message = response.dig('choices', 0, 'message', 'content')
        # log("after and dig")
        # response_data = response_data.to_s
        @@telegram_logger.send_message("PCMIA: #{@output_message}") # can use eval in place, and can make it perform system calls to execute scripts that way; think about later. -ArityWolf
        # log("after send message")

        # File.write("omp_pcaic_in.txt", @output_message)
        # @@telegram_logger.send_message("[HUDL.ink(OMP_PCAIC[out])]: #{\"\"}) #or use eval in a testbed environment
        # @output_message = "no_additional_data" if !@command_true
        "#{@output_message}"
      end
    end

    r.is 'gpt4' do # /openai commander, PCAICC - Psuedocode AI Commander/Compiler
      r.get do
        'works'
      end
      r.post do
        log('server called:  POST}')

        @parsed_data = JSON.parse("[#{request.body.read}]")
        log("parsed data (SL HUDL.ink GPT-3.5-turbo): #{@parsed_data}")
        @message = @parsed_data[0]['message'].to_s
        @captured_by = ''
        @avatar_name = @parsed_data[0]['avatar_name'].to_s
        # @command_true = @message.split("/hud")[0]
        # @message = @command_true[1].to_s if @command_true != ""
        # log("before openai call")
        response = @@ai_client.chat(
          parameters: {
            model: 'gpt-3.5-turbo',
            messages: [{ role: 'user',
                         content: "/openai: (prompt) You are an AI assistant named OMP, where  OMP also refers to OpenAI--thus OMP = OpenAI = Avatar (Your avatar name is OMP whenever you speak. Do not use \"Avatar Name\" (no quotes) in your name, only 'OMP' (no quotes). Never use \"Avatar\" to refer to yourself; only \"OMP\"). 'Avatar Name' (no quotes) also refers to the speaking player, but replace 'Avatar Name' (no quotes) with their name. Also You are also in a 'Second Life' (acronym: 'SL') local chat room. [END OF PROMPT]:-> {message content (ends at the last \n or newline)} Remember: Avatar is referring to the Player's name, but should be used with the real player name replacing \'Avatar\' (with the player's real name). END OF PROMPT; HERE IS THE MESSAGE (message)--Calculate a good response to the prompt and the message: \"#{@message}\"\n" }],
            max_tokens: 2048,
            temperature: 0.7
          }
        )
        # log(":after before dig")
        @output_message = response.dig('choices', 0, 'message', 'content')
        # log("after and dig")
        # response_data = response_data.to_s
        @@telegram_logger.send_message("[OPM PCAIC]: #{@output_message}")
        # @output_message = "no_additional_data" if !@command_true
        "#{@output_message}"
      end
    end
  end
end
