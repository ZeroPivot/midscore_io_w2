# rubocop:disable Metrics/BlockLength, Layout/LineLength, Metrics/ClassLength, Metrics/MethodLength
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

  def convert_ints_to_emoji(int)
    integers_string = int.to_s.split('')
    emoji_integers = integers_string.map do |integer|
      case integer
      when '0'
        '0️⃣'
      when '1'
        '1️⃣'
      when '2'
        '2️⃣'
      when '3'
        '3️⃣'
      when '4'
        '4️⃣'
      when '5'
        '5️⃣'
      when '6'
        '6️⃣'
      when '7'
        '7️⃣'
      when '8'
        '8️⃣'
      when '9'
        '9️⃣'
      end
    end
    string_integers = emoji_integers.join('')
    if int < 0
      string_integers = "➖#{string_integers}"
    end
    string_integers
  end

# word.encode('ASCII-8BIT', invalid: :replace, undef: :replace, replace: '')




  def private_view?(r, user)
    if @@line_db[user].pad['blog_database', 'blog_profile_table'][0]['private_view'].nil?
      @@line_db[user].pad['blog_database', 'blog_profile_table'][0]['private_view'] = false
      @@line_db[user].pad['blog_database', 'blog_profile_table'].save_everything_to_files!
    end
    if @@line_db[user].pad['blog_database', 'blog_profile_table'][0]['private_view'] == true && session['user'] != user && !LOCAL # add admin access later
      r.redirect("#{domain_name(r)}/gallery/")
    elsif @@line_db[user].pad['blog_database',
                              'blog_profile_table'][0]['private_view'] == true && session['user'] != user && LOCAL
      r.redirect("#{SERVER_IP_LOCAL}/gallery/") if LOCAL
    end
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

  def parse_tags(user:, tag_string:, r: @r)
    # parse the tags from the string
    tags = tag_string.split(', ')
    # output html that uses the user and tag_string to redirect to the tag
    output = ""
    tags.each_with_index do |tag, index|
      output << "<a href='#{domain_name(r)}/gallery/view/#{user}/tags/search/?search_tags=#{tag}'>#{tag}</a>"
      output << ", " unless index == tags.size - 1

    end
    output

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



    r.on 'upload', 'url' do
      # get user session in roda
      @user = session['user']
      logged_in?(r, @user)
      user_failcheck(@user, r)

      r.get do
        view('blog/gallery/new_url', engine: 'html.erb', layout: 'layout.html')
      end

      r.post do
        log(r.params['url'])
        uploadable = false
        uploaded_filehandle = r.params['url']
        description = "url upload - #{r.params['url']} - Time: #{Time.now.to_s}"
        tags = "url_upload"
        title = "url upload - #{Time.now.to_s}"

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


        original_to_new_filename = "#{Time.now.to_f}_url_upload_#{@user}"
        file_contents = URI.open(uploaded_filehandle).read
        #log("file_contents: #{file_contents}")
        # Write the file to a temporary gallery location
        FileUtils.mkdir_p("public/gallery/#{@user}")
        file_path = "public/gallery/#{@user}/#{original_to_new_filename}"
        log("file_path: #{file_path}")
        File.open(file_path, 'w') do |file|
          file.write(file_contents)
        end
        log("file_path: #{file_path}")



        file_size = file_contents.size

        log("file_size: #{file_size}")
        file_type = FastImage.type(uploaded_filehandle)
        log("file_type: #{file_type}")
        if [:jpeg, :png, :gif].include?(file_type)
          uploadable = true
          FileUtils.mkdir_p("public/gallery/#{@user}")
          # Rename the file to include the extension
          file_type = FastImage.type(uploaded_filehandle)
          file_extension = case file_type
                           when :jpeg then '.jpg'
                           when :png then '.png'
                           else
                             ''
                           end
          file_path = "public/gallery/#{@user}/#{original_to_new_filename}"
          original_to_new_filename += file_extension
          new_file_path = "public/gallery/#{@user}/#{original_to_new_filename}"
          File.rename(file_path, new_file_path)

          Thread.new do
            create_image_thumbnail!(image_path: new_file_path, thumbnail_size: 350, thumbnail_path: "public/gallery/#{@user}/thumbnail_#{original_to_new_filename}")
          end
          Thread.new do
            resize_image!(image_path: new_file_path, size: 1920, resized_image_path: "public/gallery/#{@user}/resized_#{original_to_new_filename}")
          end
        else
          uploadable = false
          # delete the file
          File.delete(file_path)
        end





        if uploadable
          id = @@line_db[@user].pad['gallery_database', 'gallery_table'].add_at_last do |hash|
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
      r.redirect "#{domain_name(r)}/gallery/view/#{@user}/id/#{id}" if uploadable
      "<html><body>Upload failed. Please try again. <a href='#{domain_name(r)}/gallery/upload/url'>Upload</a></html></body>"
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
        description = r.params['description'] || ""
        tags = r.params['tags'] || ""
        title = r.params['title'] || ""
        reusable_tags = r.params['reusable_tags'] || ""
         if reusable_tags == 'on'
          session['last_tags'] = tags
          session['reusable_tags'] = true
         else
          session['last_tags'] = ""
          session['reusable_tags'] = false
         end



        description = "no description" if description.empty?
        tags = "none" if tags.empty?
        title = "untitled" if title.empty?
        file_extension = File.extname(uploaded_filehandle[:filename])
        original_to_new_filename = "#{@user}_#{Time.now.to_f}_original_#{file_extension}"
        file_contents = uploaded_filehandle[:tempfile].read
        file_size = file_contents.size
       

        file_type = FastImage.type(uploaded_filehandle[:tempfile])

        # list all possible file types in File.extname:
        # .jpg, .jpeg, .png, .gif, .bmp, .zip, .tar, .gz, .rar, .7z, .mp3, .wav, .flac, .ogg, .mp4, .avi, .mkv, .mov, .wmv, .flv, .webm, .pdf, .doc, .docx, .xls, .xlsx, .ppt, .pptx, .txt, .rtf, .html, .htm, .xml, .json, .csv, .tsv, .md, .markdown, .rb, .py, .js, .css, .scss, .sass, .less, .php, .java, .c, .cpp, .h, .hpp, .cs, .go, .swift, .kt, .kts, .rs, .pl, .sh, .bat, .exe, .dll, .so, .dylib, .app, .apk, .ipa, .deb, .rpm, .msi, .dmg, .iso, .img, .bin, .cue, .mdf, .mds, .nrg, .vcd, .toast, .dmg, .toast, .vcd, .nrg, .mds, .mdf, .cue, .bin, .img, .iso, .rpm, .msi, .deb, .ipa, .apk, .app, .dylib, .so, .dll, .exe, .bat, .sh, .pl, .rs, .kts, .kt, .swift, .go, .cs, .hpp, .h, .cpp, .c, .java, .php, .less, .sass, .scss, .css, .js, .py, .rb, .markdown, .md, .tsv, .csv, .json, .xml, .htm, .html, .rtf, .txt, .pptx, .ppt, .xlsx, .xls, .docx, .doc, .pdf, .webm, .flv, .wmv, .mov, .mkv, .avi, .mp4, .ogg, .flac, .wav, .mp3, .7z, .rar, .gz, .
        #
        if ['.jpg', '.jpeg', '.png', '.bmp', '.gif'].include?(file_extension) && [:jpeg, :png, :gif].include?(file_type) # add .zip later, et al.
          uploadable = true
          FileUtils.mkdir_p("public/gallery/#{@user}")
          File.open("public/gallery/#{@user}/#{original_to_new_filename}", 'w') { |file| file.write(file_contents) }
          Thread.new do
            create_image_thumbnail!(image_path: "public/gallery/#{@user}/#{original_to_new_filename}", thumbnail_size: 350, thumbnail_path: "public/gallery/#{@user}/thumbnail_#{original_to_new_filename}")
          end

          Thread.new do
            resize_image!(image_path: "public/gallery/#{@user}/#{original_to_new_filename}", size: 1920, resized_image_path: "public/gallery/#{@user}/resized_#{original_to_new_filename}")
          end
        else
          uploadable = false
        end

        if uploadable
         id = @@line_db[@user].pad['gallery_database', 'gallery_table'].add_at_last do |hash|
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
        @@line_db[@user].pad["cache_system_database", "cache_system_table"].set(0) do |hash|
          hash['recache'] = true
        end
        @@line_db[@user].pad["cache_system_database", "cache_system_table"].save_everything_to_files!
        r.redirect "#{domain_name(r)}/gallery/view/#{@user}" if uploadable
        "<html><body>Upload failed. Please try again. <a href='#{domain_name(r)}/gallery/upload'>Upload</a></html></body>"
      end
    end

    # /gallery/view/username
    r.is 'view', String do |user| # view the gallery list
      user_failcheck(user, r)
      private_view?(r, user)

      r.get do



        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']

        @gallery_images = @gallery.data_arr.reject { |image| image == {} }

        log("gallery images size: #{@gallery_images.size}")

        @skip_by = r.params['skip_by'].to_i
        if r.params['skip_by'].nil?
          @skip_by = 0
        end
        @gallery_numbers = @gallery_images.size / 175
        log(@gallery_numbers)
        if @gallery_images.size <= 175
          @pages = 0
          @gallery_range = 0..175
        else
          @pages = @gallery_numbers + 1
          @gallery_range = (175*@skip_by)..(175 + 175*(@skip_by))
        end

        # generate pages html
        @pages_html = ""
        @pages.times do |page_number|
          if page_number == @skip_by
            @pages_html << "<a href='#{domain_name(r)}/gallery/view/#{@user}?skip_by=#{page_number}'><b><i>#{page_number}</i><b></a>&nbsp;&nbsp;"
          else
            @pages_html << "<a href='#{domain_name(r)}/gallery/view/#{@user}?skip_by=#{page_number}'>#{page_number}</a>&nbsp;&nbsp;"
          end
          @pages_html << "&nbsp;" unless page_number == @pages - 1
          @pages_html << "<br>" if page_number % 10 == 0 && page_number != 0
        end


        @gallery = @gallery_images[@gallery_range]

        @owo_count_gallery = @@line_db[@user].pad['gallery_database', 'gallery_table'].data_arr.sort_by { |image| image['owo_count'].to_i }


        view('blog/gallery/list_gallery_uploads', engine: 'html.erb', layout: 'layout.html')
      end
    end

    r.is 'view', String, 'id', Integer do |user, id| # view the gallery entry
      user_failcheck(user, r)
      r.get do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @id = id
        @image = @gallery.get(@id)
        @attachments = @image['attachments']

        @owo = @image['owo_count']

        if @image
          # add one to page view, and save by partition:
          @image['views'] += 1
          @gallery.save_partition_by_id_to_file!(@id)
          view('blog/gallery/view_user_gallery_image_id', engine: 'html.erb', layout: 'layout.html')
        else
          "No gallery post found with id #{@id}."
        end
      end
    end


    r.is 'view', String, 'id', Integer, 'attachments' do |user, id| # view the attachments list
      user_failcheck(user, r)
      r.get do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @id = id
        @image = @gallery.get(@id)
        view('blog/gallery/view_user_gallery_image_id_attachments_list', engine: 'html.erb', layout: 'layout.html')
      end


    end


    r.is 'view', String, 'id', Integer, 'attachments', 'delete', Integer do |user, id, attachment_id| # view the attachments list
      user_failcheck(user, r)
      r.get do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @id = id
        @image = @gallery.get(@id)
        @attachments = @image['attachments']

       File.delete("public/gallery/#{@user}/attachments/#{@attachments[attachment_id]['file_attachment_name']}")
       @attachments.delete_at(attachment_id)
       log(@attachments.to_s)
       log("attachment deleted")
        @gallery.set(@id) do |hash|
          hash['attachments'] = @attachments
        end
        log("attachment hash set")
        @gallery.save_partition_by_id_to_file!(@id)
        log("attachment saved")

        #"attachment deleted. <a href='#{domain_name(r)}/gallery/view/#{@user}/id/#{@id}/attachments'>Back to attachments</a>"
        r.redirect "#{domain_name(r)}/gallery/view/#{@user}/id/#{@id}/attachments"
      end

    end


    r.is 'view', String, 'id', Integer, 'attachments', 'upload' do |user, id| # view the gallery list
      user_failcheck(user, r)
      r.get do
        @user = user
        @r = r
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @id = id
        @image = @gallery.get(@id)
        #@attachments = @image['attachments']
        # <%= domain_name(@r) %>/gallery/view/<%= @user %>/id/<%= @attachment_id %>
        view('blog/gallery/view_user_gallery_image_id_attachments_upload', engine: 'html.erb', layout: 'layout.html')
      end

      r.post do
        @user = user
        @r = r
        @url_params = r.params['url']
        @id = id

        unless @url_params
          @uploaded_filehandle = r.params['file'][:tempfile].read
          @file_name = Time.now.to_f.to_s + r.params['file'][:filename]
          FileUtils.mkdir_p("public/gallery/#{@user}/attachments")
          File.open("public/gallery/#{@user}/attachments/#{@file_name}", 'w') { |file| file.puts @uploaded_filehandle }
          @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
          @id = id
          @image = @gallery.get(@id)

          log(@image['attachments'].to_s)
          if !@image['attachments']
            @attachments = []
          else
            @attachments = @image['attachments']
          end
          @attachments << { 'file_attachment_name' => @file_name, 'file_attachment_size' => @uploaded_filehandle.size, 'extension' => File.extname(@file_name), 'file_attachment_date' => TZInfo::Timezone.get('America/Los_Angeles').utc_to_local(Time.now).to_s }

          @gallery.set(@id) do |hash|
            hash['attachments'] = @attachments

          end


          @gallery.save_partition_by_id_to_file!(@id)

        else

        @uri_url = URI.open(@url_params.to_s)
        @uploaded_filehandle = @uri_url.read
        @meta = @uri_url.meta['content-type'].split('/').last
        log(@meta)
        @file_name = Time.now.to_f.to_s + 'attachment' + '.' + @meta

        FileUtils.mkdir_p("public/gallery/#{@user}/attachments")
        File.open("public/gallery/#{@user}/attachments/#{@file_name}", 'w') { |file| file.puts @uploaded_filehandle }
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @id = id
        @image = @gallery.get(@id)

        log(@image['attachments'].to_s)
        if !@image['attachments']
          @attachments = []
        else
          @attachments = @image['attachments']
        end
        @attachments << { 'file_attachment_name' => @file_name, 'file_attachment_size' => @uploaded_filehandle.size, 'extension' => File.extname(@file_name), 'file_attachment_date' => TZInfo::Timezone.get('America/Los_Angeles').utc_to_local(Time.now).to_s }

        @gallery.set(@id) do |hash|
          hash['attachments'] = @attachments

        end
        @@line_db[@user].pad["cache_system_database", "cache_system_table"].set(0) do |hash|
          hash['recache'] = true
        end
        @@line_db[@user].pad["cache_system_database", "cache_system_table"].save_everything_to_files!

        log(@url_params)
        @gallery.save_partition_by_id_to_file!(@id)

      end
        r.redirect "#{domain_name(r)}/gallery/view/#{@user}/id/#{@id}"
      end

    end



    r.is 'delete', String, 'id', Integer do |user, id| # delete a gallery post by id
      user_failcheck(user, r)
      r.get do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @id = id
        @image = @gallery.get(@id)
        if @image
          @gallery.data_arr[@id] = {}
          File.delete("public/gallery/#{@user}/#{@image['file']}")
          @gallery.save_partition_by_id_to_file!(@id)
          @@line_db[@user].pad["cache_system_database", "cache_system_table"].set(0) do |hash|
            hash['recache'] = true
          end
          @@line_db[@user].pad["cache_system_database", "cache_system_table"].save_everything_to_files!
          "Gallery post with id #{@id} deleted successfully. <a href='#{domain_name(r)}/gallery/view/#{@user}'>Back TO Gallery</a>"
        else
          "No gallery post found with id #{@id}."
        end
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
        @images = @images.compact
        @tags = @images.map { |image| image['tags'] }.flatten
        @tags.each do |tag|
          next if tag.nil?

          tag.split(', ').each do |split_tag|
            @tags_array << split_tag
          end
        end
        @tags_array = @tags_array.uniq
        @images = @gallery.data_arr.map { |image| image }
        @images = @images.compact
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
            image['tags'] && @search_params_set.subset?(image['tags'].split(', ').to_set)
          end

          @tags_to_reject.each do |rejected_tag|
            @images_to_find = @images_to_find.reject do |image|
              image['tags']&.split(', ')&.include?(rejected_tag)
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
        @tags_set = []
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @view_all_images_with_tags = r.params['view_all_images_with_tags']

        @cache = @@line_db[@user].pad["cache_system_database", "cache_system_table"]

        @cache_hash = @cache.get(0)

        if @cache_hash == {}
            @recache = true
            @cache.set(0) do |hash|
              hash['recache'] = true
            end
        end


          if !@cache.get(0)['recache']
            @cache.set(0) do |hash|
              hash['recache'] = false
              @recache = false
            end

          elsif @cache.get(0)['recache']
              @recache = true
          else
            @recache = false
          end
          log(@recache)


        if @recache
          GC.start
          @images = @gallery.data_arr.map { |image| image }
          @images = @images.compact
          @tags = @images.map { |image| image['tags'] }.flatten
          @tags.each do |tag|
            next if tag.nil?

            tag.split(', ').each do |split_tag|
              @tags_array << split_tag
            end

          end
          @tags_array = @tags_array.uniq
          @images_set = @images.to_set
          @images_set = @images_set.reject { |image| image['tags'].nil? }

          @split_tags = @tags_array

          @split_tags.each do |tag|
            tag_quantity = @gallery.data_arr.count { |image| image['tags']&.split(", ")&.include?(tag) }
            @tags_set << "<a href='#{domain_name(@r)}/gallery/view/#{@user}/tags/search/?search_tags=#{tag}'>#{tag}(#{tag_quantity})</a>"
          end


          @cache.set(0) do |hash|
            hash['tags_set'] = @tags_set
            hash['split_tags'] = @split_tags
            hash['recache'] = false
          end
          @cache.save_everything_to_files!
          GC.start
        else


          @split_tags = @cache.get(0)['split_tags']
          @tags_set = @cache.get(0)['tags_set']
        end
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
        @file = @image['file']



        view('blog/gallery/edit_user_gallery_image_id', engine: 'html.erb', layout: 'layout.html')
      end
      r.post do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @id = id
        @title = r.params['title']
        @description = r.params['description']
        @tags = r.params['tags']

        @description = "no description" if @description.empty?
        @tags = "none" if @tags.empty?
        @title = "untitled" if @title.empty?



        # get the image temp file parameters through roda:
        uploadable = false
        uploaded_filehandle = r.params['file']
        if uploaded_filehandle
          #original_to_new_filename = "#{Time.now.to_f}_#{uploaded_filehandle[:filename]}"
          original_to_new_filename = "#{@user}_#{Time.now.to_f}_original_#{file_extension}"
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
            Thread.new do
              create_image_thumbnail!(image_path: "public/gallery/#{@user}/#{original_to_new_filename}", thumbnail_size: 255, thumbnail_path: "public/gallery/#{@user}/thumbnail_#{original_to_new_filename}")
            end
            Thread.new do
              resize_image!(image_path: "public/gallery/#{@user}/#{original_to_new_filename}", size: 1080, resized_image_path: "public/gallery/#{@user}/resized_#{original_to_new_filename}")
            end
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
        @@line_db[@user].pad["cache_system_database", "cache_system_table"].set(0) do |hash|
          hash['recache'] = true
        end
        @@line_db[@user].pad["cache_system_database", "cache_system_table"].save_everything_to_files!
        r.redirect "#{domain_name(r)}/gallery/view/#{@user}/id/#{@id}"
      end
    end

    r.is 'uwu', 'view', String do |user| # view the collections list
      user_failcheck(user, r)
      r.get do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @collections = @@line_db[@user].pad['uwu_collections_database', 'uwu_collections_table']
        @collections = @collections.data_arr
        # uwu collections has its own id in data_arr and the id of the image in the gallery that is very uwu, with a numerical ranking system
        @collections = @collections.compact
        @collections = @collections.sort_by { |collection| collection['id'] }

        view('blog/gallery/view_uwu_collections', engine: 'html.erb', layout: 'layout.html')
      end
    end

    r.is 'uwu', 'view', String, 'id', Integer do |user, id| # view the collection id
      user_failcheck(user, r)

      r.get do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @collections = @@line_db[@user].pad['uwu_collections_database', 'uwu_collections_table']
        @id = id
        @collection = @collections.get(@id)
        @image_id = @collection['image_id']
        @image = @gallery.get(@image_id)
        view('blog/gallery/view_uwu_collections_id', engine: 'html.erb', layout: 'layout.html')
      end
    end

    r.is 'uwu', 'edit', String, 'id', Integer do |user, id| # edit the collection id
      user_failcheck(user, r)
      logged_in?(r, user)
      r.get do
        @user = user
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @collections = @@line_db[@user].pad['uwu_collections_database', 'uwu_collections_table']
        @id = id
        @collection = @collections.get(@id)
        @image_id = @collection['image_id']
        @image = @gallery.get(@image_id)
        view('blog/gallery/edit_uwu_collections_id', engine: 'html.erb', layout: 'layout.html')
      end
    end

    r.is 'uwu', 'view', String, 'id', Integer, 'delete' do |user, id| # delete the collection id
      user_failcheck(user, r)
      logged_in?(r, user)
     r.get do
        @user = user
        logged_in?(r, @user)
        @collections = @@line_db[@user].pad['uwu_collections_database', 'uwu_collections_table']
        @id = id
        @collection = @collections.get(@id)
        if @collection
          @collections.data_arr[@id] = {}
          @collections.save_partition_by_id_to_file!(@id)
          "Collection with id #{@id} deleted successfully."
        else
          "No collection found with id #{@id}."
        end
      end
    end

    r.is 'owo', 'add' do

      r.get do
        @user = session['user']
        logged_in?(r, @user)
        @image_id = r.params['image_id'].to_i
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @gallery.set(@image_id) do |hash|
          if hash['owo_count'].nil?
            hash['owo_count'] = 0
          else
            hash['owo_count'] += 1
          end
        end
        @gallery.save_partition_by_id_to_file!(@image_id)
        r.redirect "#{domain_name(r)}/gallery/view/#{@user}/id/#{@image_id}"

      end

    end

    r.is 'owo', 'rem' do

      r.get do
        @user = session['user']
        logged_in?(r, @user)
        @image_id = r.params['image_id'].to_i
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @gallery.set(@image_id) do |hash|
          hash['owo_count'] = nil
        end
        @gallery.save_partition_by_id_to_file!(@image_id)
        r.redirect "#{domain_name(r)}/gallery/view/#{@user}/id/#{@image_id}"

      end


    end

    r.is 'owo', 'sub' do

      r.get do
        @user = session['user']
        logged_in?(r, @user)
        @image_id = r.params['image_id'].to_i
        @gallery = @@line_db[@user].pad['gallery_database', 'gallery_table']
        @gallery.set(@image_id) do |hash|
          if hash['owo_count'].nil?
            hash['owo_count'] = 0
          else
            hash['owo_count'] -= 1
          end
        end
        @gallery.save_partition_by_id_to_file!(@image_id)
        r.redirect "#{domain_name(r)}/gallery/view/#{@user}/id/#{@image_id}"
      end
    end



  end
end
# rubocop:enable Metrics/BlockLength, Layout/LineLength, Metrics/ClassLength, Metrics/MethodLength
