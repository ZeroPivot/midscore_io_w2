class CGMFS
  hash_branch '/api', 'file' do |r| # ss: screenshot
    r.on 'upload' do
      r.post do
        auth = r.params['auth']
        raise if auth != 'CALCULUS'

        # timestamp = "#{Time.now.to_s.gsub(" ","_").gsub("+0000","")}.png"
        # File.write("test.jpg", r.params['image_title'][:tempfile].read)
        # "#{r.params}"
        # "#{timestamp}"
        File.write("./public/files/#{r.params['file_title']}", r.params['form'][:tempfile].read)
        # r.redirect("/screens/#{timestamp}")
        "https://hudl.ink/files/#{r.params['file_title']}"
        # "#{Dir.pwd}"
        # "#{p r.params['form'][:tempfile]}"
      end
    end

    r.is 'view' do
      'lol'
    end
  end
end
