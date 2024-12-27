class CGMFS
  hash_branch 'users' do |r| # ss: screenshot
    r.hash_branches
    r.is do
      r.on String do |s|
        r.get do
          "#{s}"
        end
      end
    end

    r.is 'login' do
      r.get do
        'Login'
      end
    end

    r.is 'register' do
      r.get do
        'Register'
      end
    end

    r.is 'logout' do
      r.get do
        'Logout'
      end
    end

    r.is 'profile' do
      r.get do
        'Profile'
      end
    end

    r.is do
      r.get do
        'Users'
      end
    end
  end
end
