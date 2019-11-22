class StaticPagesController < ApplicationController
  
  def page
    page_file = File.join(File.dirname(__FILE__), '..', 'pages', params[:page]+'.'+params[:format])
    if File.exists?(page_file)
      respond_to do |format|
        format.html
        format.xml { render :xml => File.read(page_file)}
      end
    else
      @page = "Couldn't find static page file: #{params[:page]}"
    end
  end

end
