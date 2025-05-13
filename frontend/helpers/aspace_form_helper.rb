module AspaceFormHelper
  class FormContext


    # fix layout for labels that are not inline
    def label_vertical(name, opts = {}, classes = [])
      prefix = ''
      prefix << "#{opts[:contextual]}." if opts[:contextual]
      prefix << 'plugins.' if opts[:plugin]

      classes << 'control-label'

      options = {:class => classes.join(' '), :for => id_for(name)}

      unless (tooltip = tooltip(name, prefix)).empty?
        add_tooltip_options(tooltip, options)
      end

      attr_string = options.merge(opts || {})
                      .map {|k, v| '%s="%s"' % [CGI::escapeHTML(k.to_s),
                                                CGI::escapeHTML(v.to_s)]}
                      .join(' ')
      content = CGI::escapeHTML(I18n.t(prefix + i18n_for(name, opts[:ignore_form_context])))
      "<label #{attr_string}>#{content}</label>".html_safe
    end
    
    # pilfered from OAI checkboxes
    def label_and_multi_boolean(name, items, opts = {}, default = false, force_checked = false)

      html = ""
      html << "<div class='form-group'>"
      html << label_vertical("sitemap_types", {}, ["control-label", "col"])
      html << "<div class='col'>"
      html << "<ul class='checkbox-list'>"
      items.each do |v|
        # if we have an empty list of checkboxes, assume all sets are enabled.
        # otherwise, a checkbox is on if it's the in the list we get from the backend.

        html << "<li class='list-group-item'>"
        html << "<div class='checkbox'>"
        html << "<label>"
        html << "<input id=\"#{id_for(name)}_#{v}\" name=\"#{path(name)}[]\" value=\"#{v}\" type=\"checkbox\" "

        if force_checked or (obj[name] === true) or (obj[name].is_a? String and obj[name].start_with?("true")) or (obj[name] === "1") or (obj[name].nil? and default)
          html << "checked=\"checked\" "
        end

        if readonly?
          html << "disabled />"
        else
          html << "/>"
        end # of checkbox tag

        html << "#{I18n.t("aspace_sitemap_job.sitemap_types_#{v}")}"
        html << "</label>"
        html << "</div>"
        html << "</li>"
      end
      html << "</ul>"
      html << "</div>" #col-sm-9
      html << "</div>" #form-group

      html.html_safe
     
    end

  end
end
