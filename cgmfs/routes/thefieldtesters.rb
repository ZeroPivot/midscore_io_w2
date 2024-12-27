class CGMFS
    hash_branch 'the-field-testers' do |r| # ss: screenshot
      r.hash_branches
      r.is do
        r.get do
          log('-------------------')
          log('THE FIELD TESTERS (REDIR REQUEST):', filename: 'thefieldtesters_redir.txt')
          log("request path: #{r.path} ; request host: #{r.host}", filename: 'thefieldtesters_redir.txt')
          log("request ip: #{request.ip}", filename: 'thefieldtesters_redir.txt')
          log("request *REFERRER*: #{request.referrer}", filename: 'thefieldtesters_redir.txt')
          log("request user_agent: #{request.user_agent}", filename: 'thefieldtesters_redir.txt')
          log("request params: #{request.params}", filename: 'thefieldtesters_redir.txt')

          log("Timestamp: #{Time.now}", filename: 'thefieldtesters_redir.txt')
          log('-------------------')
          if DO_TELEGRAM_LOGGING
            @@telegram_logger.send_message("[HTTPRequestRelay(THEFIELDTESTERS_REDIRECT)]:
            request path: #{r.path};
            request host: #{r.host};
            request ip: #{request.ip};
            request referrer: #{request.referrer || 'none'};
            request user_agent: #{request.user_agent};\n\n
            request params: #{request.params.to_s}
            ")
          end
          # @title = "ArityWolf-Midscore.io's HUDL.ink"
          # view('midscore_landing', engine: 'html.erb', layout: 'layout.html')
          r.redirect('https://thefieldtesters.net/')
          # view('artywalf_redirect', engine: 'html.erb', layout: 'layout.html')
        end
      end
    end
  end
  