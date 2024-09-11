def family_logged_in?(r)
  return unless session['user']
  return unless session['password']
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

    r.on do
      r.redirect "https://thaiamerican.market/tam/index.html" if r.host == 'thaiamerican.market'
      family_logged_in?(r)

      r.redirect "https://#{r.host}/blog" if !LOCAL
      r.redirect "http://#{r.host}:8080/blog" if LOCAL

    end


  end
end
