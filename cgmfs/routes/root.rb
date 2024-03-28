def family_logged_in?(r)
  return unless session['user']
  return unless session['password']

  log("family_logged_in? session['user']: #{session['user']}")
  log("family_logged_in? session['password']: #{session['password']}")
  r.redirect "#{domain_name(r)}/blog/login"
end

def domain_name(r)
  unless r
    return SERVER_IP_LOCAL if LOCAL # cgmfs.rb
    return DOMAIN_NAME unless LOCAL # cgmfs.rb ##
  end

  return 'http://localhost:8080' if DEBUG

  return unless r.host == 'localhost'

  'http://localhost:8080'

  # return "https://" + r.host
end


class CGMFS
  ROOT = ''

  hash_branch ROOT do |r|
    family_logged_in?(r)
    r.on do

      #@@telegram_logger.send_message("#{r.host}")


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
