class CGMFS
  hash_branch 'api' do |r| # ss: screenshot
    r.hash_branches
    r.is do
      r.get do
        'API'
      end
    end
  end
end
