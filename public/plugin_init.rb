Plugins::extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))

Rails.application.config.after_initialize do
  # copy the sitemaps into the WAR space
  if Rails.root.basename.to_s == 'WEB-INF'  # only need to do this when running out of unpacked .war
    dest = Rails.root.dirname
    if dest.directory? && dest.writable?
      FileUtils.cp_r Dir.glob("#{ASUtils.find_local_directories(nil, 'aspace_sitemap').shift}/public/pages/*.xml"), dest, :verbose => true
    end
    #robtxt = ((Pathname.new AppConfig.find_user_config).dirname + 'robots.txt' )
    #
    #if robtxt.exist? && robtxt.file? && dest.directory? && dest.writable?
    #  p "*********    #{robtxt} exists: copying to #{dest} ****** "
    #  FileUtils.cp( robtxt, dest, :verbose => true  )
    #end
  end
end