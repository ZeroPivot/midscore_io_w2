class CGMFS
  hash_branch 'midscore' do |r| # ss: screenshot
    r.hash_branches
    r.is do
      r.get do
        log('-------------------')
        log('Midscore request:')
        log("request path: #{r.path} ; request host: #{r.host}")
        log("request hash: #{request.inspect}")
        log("request ip: #{request.ip}")
        log("request referrer: #{request.referrer}")
        log("request user_agent: #{request.user_agent}")
        log("AJAX request?: #{request.xhr?}")
        log('-------------------')
        if DO_TELEGRAM_LOGGING
          @@telegram_logger.send_message("[HTTPRequestRelay(midscore)]:
          request path: #{r.path} ; request host: #{r.host}
          request ip: #{request.ip}
          request referrer: #{request.referrer || 'none'}
          request user_agent: #{request.user_agent}
          AJAX request?: #{request.xhr?}
          Timestamp: #{Time.now}
          ")
        end
        @title = "ArityWolf-Midscore.io's HUDL.ink"
        view('midscore_landing', engine: 'html.erb', layout: 'layout.html')
      end
    end
  end
end
