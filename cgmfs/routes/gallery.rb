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

  def create_image_thumbnail!(image_path:, thumbnail_size:, thumbnail_path:)
    # use free-image gem
    image = FreeImage::Bitmap.open(image_path)
    thumbnail = image.make_thumbnail(thumbnail_size, true)
    extension = File.extname(image_path)
    case extension
    when '.jpg', '.jpeg'
      thumbnail.save(thumbnail_path, :jpeg)
    when '.png'
      thumbnail.save(thumbnail_path, :png)
    when '.bmp'
      thumbnail.save(thumbnail_path, :bmp)
    end
  end

  def resize_image!(image_path:, size:, resized_image_path:)
    # use free-image gem
    image = FreeImage::Bitmap.open(image_path)
    resized = image.make_thumbnail(size, true) # figure out a way to scale images according to dimensions and to get a best fit of what the multiplier should be in image.rescale(x,y)
    extension = File.extname(image_path)
    case extension
    when '.jpg', '.jpeg'
      resized.save(resized_image_path, :jpeg)
    when '.png'
      resized.save(resized_image_path, :png)
    when '.bmp'
      resized.save(resized_image_path, :bmp)
    end
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
        if ['.jpg', '.jpeg', '.png', '.bmp'].include?(file_extension) # add .zip later, et al.
          uploadable = true
          FileUtils.mkdir_p("public/gallery/#{@user}")
          File.open("public/gallery/#{@user}/#{original_to_new_filename}", 'w') { |file| file.write(file_contents) }
          create_image_thumbnail!(image_path: "public/gallery/#{@user}/#{original_to_new_filename}", thumbnail_size: 350, thumbnail_path: "public/gallery/#{@user}/thumbnail_#{original_to_new_filename}")
          resize_image!(image_path: "public/gallery/#{@user}/#{original_to_new_filename}", size: 1024, resized_image_path: "public/gallery/#{@user}/resized_#{original_to_new_filename}")
        else
          uploadable = false
        end

        if uploadable
         id = @@line_db[@user].pad['gallery_database', 'gallery_table'].add do |hash|
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
          # set the id of the image to the id of the image in the database
          @@line_db[@user].pad['gallery_database', 'gallery_table'].set(id) do |hash|
            hash['id'] = id
          end

        end
        # change to more efficient form later.
        @@line_db[@user].pad['gallery_database', 'gallery_table'].save_everything_to_files! if uploadable
        r.redirect "#{domain_name(r)}/gallery/view/#{@user}" if uploadable
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
        # @gallery.save_everything_to_files!
        # partition_to_save = @gallery.get(@id, hash: true)["db_index"]
        # @gallery.save_partition_to_file!(partition_to_save)
        @gallery.save_partition_by_id_to_file!(@id)

        view('blog/gallery/view_user_gallery_image_id', engine: 'html.erb', layout: 'layout.html')
      end
    end

    r.is 'view', String, 'tags', 'search' do |user| # view the tags list
      user_failcheck(user, r)
      r.get do
        @only_search = false
        @search_params = r.params['search_tags']
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @tags_array = []
        @images = @gallery.data_arr.map { |image| image }
        @tags = @images.map { |image| image['tags'] }.flatten
        @tags.each do |tag|
          next if tag.nil?

          tag.split(', ').each do |split_tag|
            @tags_array << split_tag
          end
        end
        @tags_array = @tags_array.uniq
        @images = @gallery.data_arr.map { |image| image }
        @image_tags = @images.map { |image| image['tags'] }
        # remove nils in tags
        @image_tags = @image_tags.reject { |tag| tag.nil? }
        if @search_params
          @search_params_set = @search_params.split(', ').compact.to_set
          # get rid of nil tags in @images_set
          @tags_to_reject = @search_params_set.select { |tag| tag.start_with?('-') }

          # remove the '--' from the tags to reject
          @tags_to_reject = @tags_to_reject.map { |tag| tag[2..-1] }

          @search_params_set.reject! { |tag| tag.start_with?('--') }
          @images_to_find = @images.select do |image|
            image['tags'] &&
              @search_params_set.subset?(image['tags'].split(', ').to_set)
          end

          @tags_to_reject.each do |rejected_tag|
            @images_to_find = @images_to_find.reject do |image|
              image['tags'].split(', ').include?(rejected_tag)
            end

          end


          @images_to_find = @images_to_find.to_a
        else
          @only_search = true
        end

        view('blog/gallery/view_user_gallery_image_tags_search', engine: 'html.erb', layout: 'layout.html')
      end
    end


    r.is 'view', String, 'tags' do |user| # view the tags list
      user_failcheck(user, r)
      r.get do
        @user = user
        @tags_array = []
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']

        # search the gallery database and join the results with the tags in search_params and the tags in @gallery
        # get all the unique tags from each gallery post
     

        @images = @gallery.data_arr.map { |image| image }
        # remove nils in tags
        @tags = @images.map { |image| image['tags'] }.flatten
        @tags.each do |tag|
          next if tag.nil?

          tag.split(', ').each do |split_tag|
            @tags_array << split_tag
          end
        end
        @tags_array = @tags_array.uniq
        @images_set = @images.to_set
        # remove an image from the set if it does not contain tags
        @images_set = @images_set.reject { |image| image['tags'].nil? }

        # search query for tags
        #
        # get the tags from the gallery databas
        # get the tags from the image database
        @split_tags = @tags_array
        view('blog/gallery/view_user_gallery_image_tags', engine: 'html.erb', layout: 'layout.html')
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
        if uploaded_filehandle
          original_to_new_filename = "#{Time.now.to_f}_#{uploaded_filehandle[:filename]}"
          file_contents = uploaded_filehandle[:tempfile].read
          file_size = file_contents.size
          file_extension = File.extname(uploaded_filehandle[:filename])
          # list all possible file types in File.extname:
          # .jpg, .jpeg, .png, .gif, .bmp, .zip, .tar, .gz, .rar, .7z, .mp3, .wav, .flac, .ogg, .mp4, .avi, .mkv, .mov, .wmv, .flv, .webm, .pdf, .doc, .docx, .xls, .xlsx, .ppt, .pptx, .txt, .rtf, .html, .htm, .xml, .json, .csv, .tsv, .md, .markdown, .rb, .py, .js, .css, .scss, .sass, .less, .php, .java, .c, .cpp, .h, .hpp, .cs, .go, .swift, .kt, .kts, .rs, .pl, .sh, .bat, .exe, .dll, .so, .dylib, .app, .apk, .ipa, .deb, .rpm, .msi, .dmg, .iso, .img, .bin, .cue, .mdf, .mds, .nrg, .vcd, .toast, .dmg, .toast, .vcd, .nrg, .mds, .mdf, .cue, .bin, .img, .iso, .rpm, .msi, .deb, .ipa, .apk, .app, .dylib, .so, .dll, .exe, .bat, .sh, .pl, .rs, .kts, .kt, .swift, .go, .cs, .hpp, .h, .cpp, .c, .java, .php, .less, .sass, .scss, .css, .js, .py, .rb, .markdown, .md, .tsv, .csv, .json, .xml, .htm, .html, .rtf, .txt, .pptx, .ppt, .xlsx, .xls, .docx, .doc, .pdf, .webm, .flv, .wmv, .mov, .mkv, .avi, .mp4, .ogg, .flac, .wav, .mp3, .7z, .rar, .gz, .
          #
          if ['.jpg', '.jpeg', '.png', '.bmp'].include?(file_extension) # add .zip later, et al.
            uploadable = true
            FileUtils.mkdir_p("public/gallery/#{@user}")
            File.open("public/gallery/#{@user}/#{original_to_new_filename}", 'w') { |file| file.write(file_contents) }
            create_image_thumbnail!(image_path: "public/gallery/#{@user}/#{original_to_new_filename}", thumbnail_size: 500, thumbnail_path: "public/gallery/#{@user}/thumbnail_#{original_to_new_filename}")
            resize_image!(image_path: "public/gallery/#{@user}/#{original_to_new_filename}", size: 1024, resized_image_path: "public/gallery/#{@user}/resized_#{original_to_new_filename}")
          else
            uploadable = false
          end
        else
          original_to_new_filename = @@line_db[@user].pad['gallery_database', 'gallery_table'].get(@id)['file']
          file_size = @@line_db[@user].pad['gallery_database', 'gallery_table'].get(@id)['size']
          file_extension = @@line_db[@user].pad['gallery_database', 'gallery_table'].get(@id)['extension']
        end

        @@line_db[@user].pad['gallery_database', 'gallery_table'].set(@id) do |hash|
          hash['file'] = original_to_new_filename
          hash['title'] = @title
          hash['description'] = @description
          hash['tags'] = @tags
          hash['size'] = file_size
          hash['extension'] = file_extension
          hash['date'] = TZInfo::Timezone.get('America/Los_Angeles').utc_to_local(Time.now).to_s
        end

        @gallery.save_partition_by_id_to_file!(@id)
        r.redirect "#{domain_name(r)}/gallery/view/#{@user}"
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength, Layout/LineLength, Metrics/ClassLength
