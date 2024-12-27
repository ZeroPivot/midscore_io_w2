class CGMFS
  hash_branch '/api', 'screens' do |r| # ss: screenshot
    #  check_csrf!
    r.is 'upload' do
      r.post do
        auth = r.params['auth']
        raise if auth != 'CALCULUS'

        file_name = r.params['image_title']
        temp_file = r.params['form'][:tempfile].read
        File.write("./public/screens/#{file_name}", temp_file)
        log("uploaded: #{file_name}")

        #"https://hudl.ink/screens/#{file_name}"

        r.redirect("/screens/#{file_name}")
      end
    end

    r.is 'view' do
      'lol'
    end
    r.hash_branches(:screen)
  end
end
