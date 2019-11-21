module AspaceFormHelper
  class FormContext
    
    def label_and_multi_boolean(name, items, opts = {}, default = false, force_checked = false)
      opts[:col_size] = 1
      opts[:controls_class] = "checkbox"
      multi_checkbox_html = ""
      items.each do |item|
        multi_checkbox_html << label_with_field(name+"_"+item, multi_checkbox(name, item, opts, default, force_checked), opts)
      end
      multi_checkbox_html.html_safe   
    end
    
    def multi_checkbox(name, item, opts = {}, default = true, force_checked = false)
      options = {:id => "#{id_for(name)}_#{item}", :type => "checkbox", :name => path(name)+"[]", :value => "#{item}"}
      options[:checked] = "checked" if force_checked or (obj[name] === true) or (obj[name].is_a? String and obj[name].start_with?("true")) or (obj[name] === "1") or (obj[name].nil? and default)
  
      @forms.tag("input", options.merge(opts), false, false)
    end
  end
end