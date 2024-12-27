class CGMFS
  hash_branch(:screen, 'list') do |r| # ss: screenshot
    r.is do
      r.get do
        'Screen'
      end
    end
  end
end
