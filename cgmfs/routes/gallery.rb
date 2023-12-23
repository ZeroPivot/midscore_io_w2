# rubocop:disable Metrics/BlockLength
# require 'roda'
# require 'sequel'

DB = Sequel.connect('sqlite://gallery.db') # replace with LineDB

class CGMFS
  plugin :indifferent_params
  plugin :json

  hash_branch('gallery') do |r|
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

    r.on 'folder', String, Integer do |username, folder_id|
      r.get do
        # Retrieve a specific folder
        folder = DB[:folders].first(id: folder_id)
        { folder: folder }
      end

      r.put do
        # Update a specific folder
        updated_folder = DB[:folders].where(id: folder_id).update(title: r.params['title'])
        { folder_id: folder_id, message: 'Folder updated successfully' }
      end
    end

    r.on 'folder', String, Integer, 'edit' do |username, folder_id|
      r.get do
        # Retrieve the edit page for a specific folder
        folder = DB[:folders].first(id: folder_id)
        { folder: folder }
      end

      r.post do
        # Update a specific folder from the edit page
        updated_folder = DB[:folders].where(id: folder_id).update(title: r.params['title'])
        { folder_id: folder_id, message: 'Folder updated successfully' }
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
