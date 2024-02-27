# rubocop:disable Metrics/BlockLength
# require 'roda'
# require 'sequel'

#DB #= Sequel.connect('sqlite://gallery.db') # replace with LineDB

class CGMFS
  plugin :indifferent_params
  plugin :json

  hash_branch('gallery') do |r|
    r.hash_branches
    r.is do
      r.get do
        # Retrieve all galleries
          galleries = DB[:galleries].all
        { galleries: galleries }
      end

      r.post do
        # Create a new gallery
        gallery_id = DB[:galleries].insert(title: r.params['title'])
        { gallery_id: gallery_id }
      end
    end

    r.on String, Integer do |username, gallery_id|
      r.get do
        # Retrieve a specific gallery
        gallery = DB[:galleries].first(id: gallery_id)
        { gallery: gallery }
      end

      r.post 'upload' do
        # Handle gallery image upload
        # Save the uploaded image to a folder
        # Update the gallery record in the database
        { message: 'Image uploaded successfully' }
      end
    end

  end
end

# rubocop:enable Metrics/BlockLength
