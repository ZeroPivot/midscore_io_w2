class CGMFS
  hash_branch '/api', 'text' do |r| # ss: screenshot
    r.on 'upload' do
      r.post do
        auth = r.params['auth']
        raise if auth != 'CALCULUS'

        timestamp = "#{Time.now.to_s.gsub(' ', '_').gsub('+0000', '')}" # {} ".txt"""
        File.write("./public/text/#{timestamp}", r.params['text'])
        # r.redirect("/files/#{timestamp}")
        "https://hudl.ink/text/#{timestamp}"
      end
    end

    r.is 'view' do
      'lol'
    end
  end
end
