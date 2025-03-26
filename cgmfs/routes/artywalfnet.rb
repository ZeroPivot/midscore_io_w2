class CGMFS
  hash_branch 'artywalfnet' do |r| # ss: screenshot
    r.hash_branches
    r.is do
      r.get do
        log('-------------------')
        log('Artywalf.net -> hudl.ink:8080 Redirection Request:', filename: 'artywalf_redir.txt')
        log("request path: #{r.path} ; request host: #{r.host}", filename: 'artywalf_redir.txt')
        log("request hash: #{request.inspect}", filename: 'artywalf_redir.txt')
        log("request ip: #{request.ip}", filename: 'artywalf_redir.txt')
        log("request referrer: #{request.referrer}", filename: 'artywalf_redir.txt')
        log("request user_agent: #{request.user_agent}", filename: 'artywalf_redir.txt')
        log("AJAX request?: #{request.xhr?}", filename: 'artywalf_redir.txt')
        log("Timestamp: #{Time.now}", filename: 'artywalf_redir.txt')
        log('-------------------')
        if DO_TELEGRAM_LOGGING
          @@telegram_logger.send_message("[HTTPRequestRelay(artywalfnet)]:
          request path: #{r.path} ; request host: #{r.host}
          request ip: #{request.ip}
          request referrer: #{request.referrer || 'none'}
          request user_agent: #{request.user_agent}
          AJAX request?: #{request.xhr?}
          Timestamp: #{Time.now}
          ")
        end
        # @title = "ArityWolf-Midscore.io's HUDL.ink"
        # view('midscore_landing', engine: 'html.erb', layout: 'layout.html')
        r.redirect('https://furaffinity.net/user/artywalf')
        # view('artywalf_redirect', engine: 'html.erb', layout: 'layout.html')
      end
    end
  end
end
