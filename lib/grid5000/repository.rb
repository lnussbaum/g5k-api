require 'grid5000/extensions/grit'
require 'json'


module Grid5000
  class Repository
    attr_reader :repository_path, :repository_path_prefix, :instance, :commit
    
    def initialize(repository_path, repository_path_prefix = nil)
      @commit = nil
      @reloading = false
      @repository_path_prefix = repository_path_prefix ? repository_path_prefix.gsub(/^\//,'') : repository_path_prefix
      @repository_path = File.expand_path repository_path
      @instance = Grit::Repo.new(repository_path)
    end
    
    def find(path, options = {})
      @commit = nil
      @commit = find_commit_for(options)
      return nil if @commit.nil?
      object = find_object_at(path, @commit)
      return nil if object.nil?
      result = expand_object(object, path, @commit)
    end
    
    def expand_object(object, path, commit)
      return nil if object.nil?
      
      if object.mode == "120000"
        object = find_object_at(object.data, commit, relative_to=path)
      end
      
      case object
      when Grit::Blob
        JSON.parse(object.data).merge("version" => commit.id)
      when Grit::Tree
        groups = object.contents.group_by{|content| content.class}
        blobs, trees = [groups[Grit::Blob] || [], groups[Grit::Tree] || []]
        # select only json files
        blobs = blobs.select{|blob| File.extname(blob.name) == '.json'}
        if (blobs.size > 0 && trees.size > 0)
          # item
          blobs.inject({}) do |accu, blob| 
            content = expand_object(
              blob, 
              File.join(path, blob.name.gsub(".json", "")),
              commit
            )
            accu.merge(content)
          end
        else # collection
          # collection
          items = object.contents.map do |object|
            content = expand_object(
              object,
              File.join(path, object.name.gsub(".json", "")),
              commit
            )
          end
          result = {
            "total" => items.length, 
            "offset" => 0,
            "items" => items,
            "version" => commit.id
          }
          result
        end
      else
        nil
      end
    end
    
    def find_commit_for(options = {})
      options[:branch] ||= 'master'
      version, branch = options.values_at(:version, :branch)
      if version.nil?
        instance.commits(branch)[0]
      elsif version.to_s.length == 40 # SHA
        instance.commit(version)
      else
        # version should be a date, get the closest commit
        date = Time.at(version.to_i).strftime("%Y-%m-%d %H:%M:%S")
        sha = instance.git.rev_list({
          :pretty => :raw, :until => date
        }, branch)
        sha = sha.split("\n")[0]
        find_commit_for(options.merge(:version => sha))
      end
    rescue Grit::GitRuby::Repository::NoSuchShaFound => e
      nil
    end
    
    def find_object_at(path, commit, relative_to = nil)
      path = path_to(path, relative_to)
      object = commit.tree/path || commit.tree/(path+".json")
    end
    
    # Return the physical path within the repository
    # Takes care of symbolic links
    def path_to(path, relative_to = nil)
      if relative_to
        path = File.expand_path( 
          # symlink, e.g. "../../../../grid5000/environments/etch-x64-base-1.0.json"
          path, 
          # e.g. : File.join("/",  File.dirname("grid5000/sites/rennes/environments/etch-x64-base-1.0"))
          File.join('/', File.dirname(relative_to)) 
        ).gsub(/^\//, "")
      end
      File.join(repository_path_prefix, path)
    end
    
    def async_find(*args)
      require 'eventmachine'
      self.extend(EventMachine::Deferrable)
      callback = proc { |result|
        set_deferred_status :succeeded, result
      }
      EM.defer(proc{ find(*args) }, callback)
      self
    end
    
    def versions_for(path, options = {})
      branch, offset, limit = options.values_at(:branch, :offset, :limit)
      branch ||= 'master'
      offset = (offset || 0).to_i
      limit = (limit || 100).to_i
      commits = instance.log(
        branch, 
        path_to(path)
      )
      commits = instance.log(
        branch, 
        path_to(path)+".json"
      ) if commits.empty?
      {
        "total" => commits.length,
        "offset" => offset,
        "items" => commits.slice(offset, limit)
      }
    end
    
    # Fetches the latest changes from the origin repo 
    def reload
      return if reloading?
      @reloading = true
      # TODO: async code to reload repo
    ensure
      @reloading = false
    end
    
    def reloading?
      @reloading == true
    end
    
  end
  
end # module Grid5000