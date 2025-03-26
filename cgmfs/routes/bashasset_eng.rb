class CGMFS
  hash_branch 'bashasset_eng' do |r| # ss: screenshot
    r.hash_branches
    r.is do
      r.get do
        log('-------------------')
        log('hudl.ink/bashasset_eng -> itch.io(zeropivot/bashasset) Redirection Request:',
            filename: 'bashasset_eng-redir.txt')
        log("request path: #{r.path} ; request host: #{r.host}", filename: 'bashasset_eng-redir.txt')
        log("request hash: #{request.inspect}", filename: 'bashasset_eng-redir.txt')
        log("request ip: #{request.ip}", filename: 'bashasset_eng-redir.txt')
        log("request referrer: #{request.referrer}", filename: 'bashasset_eng-redir.txt')
        log("request user_agent: #{request.user_agent}", filename: 'bashasset_eng-redir.txt')
        log("AJAX request?: #{request.xhr?}", filename: 'bashasset_eng-redir.txt')
        log("Timestamp: #{Time.now}", filename: 'bashasset_eng-redir.txt')
        log('-------------------')
        if DO_TELEGRAM_LOGGING
          @@telegram_logger.send_message("[HTTPRequestRelay(bashasset_eng)]:
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
        r.redirect('https://zeropivot.itch.io/bashasset') # todo, redirect to a page that redirects so you can gatehr more data
        # view('artywalf_redirect', engine: 'html.erb', layout: 'layout.html')
      end
    end
  end
end

# request referrer: #{request.referrer}
