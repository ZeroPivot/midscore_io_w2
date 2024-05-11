class CGMFS
  hash_branch 'r' do |r| # ss: screenshot
    r.hash_branches
    # these are the commands
    r.on 'admin' do
      r.is 'del' do
        r.get do
          @title = 'Delete URL'
          @r = r
          @url_to_delete = r.params['url_to_delete']
          @@line_db['urls_redir'].pad['urls_database', 'urls_table'].set(0) do |hash|
            temp = hash['url_name_title']
            temp.delete_if { |url| url[1] == @url_to_delete }
            hash['url_name_title'] = temp
          end
          @@line_db['urls_redir'].pad['urls_database', 'urls_table'].save_everything_to_files!
          r.redirect('/r/admin/view')
          #'del'
        end
        r.post do
        end
      end

      r.is 'view' do
        @r = r
        @title = 'List of URLS'
        r.get do
          view('r/view', engine: 'html.erb', layout: 'layout.html')
        end
      end
      r.is 'new' do
        # current = @@line_db['urls_redir'].pad['urls_database', 'urls_table'].get(0)
        # current = current['url_name_title']
        r.post do
          @@line_db['urls_redir'].pad['urls_database', 'urls_table'].set(0) do |hash|
            temp = hash['url_name_title']
            if temp.nil?
              temp = []
            end

            hash['url_name_title'] = temp << [r.params['whole_url_name'], r.params['url_string_title']]

          end
          @@line_db['urls_redir'].pad['urls_database', 'urls_table'].save_everything_to_files!
          r.redirect('/r/admin/view')
          # <label for="url_string_title">Url String Title:</label>
          #     <input type="text" id="url_string_title" name="url_string_title"><br><br>
          #
          #     <label for="lastName">Whole URL:</label>
          #     <input type="text" id="whole_url_name" name="whole_url_name"><br><br>
          #   </fieldset>
        end

        r.post do
        end
      end
    end
    # when it is any other string, it is a redirect
    r.on String do |s|
      r.get do
        traverse = @@line_db['urls_redir'].pad['urls_database', 'urls_table'].get(0)['url_name_title']
        traverse.each do |url|
          if url[1] == s
            # first line is a 5 character string of '-'s
            log("---------------\n(Click) Redirection for \"/r/#{url[1]}\" to #{url[0]}:", filename: "./db/r_redirs/url_shortened.log")
            log("BLOG_REDIR_LABEL: #{url[1]}", filename: "./db/r_redirs/url_shortened.log")
            log("BLOG_URL: #{url[0]}", filename: "./db/r_redirs/url_shortened.log")
            log("TIMESTAMP: #{Time.now}", filename: "./db/r_redirs/url_shortened.log")            
            log("PATH: https://#{r.host}#{r.path}", filename: "./db/r_redirs/url_shortened.log")
            log("REQUEST_IP: #{r.ip}", filename: "./db/r_redirs/url_shortened.log")
            log("REFERER: #{r.referer}", filename: "./db/r_redirs/url_shortened.log")
            log("REQUEST_USER_AGENT: #{r.user_agent}", filename: "./db/r_redirs/url_shortened.log")
            log("REQUEST_METHOD: #{r.request_method}", filename: "./db/r_redirs/url_shortened.log")
            log("REQUEST_PATH: #{r.path}", filename: "./db/r_redirs/url_shortened.log")
            log("REQUEST_HOST: #{r.host}", filename: "./db/r_redirs/url_shortened.log")
            log("REQUEST_PORT: #{r.port}", filename: "./db/r_redirs/url_shortened.log")
            log("REQUEST_URL: #{r.url}", filename: "./db/r_redirs/url_shortened.log")        
            log("REQUEST_QUERY_STRING: #{r.query_string}", filename: "./db/r_redirs/url_shortened.log")            
            log("---------------\n")
            @@telegram_logger.send_message("➿REDIRECTION➿ for \"/r/#{url[1]}\" to #{url[0]}:\nBLOG_REDIR_LABEL: #{url[1]}\nBLOG_URL: #{url[0]}\nTIMESTAMP: #{Time.now}\nPATH: https://#{r.host}#{r.path}\nREQUEST_IP: #{r.ip}\nREFERER: #{r.referer}\nREQUEST_USER_AGENT: #{r.user_agent}\nREQUEST_METHOD: #{r.request_method}\nREQUEST_PATH: #{r.path}\nREQUEST_HOST: #{r.host}\nREQUEST_PORT: #{r.port}\nREQUEST_URL: #{r.url}\nREQUEST_QUERY_STRING: #{r.query_string}")
            r.redirect(url[0])

          else
            log("#{url[0]}: /r/#{url[1]} found and skipped!", filename: "./db/r_redirs/url_shortened.log")
            #'404 not found'
          end
        end
        log("#{url[0]}: /r/:url not found", filename: "./db/r_redirs/url_shortened.log")
        '404 not found'
        # "#{traverse}"
        # r.redirect(@@line_db["urls_redir"].pad["urls_database", "urls_table"].get(0)["url_name_title"].first)
      end
    end
  end
end
