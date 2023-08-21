class CGMFS
  ROOT = ''
  hash_branch ROOT do |r|
    r.on do
      #@@telegram_logger.send_message("#{r.host}")
      if (r.host == 'thefieldtester.net' && r.params['autologin'])
        session['user'] = 'archyeen'
        session['password'] = '859CDFE#F4E90'
        session['admin'] = true

        r.redirect 'https://thefieldtester.net/blog/archyeen'
      elsif (r.host == 'thefieldtester.net')
        r.redirect 'https://thefieldtester.net/blog/archyeen'
      end

      if (r.host == 'thefieldtesters.net')
        r.redirect 'https://thefieldtesters.net/blog/the-field-testers'
      end

     if (r.host == 'midscore.io')
       r.redirect 'https://midscore.io/index.html'
     end





      #r.redirect "https://thefieldtesters.net/blog/aritywolf" if r.host == "thefieldtesters.net" && !r.params("autologin")
      #r.redirect "https://thefieldtesters.net/blog/aritywolf?autologin=1" if r.host == "thefieldtesters.net" && r.params("autologin")
      r.redirect "https://#{r.host}/blog" if !LOCAL
      r.redirect "http://#{r.host}:8080/blog" if LOCAL
      # "#{r.host}"
      # "#{r.host}"
    end
  end
end

# Q: how do I configure my username and password and email in github?
# A: git config --global user.name "Your Name"
#    git config --global user.email "

# Q: gay?
# A: yes
