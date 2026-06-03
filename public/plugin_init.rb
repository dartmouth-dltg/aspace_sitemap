Plugins::extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))

  AI_BOTS = [
    { name: "OpenAI - GPTBot",              ua: "GPTBot" },
    { name: "OpenAI - ChatGPT browsing",    ua: "ChatGPT-User" },
    { name: "OpenAI - OAI-SearchBot",       ua: "OAI-SearchBot" },
    { name: "Anthropic - ClaudeBot",        ua: "ClaudeBot" },
    { name: "Anthropic - Claude-Web",       ua: "Claude-Web" },
    { name: "Google - Gemini/Bard training",ua: "Google-Extended" },
    { name: "Meta - FacebookBot",           ua: "FacebookBot" },
    { name: "Apple - Applebot-Extended",    ua: "Applebot-Extended" },
    { name: "Common Crawl",                 ua: "CCBot" },
    { name: "Cohere AI",                    ua: "cohere-ai" },
    { name: "Perplexity",                   ua: "PerplexityBot" },
    { name: "You.com",                      ua: "YouBot" },
    { name: "Diffbot",                      ua: "Diffbot" },
    { name: "ByteDance - Bytespider",       ua: "Bytespider" },
    { name: "Amazon - Alexa AI",            ua: "Amazonbot" },
    { name: "Timpibot",                     ua: "Timpibot" },
    { name: "ImagesiftBot",                 ua: "ImagesiftBot" },
    { name: "SleepBot",                     ua: "SleepBot" },
    { name: "Semrush",                      ua: "SemrushBot" },

  ].freeze

  def generate_robots_txt
    lines = []

    lines << ""
    lines << "# AI/LLM crawlers blocked, search engines allowed"
    lines << "# Generated on #{Time.now.strftime('%Y-%m-%d')}"
    lines << ""
    lines << "# Block all AI / LLM training crawlers"
    lines << ""

    AI_BOTS.each do |bot|
      lines << "# #{bot[:name]}"
      lines << "User-agent: #{bot[:ua]}"
      lines << "Disallow: /"
      lines << ""
    end

    lines << "# Allow all standard search engines"
    lines << ""
    lines << "User-agent: *"
    lines << "Allow: /"
    lines << ""

    lines.join("\n")
  end

Rails.application.config.after_initialize do
  # copy the sitemaps into the WAR space
  if Rails.root.basename.to_s == 'WEB-INF'  # only need to do this when running out of unpacked .war
    dest = Rails.root.dirname
    if dest.directory? && dest.writable?
      sitemap_files = File.join(AppConfig[:data_directory], "pui_sitemaps","*.xml")
      FileUtils.cp_r Dir.glob(sitemap_files), dest, :verbose => true
    end
    
    # add the rails root to plugin space so that backend can grab it for writing to the war when job runs
    File.open(File.join("#{ASUtils.find_local_directories(nil, 'aspace_sitemap').shift}","frontend","rails_path_to_pui.txt"), "w+") do |f|
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

    if robtxt.exist? && robtxt.file?
      File.open(robtxt, 'a') { |f|
        f.write(generate_robots_txt)
      }
    end
  end
end