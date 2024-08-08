class CGMFS
  hash_branch 'pages' do |r| # ss: screenshot
    r.hash_branches

    r.on 'list' do
      r.get do
        # Logic for displaying a list of all pages
      end
    end

    r.on 'new', String do |page_name|
      r.get do
        # Logic for displaying the page creation form
      end

      r.post do
        # Logic for creating a new page
        #
      end
    end

    r.on 'edit', String do |page_name|
      r.get do
        # Logic for displaying the page deletion form
        #
        #
      end

      r.post do
        # Logic for deleting the page
      end
    end

    r.on String do |page_name|
      r.get do
        # Logic for displaying the page with the given name
      end
    end
  end
end
