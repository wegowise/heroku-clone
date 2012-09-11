module Heroku::Command

  class Clone < BaseWithApp

    def index
      old_app = app
      puts "Cloning #{old_app}"

      old_stack = api.get_app(old_app).body['stack']

      step "creating application"

      new_app = extract_option("--name")

      api.post_app(:stack => old_stack, :name => new_app)
      step "new app: #{new_app}", 2

      step "cloning addons"
      clone_addons(old_app, new_app)

      step "cloning configuration"
      clone_configuration(old_app, new_app)

      step "cloning repository"
      clone_repository(old_app, new_app)

      step "cloning collaborators"
      clone_collaborators(old_app, new_app)
    end

  private ######################################################################

    def clone_addons(old_app, new_app)
      old_addons = api.get_addons(old_app).body.map { |a| a["name"] }
      current_addons = api.get_addons(new_app).body.map { |a| a["name"] }

      (old_addons - current_addons).each do |addon|
        step "installing #{addon}", 2
        begin
          api.post_addon(new_app, addon)
        rescue Exception => e
          print "* could not install #{addon}: #{e.message}"
        end
      end
    end

    def clone_configuration(old_app, new_app)
      old_config = api.get_config_vars(old_app).body
      api.put_config_vars(new_app, old_config)
      old_config.keys.sort.each { |key| step(key, 2) }
    end

    def clone_repository(old_app, new_app)
      tempfile = Tempfile.new("heroku-clone")
      tempdir = tempfile.path
      tempfile.delete
      FileUtils.mkdir_p(tempdir)
      Dir.chdir(tempdir) do
        %x{ git clone git@#{heroku.host}:#{old_app}.git . }
        %x{ git remote add clone git@#{heroku.host}:#{new_app}.git }
        %x{ git push clone master }
      end
     FileUtils.rm_rf(tempdir)
    end

    def clone_collaborators(old_app, new_app)
      old_collabs = api.get_collaborators(old_app).body.map { |c| c['email'] }
      new_collabs = api.get_collaborators(new_app).body.map { |c| c['email'] }
      (old_collabs - new_collabs).each do |collab|
        step "adding #{collab}", 2
        api.post_collaborator(new_app, collab)
      end
    end

    def step(message, indent=1)
      print "  " * indent
      print "* "
      puts message
    end

    def extract_option(options, default=true)
      values = options.is_a?(Array) ? options : [options]
      return unless opt_index = args.select { |a| values.include? a }.first
      opt_position = args.index(opt_index) + 1
      if args.size > opt_position && opt_value = args[opt_position]
        if opt_value.include?('--')
          opt_value = nil
        else
          args.delete_at(opt_position)
        end
      end
      opt_value ||= default
      args.delete(opt_index)
      block_given? ? yield(opt_value) : opt_value
    end   
  end
end
