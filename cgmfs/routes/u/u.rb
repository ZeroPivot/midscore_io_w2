

class CGMFS
  # response.headers["Cache-Control"] = "no-cache, no-store"
  # response.headers["Pragma"] = "no-cache"
  # response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
  hash_branch 'u' do |r| # ss: screenshot
    r.is 'test_u' do
      r.get do
        entry = @@urls.add do |hash|
          hash['url'] = 'test'
        end
        "entry: #{entry} - #{@@urls.get(0)}"
      end
    end
    r.is 'test' do
      r.get do
        log('adding a test entry')
        id = @@urls.add do |hash|
          hash['url'] = 'test'
        end
        part = @@urls.get(id, hash: true)['db_index']
        # log()
        @@urls.save_partition_to_file!(part)
        log("id: #{id} - part: #{part}")
        "#{id} - #{part}"
      end
    end

    r.is 'shorten' do
      r.post do
          # url = r.params['url']
   
            entry = @@urls.add(return_added_element_id: true) do |hash|
              hash['url'] = r.params['url'].to_s
            end
            log(entry.to_s)
            # @@urls.save_last_entry_to_file!
            part = @@urls.get(entry, hash: true)['db_index']
            @@urls.save_partition_to_file!(part)   
          
          
          "https://hudl.ink/u/#{entry}"
      end
    end


    r.is 'check_latest_id' do
    end

    r.is Integer do |id|
      max_entry = @@urls.latest_id

      
        # For base changes in the surface if => id_base16_in_10 = id.to_s(16).to_i(10)
        url_hash = @@urls.get(id)
        r.redirect url_hash['url'] unless url_hash.empty?
      
      "#{id} - #{max_entry}"
    end
  end
  hash_branch 'v' do |r| # ss: screenshot
  end
end
