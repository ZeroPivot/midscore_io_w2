def family_logged_in?(r)
  return unless session['user']
  return unless session['password']
end

class CGMFS
  ROOT = ''

  hash_branch ROOT do |r|
    r.on do
      family_logged_in?(r)      
      r.redirect "https://#{r.host}:8080/blog"
    end
  end
end
