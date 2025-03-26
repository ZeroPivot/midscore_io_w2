class CGMFS
  hash_branch 'VAR_DB' do |r| # ss: screenshot
    r.hash_branches
    r.is do
      r.post do
        'VAR_DB ARRAY TEST'
        # view('midscore_landing', engine: 'html.erb', layout: 'layout.html')
      end
    end
  end
end
