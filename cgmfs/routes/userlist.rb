class CGMFS
  hash_branch 'userlist' do |r|
    r.is do
      r.get do
        userlist = ""
        @@line_db.databases.each do |db|
          userlist << db << "<br>"
        end
        "#{userlist}"
      end
    end
  end
end
