Plugins::extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))

Rails.application.config.after_initialize do
  # copy the sitemaps into the WAR space
  if Rails.root.basename.to_s == 'WEB-INF'  # only need to do this when running out of unpacked .war
    dest = Rails.root.dirname
    if dest.directory? && dest.writable?
      FileUtils.cp_r Dir.glob("#{ASUtils.find_local_directories(nil, 'aspace_sitemap').shift}/public/pages/*.xml"), dest, :verbose => true
    end
    
    robtxt = Pathname.new( dest + 'robots.txt' )
    sitemap_index = Pathname.new( dest + 'sitemap-index.xml' )
    if robtxt.exist? && robtxt.file? && sitemap_index.exist? && sitemap_index.file? && dest.directory? && dest.writable?
      pui_base_url = AppConfig[:public_proxy_url]
      # make sure the public url ends in a "/"
      unless pui_base_url[-1] == "/"
        pui_base_url += "/"
      end
      p "*********    #{robtxt} and #{sitemap_index} exist: checking for sitemap entry ****** "
      if File.foreach(robtxt).detect { |line| line =~ /sitemap/i }
        contents = File.read(robtxt)
        File.write(robtxt, contents.gsub(/sitemap.*$/i, "Sitemap: #{pui_base_url}sitemap-index.xml\n"))
      else
        File.open(robtxt, 'a') { |f|
          f.write("\nSitemap: #{pui_base_url}sitemap-index.xml\n")
        }
      end
      p "*********    updated #{robtxt} with sitemap entry for #{sitemap_index} ****** "
    end
  end
end