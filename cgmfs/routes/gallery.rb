# rubocop:disable Metrics/BlockLength, Layout/LineLength, Metrics/ClassLength
class CGMFS
  def user_failcheck(username, r)
    return if @@line_db.databases.include?(username)

    # @@line_db.new_database!(username)
    # @@line_db[username].pad.new_table!(database_name: "#{username}_database", database_table: "#{username}_table")
    r.redirect "http://#{r.host}:8080" if LOCAL
    r.redirect "https://#{r.host}" unless LOCAL
  end

  def logged_in?(r, user)
    return unless session['user'] != user

    r.redirect "#{domain_name(r)}/blog/login"
  end

  def domain_name(r)
    unless r
      return SERVER_IP_LOCAL if LOCAL # cgmfs.rb
      return DOMAIN_NAME unless LOCAL # cgmfs.rb ##
    end

    return 'http://localhost:8080' if DEBUG

    return unless r.host == 'localhost'

    'http://localhost:8080'

    # return "https://" + r.host
  end

  # /gallery
  hash_branch 'gallery' do |r|
    @start_rendering_time = Time.now.to_f
    r.hash_branches
    @r = r
    r.is do
      r.get do
        view('blog/gallery/list_gallery_users', engine: 'html.erb', layout: 'layout.html')
      end
    end

    r.on 'upload' do
      # get user session in roda
      @user = session['user']
      logged_in?(r, @user)
      user_failcheck(@user, r)

      r.get do
        view('blog/gallery/new', engine: 'html.erb', layout: 'layout.html')
      end

      r.post do
        # Code to upload an image to the gallery, with an option to introduce the upload location and retrieve via URL
        # 1. Upload the image to the server
        # 2. Save the image to the database
        # 3. Redirect to the gallery view
        # 4. Add a delete option
        # 5. Add a view option
        # 6. Add a download option
        # 7. Add a share option
        # 8. Add a comment option
        # 9. Add a like option
        # 10. Add a tag option
        # 11. Add a search option
        # 12. Add a sort option
        # 13. Add a filter option

        # get the image temp file parameters through roda:
        uploadable = false
        uploaded_filehandle = r.params['file']
        description = r.params['description']
        tags = r.params['tags']
        title = r.params['title']
        original_to_new_filename = "#{Time.now.to_f}_#{uploaded_filehandle[:filename]}"
        file_contents = uploaded_filehandle[:tempfile].read
        file_size = file_contents.size
        file_extension = File.extname(uploaded_filehandle[:filename])
        # list all possible file types in File.extname:
        # .jpg, .jpeg, .png, .gif, .bmp, .zip, .tar, .gz, .rar, .7z, .mp3, .wav, .flac, .ogg, .mp4, .avi, .mkv, .mov, .wmv, .flv, .webm, .pdf, .doc, .docx, .xls, .xlsx, .ppt, .pptx, .txt, .rtf, .html, .htm, .xml, .json, .csv, .tsv, .md, .markdown, .rb, .py, .js, .css, .scss, .sass, .less, .php, .java, .c, .cpp, .h, .hpp, .cs, .go, .swift, .kt, .kts, .rs, .pl, .sh, .bat, .exe, .dll, .so, .dylib, .app, .apk, .ipa, .deb, .rpm, .msi, .dmg, .iso, .img, .bin, .cue, .mdf, .mds, .nrg, .vcd, .toast, .dmg, .toast, .vcd, .nrg, .mds, .mdf, .cue, .bin, .img, .iso, .rpm, .msi, .deb, .ipa, .apk, .app, .dylib, .so, .dll, .exe, .bat, .sh, .pl, .rs, .kts, .kt, .swift, .go, .cs, .hpp, .h, .cpp, .c, .java, .php, .less, .sass, .scss, .css, .js, .py, .rb, .markdown, .md, .tsv, .csv, .json, .xml, .htm, .html, .rtf, .txt, .pptx, .ppt, .xlsx, .xls, .docx, .doc, .pdf, .webm, .flv, .wmv, .mov, .mkv, .avi, .mp4, .ogg, .flac, .wav, .mp3, .7z, .rar, .gz, .
        #
        if ['.jpg', '.jpeg', '.png', '.gif', '.bmp'].include?(file_extension) # add .zip later, et al.
          uploadable = true
          FileUtils.mkdir_p("public/gallery/#{@user}")
          File.open("public/gallery/#{@user}/#{original_to_new_filename}", 'w') { |file| file.write(file_contents) }
        else
          uploadable = false
        end

        if uploadable
          @@line_db[@user].pad['gallery_database', 'gallery_table'].add do |hash|
            hash['file'] = original_to_new_filename
            hash['views'] = 0
            hash['title'] = title
            hash['description'] = description
            hash['downloads'] = 0
            hash['shares'] = 0
            hash['comments'] = 0
            hash['likes'] = 0
            hash['tags'] = tags
            hash['size'] = file_size
            hash['extension'] = file_extension
            hash['date'] = TZInfo::Timezone.get('America/Los_Angeles').utc_to_local(Time.now).to_s
          end
        end
        # change to more efficient form later.
        @@line_db[@user].pad['gallery_database', 'gallery_table'].save_everything_to_files! if uploadable
        r.redirect "#{domain_name(r)}/gallery/view/#{session['user']}" if uploadable
        "<html><body>Upload failed. Please try again. <a href='#{domain_name(r)}/gallery/upload'>Upload</a></html></body>"
      end
    end

    # /gallery/view/username
    r.is 'view', String do |user| # view the gallery list
      user_failcheck(user, r)
      r.get do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        view('blog/gallery/list_gallery_uploads', engine: 'html.erb', layout: 'layout.html')
      end
    end

    r.is 'view', String, 'id', Integer do |user, id| # view the gallery list
      user_failcheck(user, r)
      r.get do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @id = id
        @image = @gallery.get(@id)
        # add one to page view, and save by partition:
        @image['views'] += 1
        #@gallery.save_everything_to_files!
        partition_to_save = @gallery.get(@id, hash: true)["db_index"]
        @gallery.save_partition_to_file!(partition_to_save)



        view('blog/gallery/view_user_gallery_image_id', engine: 'html.erb', layout: 'layout.html')
      end
    end
    # /gallery/edit/user/id/ID
    r.is 'edit', String, 'id', Integer do |user, id| # edit the gallery list
      user_failcheck(user, r)
      logged_in?(r, user)
      r.get do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @id = id

        @image = @gallery.get(@id)
        @title = @image['title']
        @description = @image['description']
        @tags = @image['tags']

        view('blog/gallery/edit_user_gallery_image_id', engine: 'html.erb', layout: 'layout.html')
      end
      r.post do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @id = id
        @title = r.params['title']
        @description = r.params['description']
        @tags = r.params['tags']

        # get the image temp file parameters through roda:
        uploadable = false
        uploaded_filehandle = r.params['file']
        if (uploaded_filehandle)
          original_to_new_filename = "#{Time.now.to_f}_#{uploaded_filehandle[:filename]}"
          file_contents = uploaded_filehandle[:tempfile].read
          file_size = file_contents.size
          file_extension = File.extname(uploaded_filehandle[:filename])
          # list all possible file types in File.extname:
          # .jpg, .jpeg, .png, .gif, .bmp, .zip, .tar, .gz, .rar, .7z, .mp3, .wav, .flac, .ogg, .mp4, .avi, .mkv, .mov, .wmv, .flv, .webm, .pdf, .doc, .docx, .xls, .xlsx, .ppt, .pptx, .txt, .rtf, .html, .htm, .xml, .json, .csv, .tsv, .md, .markdown, .rb, .py, .js, .css, .scss, .sass, .less, .php, .java, .c, .cpp, .h, .hpp, .cs, .go, .swift, .kt, .kts, .rs, .pl, .sh, .bat, .exe, .dll, .so, .dylib, .app, .apk, .ipa, .deb, .rpm, .msi, .dmg, .iso, .img, .bin, .cue, .mdf, .mds, .nrg, .vcd, .toast, .dmg, .toast, .vcd, .nrg, .mds, .mdf, .cue, .bin, .img, .iso, .rpm, .msi, .deb, .ipa, .apk, .app, .dylib, .so, .dll, .exe, .bat, .sh, .pl, .rs, .kts, .kt, .swift, .go, .cs, .hpp, .h, .cpp, .c, .java, .php, .less, .sass, .scss, .css, .js, .py, .rb, .markdown, .md, .tsv, .csv, .json, .xml, .htm, .html, .rtf, .txt, .pptx, .ppt, .xlsx, .xls, .docx, .doc, .pdf, .webm, .flv, .wmv, .mov, .mkv, .avi, .mp4, .ogg, .flac, .wav, .mp3, .7z, .rar, .gz, .
          #
          if ['.jpg', '.jpeg', '.png', '.gif', '.bmp'].include?(file_extension) # add .zip later, et al.
            uploadable = true
            FileUtils.mkdir_p("public/gallery/#{@user}") unless
            File.open("public/gallery/#{@user}/#{original_to_new_filename}", 'w') { |file| file.write(file_contents) }
          else
            uploadable = false
          end
        else
          original_to_new_filename =  @@line_db[@user].pad['gallery_database', 'gallery_table'].get(@id)['file']
          file_size = @@line_db[@user].pad['gallery_database', 'gallery_table'].get(@id)['size']
          file_extension = @@line_db[@user].pad['gallery_database', 'gallery_table'].get(@id)['extension']
        end

        if uploadable
          @@line_db[@user].pad['gallery_database', 'gallery_table'].set(@id) do |hash|
            hash['file'] = original_to_new_filename
            hash['title'] = @title
            hash['description'] = @description
            hash['tags'] = @tags
            hash['size'] = file_size
            hash['extension'] = file_extension
            hash['date'] = TZInfo::Timezone.get('America/Los_Angeles').utc_to_local(Time.now).to_s
          end
        end




        @gallery.save_partition_by_id_to_file!(@id)
        r.redirect "#{domain_name(r)}/gallery/view/#{@user}"
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength, Layout/LineLength, Metrics/ClassLength
