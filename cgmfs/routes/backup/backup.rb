class CGMFS
  hash_branch 'backup' do |r|
    r.hash_branches
    r.is do
      r.get do
        t = Time.now
        `zip -r /root/midscore_io/public/midscore-io-backup/midscore-io-backup_#{t.to_s.gsub(' ', '_')}.zip /root/midscore_io/`
        "
        <html>
        <a href='/midscore-io-backup/midscore-io-backup_#{t.to_s.gsub(' ', '_')}.zip'>Download backup</a>
        </html>        
        "
      end
  end
end
end
#