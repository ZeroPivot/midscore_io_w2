class CGMFS
  hash_branch 'simulatorwolfnet' do |r| # ss: screenshot
    r.hash_branches
    r.is do
      r.get do
        log('-------------------')
        log('SimulatorWolf.net -> Deviantart.com/ArityWolf Redirection Request:', filename: 'aritywolf_redir.txt')
        log("request path: #{r.path} ; request host: #{r.host}", filename: 'aritywolf_redir.txt')
        log("request hash: #{request.inspect}", filename: 'aritywolf_redir.txt')
        log("request ip: #{request.ip}", filename: 'aritywolf_redir.txt')
        log("request referrer: #{request.referrer}", filename: 'aritywolf_redir.txt')
        log("request user_agent: #{request.user_agent}", filename: 'aritywolf_redir.txt')
        log("AJAX request?: #{request.xhr?}", filename: 'aritywolf_redir.txt')
        log("Timestamp: #{Time.now}", filename: 'aritywolf_redir.txt')
        log('-------------------')
        if DO_TELEGRAM_LOGGING
          @@telegram_logger.send_message("[HTTPRequestRelay(simulatorwolfnet)]:
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
        r.redirect('https://deviantart.com/ArityWolf')
      end
    end
  end
end
