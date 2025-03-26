def family_logged_in?(r)
  return if session['user']
  return if session['password']
  return if session['user'] == 'superadmin'
  return if r.path == '/blog/login' # Don't redirect if already at login

  r.redirect '/blog/login'
end

class CGMFS
  ROOT = ''

  hash_branch ROOT do |r|
    r.on do
     # family_logged_in?(r) # -- TEMP FAILSAFE (v9.0.0.1)
      r.redirect "#{domain_name(r)}/blog/login"
    end
  end
end