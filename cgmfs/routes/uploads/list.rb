class CGMFS
  hash_branch '/uploads', 'list' do |r| # ss: screenshot
    # r.hash_branches
    r.is do
      r.get do
        @list = @@urls.data_arr
        @title = 'List of uploads'
        @r = r
        view('list_urls', engine: 'html.erb', layout: 'layout.html')
      end
    end
  end
end
