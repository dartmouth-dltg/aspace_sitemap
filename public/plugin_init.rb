Plugins::extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))

Rails.application.config.after_initialize do
  # copy the sitemaps into the WAR space
  if Rails.root.basename.to_s == 'WEB-INF'  # only need to do this when running out of unpacked .war
    dest = Rails.root.dirname
    if dest.directory? && dest.writable?
      sitemap_files = File.join("#{ASUtils.find_local_directories(nil, 'aspace_sitemap').shift}","frontend","assets","sitemaps","*.xml")
      FileUtils.cp_r Dir.glob(sitemap_files), dest, :verbose => true
    end
    
    # add the rails root to plugin space so that backend can grab it for writing to the war when job runs
    File.open(File.join("#{ASUtils.find_local_directories(nil, 'aspace_sitemap').shift}","frontend","assets","sitemaps","rails_path_to_pui.txt"), "w+") do |f|
      f.write(Rails.root.to_s)
      f.close
    end
    
    robtxt = Pathname.new( dest + 'robots.txt' )
    sitemap_index = Pathname.new( dest + 'sitemap-index.xml' )
    if robtxt.exist? && robtxt.file? && sitemap_index.exist? && sitemap_index.file? && dest.directory? && dest.writable?
      sitemap_root_loc = File.join("#{AppConfig[:public_proxy_url]}","sitemap-index.xml")
      p "*********    #{robtxt} and #{sitemap_index} exist: checking for sitemap entry ****** "
      if File.foreach(robtxt).detect { |line| line =~ /sitemap/i }
        contents = File.read(robtxt)
        File.write(robtxt, contents.gsub(/sitemap.*$/i, "Sitemap: #{sitemap_root_loc}\n"))
      else
        File.open(robtxt, 'a') { |f|
          f.write("\nSitemap: #{sitemap_root_loc}\n")
        }
      end
      p "*********    updated #{robtxt} with sitemap entry for #{sitemap_index} ****** "
    end
  end
end