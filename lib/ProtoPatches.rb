require_relative 'notestore_pb.rb'

# A little monkey patching never hurt anyone
class ParagraphStyle
  def ==(other_paragraph_style)
    return false if !other_paragraph_style
    same_style_type = (style_type == other_paragraph_style.style_type)
    same_alignment = (alignment == other_paragraph_style.alignment)
    same_indent = (indent_amount == other_paragraph_style.indent_amount)
    same_checklist = (checklist == other_paragraph_style.checklist)

    return (same_style_type and same_alignment and same_indent and same_checklist)
  end
end

class Color
  def red_hex_string
    (red * 255).round().to_s(16).upcase
  end

  def green_hex_string
    (green * 255).round().to_s(16).upcase
  end

  def blue_hex_string
    (blue * 255).round().to_s(16).upcase
  end

  def full_hex_string
    "##{red_hex_string}#{green_hex_string}#{blue_hex_string}"    
  end
end

class AttributeRun

  attr_accessor :previous_run, :next_run

  def has_style_type(style = paragraph_style)
    style and style.style_type
  end

  def same_style?(other_attribute_run)
    return false if !other_attribute_run
    same_paragraph = (paragraph_style == other_attribute_run.paragraph_style)
    same_font = (font == other_attribute_run.font)
    same_font_weight = (font_weight == other_attribute_run.font_weight)
    same_underlined = (underlined == other_attribute_run.underlined)
    same_strikethrough = (strikethrough == other_attribute_run.strikethrough)
    same_superscript = (superscript == other_attribute_run.superscript)
    same_link = (link == other_attribute_run.link)
    same_color = (color == other_attribute_run.color)
    same_attachment_info = (attachment_info == other_attribute_run.attachment_info)

    no_attachment_info = !attachment_info # We don't want to get so greedy with attachments

    # puts "SAME LINK: #{same_link.inspect}"
    # puts "SAME LINK: #{link.inspect}"
    # puts "SAME LINK: #{other_attribute_run.link.inspect}"
    return (same_paragraph and same_font and same_font_weight and same_underlined and same_strikethrough and same_superscript and same_link and same_color and same_attachment_info and no_attachment_info)
  end

  ##
  # This method checks if the previous AttributeRun had the same style_type
  def same_style_type_previous?
    same_style_type?(previous_run)
    # same_style_type?(previous_run) && previous_run.paragraph_style.indent_amount == paragraph_style.indent_amount
  end

  ##
  # This method checks if the next AttributeRun had the same style_type
  def same_style_type_next?
    same_style_type?(next_run)
  end

  ##
  # This method compares the paragraph_style.style_type integer of two AttributeRun 
  # objects to see if they have the same style_type.
  def same_style_type?(other_attribute_run)
    return false if !other_attribute_run

    # We clearly aren't the same if one or the other lacks a style type completely
    return false if (other_attribute_run.has_style_type and !has_style_type)
    return false if (!other_attribute_run.has_style_type and has_style_type)

    # If neither has a style type, that is the same
    return true if (!other_attribute_run.has_style_type and !has_style_type)

    return false if (other_attribute_run.paragraph_style.indent_amount != paragraph_style.indent_amount)

    return false if (is_checkbox? && other_attribute_run.is_checkbox? && other_attribute_run.paragraph_style.checklist.uuid != paragraph_style.checklist.uuid)

    # Compare our style_type to the other style_type and return the result
    return (other_attribute_run.paragraph_style.style_type == paragraph_style.style_type)
    # return (other_attribute_run.paragraph_style.style_type == paragraph_style.style_type && other_attribute_run.paragraph_style.indent_amount == paragraph_style.indent_amount)
  end

  ##
  # Helper function to tell if a given AttributeRun has the same font weight as this one.
  def same_font_weight?(other_attribute_run)
    return false if !other_attribute_run
    return (other_attribute_run.font_weight == font_weight)
  end

  ##
  # Helper function to tell if the previous AttributeRun has the same font weight as this one.
  def same_font_weight_previous?
    same_font_weight?(previous_run)
  end

  ##
  # Helper function to tell if the next AttributeRun has the same font weight as this one.
  def same_font_weight_next?
    same_font_weight?(next_run)
  end

  ##
  # Helper function to tell if a given AttributeRun is an AppleNote::STYLE_TYPE_CHECKBOX.
  def is_checkbox?(style = paragraph_style)
    return (has_style_type(style) and style.style_type == AppleNote::STYLE_TYPE_CHECKBOX)
  end

  ##
  # Helper function to tell if a given AttributeRun is an AppleNote::STYLE_TYPE_NUMBERED_LIST.
  def is_numbered_list?(style = paragraph_style)
    return (has_style_type(style) and style.style_type == AppleNote::STYLE_TYPE_NUMBERED_LIST)
  end

  ##
  # Helper function to tell if a given AttributeRun is an AppleNote::STYLE_TYPE_DOTTED_LIST.
  def is_dotted_list?(style = paragraph_style)
    return (has_style_type(style) and style.style_type == AppleNote::STYLE_TYPE_DOTTED_LIST)
  end

  ##
  # Helper function to tell if a given AttributeRun is an AppleNote::STYLE_TYPE_DASHED_LIST.
  def is_dashed_list?(style = paragraph_style)
    return (has_style_type(style) and style.style_type == AppleNote::STYLE_TYPE_DASHED_LIST)
  end

  ##
  # Helper function to tell if a given AttributeRun is any sort of AppleNote::STYLE_TYPE_X_LIST.
  def is_any_list?(style = paragraph_style)
    return (is_numbered_list?(style) or is_dotted_list?(style) or is_dashed_list?(style) or is_checkbox?(style))
  end

  ##
  # This method calculates the total indentation of a given AttributeRun. It caches the result since
  # it has to recursively check the previous AttributeRuns.
  def total_indent

    to_return = 0

    # Determine what this AttributeRun's indent amount is on its own
    my_indent = 0
    if paragraph_style and paragraph_style.indent_amount
      my_indent = paragraph_style.indent_amount
    end

    # If there is no previous AttributeRun, the answer is just this AttributeRun's indent amount
    if !previous_run
      to_return = my_indent
    # If there is something previous, add our indent to its total indent
    else
      to_return = my_indent + previous_run.total_indent
    end
    
    return to_return
  end

  def open_html_tag(tag_name, attributes = {}, track_depth: true)
    tag = Nokogiri::XML::Node.new(tag_name, @active_html_node.document)
    attributes.each do |key, value|
      tag[key] = value
    end

    @active_html_node = @active_html_node.add_child(tag)

    if track_depth
      @html_added_tag_depth += 1
    end
  end

  def close_html_tag(track_depth: true)
    unless @active_html_node.parent.kind_of?(Nokogiri::XML::Document)
      @active_html_node = @active_html_node.parent
      if track_depth
        @html_added_tag_depth -= 1
      end
    end
  end

  def add_inline_html(text_to_insert)
    begin_html_added_tag_depth = @html_added_tag_depth

    # Deal with the font
    if font_weight
      case font_weight
      when AppleNote::FONT_TYPE_DEFAULT
        # Do nothing
      when AppleNote::FONT_TYPE_BOLD
        if @active_html_node.node_name != "h1" && @active_html_node.node_name != "h2" && @active_html_node.node_name != "h3"
          open_html_tag("b")
        end
      when AppleNote::FONT_TYPE_ITALIC
        open_html_tag("i")
      when AppleNote::FONT_TYPE_BOLD_ITALIC
        if @active_html_node.node_name != "h1" && @active_html_node.node_name != "h2" && @active_html_node.node_name != "h3"
          open_html_tag("b")
        end
        open_html_tag("i")
      end
    end

    # Add in underlined
    if underlined == 1
      open_html_tag("u")
    end

    # Add in strikethrough
    if strikethrough == 1
      open_html_tag("s")
    end

    # Add in superscript
    if superscript == 1
      open_html_tag("sup")
    end

    # Add in subscript
    if superscript == -1
      open_html_tag("sub")
    end

    # Handle fonts and colors
    font_attrs = {}
    color_style = ""
    if font and font.font_name
      font_attrs["face"] = font.font_name
    end
    if color
      font_attrs["color"] = color.full_hex_string
    end
    if font_attrs.any?
      open_html_tag("font", font_attrs)
    end

    if link and link.length > 0
      open_html_tag("a", { href: link, target: "_blank" })
    end

    @active_html_node.add_child(Nokogiri::XML::Text.new(text_to_insert, @active_html_node.document))

    (@html_added_tag_depth - begin_html_added_tag_depth).times do
      close_html_tag
    end
  end

  def add_html_text(text_to_insert)
    text_to_insert.split(/(\u2028|\n)/).each_with_index do |line, i|
      case line
      when "\u2028"
        @active_html_node.add_child(Nokogiri::XML::Node.new("br", @active_html_node.document))
      when "\n"
        case @active_html_node.node_name
        when "pre"
          add_inline_html("\n")
        when "h1", "h2", "h3"
          # Do nothing
        else
          @active_html_node.add_child(Nokogiri::XML::Node.new("br", @active_html_node.document))
        end
      else
        add_inline_html(line)
      end
    end
  end

  ##
  # This method generates the HTML for a given AttributeRun. It expects a String as +text_to_insert+
  def generate_html(text_to_insert, node)
    puts "GENERATE HTML TEXT: #{text_to_insert.inspect}"
    puts "GENERATE HTML SELF: #{self.inspect}"
    puts "GENERATE HTML NODE: #{node.node_name.inspect}"
    @active_html_node = node
    @html_added_tag_depth = 0
    begin_tag_name = @active_html_node.node_name

    if has_style_type and !same_style_type_previous?
      case paragraph_style.style_type
      when AppleNote::STYLE_TYPE_TITLE
        open_html_tag("h1")
      when AppleNote::STYLE_TYPE_HEADING
        open_html_tag("h2")
      when AppleNote::STYLE_TYPE_SUBHEADING
        open_html_tag("h3")
      when AppleNote::STYLE_TYPE_MONOSPACED
        open_html_tag("pre")
      when AppleNote::STYLE_TYPE_NUMBERED_LIST
        list_tag = "ol"
        list_attrs = {}
      when AppleNote::STYLE_TYPE_DOTTED_LIST
        list_tag = "ul"
        list_attrs = { class: "dotted" }
      when AppleNote::STYLE_TYPE_DASHED_LIST
        list_tag = "ul"
        list_attrs = { class: "dashed" }
      when AppleNote::STYLE_TYPE_CHECKBOX
        list_tag = "ul"
        list_attrs = { class: "checklist" }
      else
        if paragraph_style&.indent_amount > 0
          list_tag = "ul"
          list_attrs = { class: "none" }
        end
      end

      if list_tag
        indent = paragraph_style&.indent_amount.to_i - previous_run&.paragraph_style&.indent_amount.to_i
        puts "LIST INDENT RAW: #{indent.inspect}"
        if indent <= 0 && !previous_run&.is_any_list?
          indent = 1
        end
        puts "LIST INDENT: #{indent.inspect}"

        indent.times do |index|
          if index > 0
            open_html_tag("li")
          end

          open_html_tag(list_tag, list_attrs)
        end
      end
    end

    # puts text_to_insert.inspect
    # puts "LINK: #{link.inspect}"
    # puts "LINK has_style_type: #{has_style_type.inspect}"
    # puts "LINK same_style_type_previous?: #{same_style_type_previous?.inspect}"
    # puts "ATTRIBUTE RUN: #{self.inspect}"
    # puts @active_html_node.inspect

    case @active_html_node.node_name
    when "ol", "ul", "li"
      li_attrs = {}
      if is_checkbox?
        li_attrs["class"] = (paragraph_style.checklist.done == 1) ? "checked" : "unchecked"
      end

      # puts "LIST TEXT TO INSERT: #{text_to_insert.inspect}"
      # puts "LIST TEXT TO INSERT node type: #{@active_html_node.node_name.inspect}"
      puts "LIST NODE: #{@active_html_node.node_name.inspect}"
      list_items = text_to_insert.split(/(\n)/)
      list_items.each_with_index do |list_item_text, index|
        if list_item_text == "\n"
          if index != list_items.length - 1
            # close_html_tag(track_depth: false)
            close_html_tag
          end
        else
          if @active_html_node.node_name != "li"
            # open_html_tag("li", li_attrs, track_depth: false)
            open_html_tag("li", li_attrs)
          end

          add_html_text(list_item_text)
        end
      end
    else
      add_html_text(text_to_insert)
    end

    puts "CLOSING X TIMES RAW: #{@html_added_tag_depth}"
    if has_style_type
      indent = paragraph_style&.indent_amount.to_i - next_run&.paragraph_style&.indent_amount.to_i
      indent2 = previous_run&.paragraph_style&.indent_amount.to_i - next_run&.paragraph_style&.indent_amount.to_i
      puts "CLOSING INDENT: #{indent.inspect}"
      puts "CLOSING INDENT2: #{indent2.inspect}"
      puts "CLOSING TAG: #{@active_html_node.node_name.inspect}"
      if @active_html_node.node_name == "li" && indent < 0
        @html_added_tag_depth = 0
      elsif @active_html_node.node_name == "li" && indent >= 0
        if indent > 0
          @html_added_tag_depth += 1
        end

        case begin_tag_name
        when "ol", "ul"
          @html_added_tag_depth += 1
        end
      elsif !same_style_type_previous? && same_style_type_next?
        @html_added_tag_depth -= indent
      elsif same_style_type_previous? && !same_style_type_next?
        @html_added_tag_depth += indent
      end
    end

    puts "CLOSING X TIMES: #{@html_added_tag_depth}"
    @html_added_tag_depth.times do
      # puts "CLOSING NODE: #{@active_html_node.inspect}"
      # puts "CLOSING NODE.PARENT: #{@active_html_node.parent.inspect}"
      puts "CLOSING X BEFORE: #{@active_html_node.node_name.inspect}"
      close_html_tag
      puts "CLOSING X AFTER: #{@active_html_node.node_name.inspect}"
    end


    return @active_html_node
    html = ""
  
    initial_run = false
    initial_run = true if !previous_run
    final_run = false
    final_run = true if !next_run
 
    # Deal with the style type 
    if has_style_type and !same_style_type_previous?
      if is_any_list?
        li_attrs = ""
        if is_checkbox?
          # Set the style to apply to the list item
          li_attrs = " class='unchecked'"
          li_attrs = " class='checked'" if paragraph_style.checklist.done == 1
        end

        if is_any_list?(previous_run&.paragraph_style) && paragraph_style.indent_amount < previous_run.paragraph_style.indent_amount
          html += "<li data-foo='1' #{li_attrs}>"
        elsif is_checkbox? && is_checkbox?(previous_run&.paragraph_style) && paragraph_style.indent_amount == previous_run.paragraph_style.indent_amount
          html += "<li data-foo='2' #{li_attrs}>"
        # elsif is_checkbox? && previous_run&.is_checkbox? && previous_run.paragraph_style.checklist.uuid != paragraph_style.checklist.uuid
          # html += "</li><li#{li_attrs}>"
        else
          indent = 1
          if is_any_list?(previous_run&.paragraph_style) && paragraph_style.indent_amount > previous_run.paragraph_style.indent_amount
            indent = paragraph_style.indent_amount - previous_run.paragraph_style.indent_amount
          end

          case paragraph_style.style_type
          when AppleNote::STYLE_TYPE_NUMBERED_LIST
            html += "<ol><li#{li_attrs}>" * indent
          when AppleNote::STYLE_TYPE_DOTTED_LIST
            html += "<ul class='dotted'><li#{li_attrs}>" * indent
          when AppleNote::STYLE_TYPE_DASHED_LIST
            html += "<ul class='dashed'><li#{li_attrs}>" * indent
          when AppleNote::STYLE_TYPE_CHECKBOX
            html += "<ul class='checklist'><li#{li_attrs}>" * indent
          end
        end
      else
        case paragraph_style.style_type
        when AppleNote::STYLE_TYPE_TITLE
          html += "<h1>"
        when AppleNote::STYLE_TYPE_HEADING
          html += "<h2>"
        when AppleNote::STYLE_TYPE_SUBHEADING
          html += "<h3>"
        when AppleNote::STYLE_TYPE_MONOSPACED
          html += "<code>"
        when AppleNote::STYLE_TYPE_NUMBERED_LIST
          html += "<ol><li>"
        when AppleNote::STYLE_TYPE_DOTTED_LIST
          html += "<ul class='dotted'><li>"
        when AppleNote::STYLE_TYPE_DASHED_LIST
          html += "<ul class='dashed'><li>"
        end
      end
    end

    #if (!is_any_list? and !is_checkbox? and total_indent > 0)
    #  puts "Total indent: #{total_indent}"
    #  html += "\t-"
    #end
  
=begin
    # Handle AppleNote::STYLE_TYPE_CHECKBOX separately because they're special
    if is_checkbox?
      # Set the style to apply to the list item
      style = "unchecked"
      style = "checked" if paragraph_style.checklist.done == 1

      if (initial_run or !previous_run.is_checkbox?)
        html += "<ul class='checklist'><li class='#{style}'>"
      elsif previous_run.paragraph_style.checklist.uuid != paragraph_style.checklist.uuid
        html += "</li><li class='#{style}'>"
      end
    end
=end

    # Deal with the font
    if font_weight
      case font_weight
      when AppleNote::FONT_TYPE_DEFAULT
        # Do nothing
      when AppleNote::FONT_TYPE_BOLD
        html += "<b>"
      when AppleNote::FONT_TYPE_ITALIC
        html += "<i>"
      when AppleNote::FONT_TYPE_BOLD_ITALIC
        html += "<b><i>"
      end
    end

    # Add in underlined
    if underlined == 1
      html += "<u>"
    end

    # Add in strikethrough
    if strikethrough == 1
      html += "<s>"
    end

    # Add in superscript
    if superscript == 1
      html += "<sup>"
    end

    # Add in subscript
    if superscript == -1
      html += "<sub>"
    end
  
    # Handle fonts and colors 
    font_style = ""
    color_style = ""

    if font and font.font_name
      font_style = "face='#{font.font_name}'"
    end

    if color
      color_style = "color='#{color.full_hex_string}'"
    end
 
    if font_style.length > 0 and color_style.length > 0
      html +="<font #{font_style} #{color_style}>"
    elsif font_style.length > 0
      html +="<font #{font_style}>"
    elsif color_style.length > 0
      html +="<font #{color_style}>"
    end

    # Escape HTML in the actual text of the note
    text_to_insert = CGI::escapeHTML(text_to_insert)

=begin
    if (!is_any_list? and !is_checkbox? and total_indent > 0)
      indent = "\u00A0" * (total_indent * 4)
      puts "Total indent: #{total_indent} #{indent.inspect} #{text_to_insert.inspect}"
      text_to_insert.gsub!("\n", "\n#{indent}")
    end
    puts "TO INSERT: #{text_to_insert.inspect}"
=end

    closed_font = false
    need_to_close_li = false
    # Edit the text if we need to make small changes based on the paragraph style
    if is_any_list? and !is_checkbox?
      puts "TEXT TO INSERT: #{text_to_insert.inspect}"
      need_to_close_li = text_to_insert.end_with?("\n") && !is_any_list?(next_run&.paragraph_style)
      text_to_insert = text_to_insert.split("\n").join("</li><li class='2'>")

      # Check it see if we have an open list element...
      if need_to_close_li

        # Also if we're going to need to close a font element...
        if (font_style.length > 0 or color_style.length > 0)
          # ... if so close the font and remember we did so
          #text_to_insert += "</font>"
          #closed_font = true
        end

        # ... then close the list element tag
        #text_to_insert += "</li><li>"
      end
    end

    # Clean up checkbox newlines
    if is_checkbox?
      text_to_insert.gsub!("\n","")
    end

    # Add in links that are part of the text itself, doing this after cleaning the note so the <a> tag lives
    if link and link.length > 0
      text_to_insert = "<a href='#{link}' target='_blank'>#{text_to_insert}</a>"
    end

    # Add the text into HTML finally and start closing things up
    html += text_to_insert

    # Handle fonts
    if font_style.length > 0 or color_style.length > 0
      html +="</font>" if !closed_font
    end

    # Add in subscript
    if superscript == -1
      html += "</sub>"
    end

    # Add in superscript
    if superscript == 1
      html += "</sup>"
    end

    # Add in strikethrough
    if strikethrough == 1
      html += "</s>"
    end

    # Add in underlined
    if underlined == 1
      html += "</u>"
    end

    # Close the font if this is the last AttributeRun or if the next is different
    if font_weight
      case font_weight
      when AppleNote::FONT_TYPE_DEFAULT
        # Do nothing
      when AppleNote::FONT_TYPE_BOLD
        html += "</b>"
      when AppleNote::FONT_TYPE_ITALIC
        html += "</i>"
      when AppleNote::FONT_TYPE_BOLD_ITALIC
        html += "</i></b>"
      end
    end

    if need_to_close_li
      # html += "</li><li class='1'>"
    end

    # Close the style type if this is the last AttributeRun or if the next is different
    # if has_style_type and !same_style_type_next?
    if has_style_type
      if is_any_list?
        indent = 0
        puts "INDENT HTML: #{html.inspect}"
        puts "INDENT AMOUNT: #{paragraph_style.indent_amount.inspect}"
        puts "NEXT RUN INDENT AMOUNT: #{next_run&.paragraph_style&.indent_amount.inspect}"
        indent = paragraph_style.indent_amount - (next_run&.paragraph_style&.indent_amount || 0)

        puts "INDENT: #{indent.inspect}"

        if indent >= 0
          case paragraph_style.style_type
          when AppleNote::STYLE_TYPE_NUMBERED_LIST
            html += "</li></ol>" * indent
            html += "</li>"
            if !is_any_list?(next_run&.paragraph_style)
              html += "</ol>"
            end
          when AppleNote::STYLE_TYPE_DOTTED_LIST, AppleNote::STYLE_TYPE_DASHED_LIST, AppleNote::STYLE_TYPE_CHECKBOX
            html += "</li></ul>" * indent
            html += "</li>"
            if !is_any_list?(next_run&.paragraph_style)
              puts "HTML: #{html.inspect}"
              puts "NEXT_RUN: #{next_run&.paragraph_style.inspect}"
              html += "</ul>"
            end
          end
        end


=begin
        if !is_any_list?(next_run&.paragraph_style)
        end

        if is_any_list?(next_run&.paragraph_style) && next_run.paragraph_style.indent_amount < paragraph_style.indent_amount
          case paragraph_style.style_type
          when AppleNote::STYLE_TYPE_NUMBERED_LIST
            html += "</li></ol></li>"
          when AppleNote::STYLE_TYPE_DOTTED_LIST, AppleNote::STYLE_TYPE_DASHED_LIST, AppleNote::STYLE_TYPE_CHECKBOX
            html += "</li></ul></li>"
          end
        elsif is_any_list?(next_run&.paragraph_style) && next_run.paragraph_style.indent_amount > paragraph_style.indent_amount
          html += ""
        elsif is_any_list?(next_run&.paragraph_style) && next_run.paragraph_style.indent_amount == paragraph_style.indent_amount
          html += "</li>"
        else
          case paragraph_style.style_type
          when AppleNote::STYLE_TYPE_NUMBERED_LIST
            html += "</li></ol>" * (paragraph_style.indent_amount)
            html += "</li>"
            if !is_any_list?(next_run&.paragraph_style)
              html += "</ol>"
            end
          when AppleNote::STYLE_TYPE_DOTTED_LIST, AppleNote::STYLE_TYPE_DASHED_LIST, AppleNote::STYLE_TYPE_CHECKBOX
            html += "</li></ul>" * (paragraph_style.indent_amount)
            html += "</li>"
            if !is_any_list?(next_run&.paragraph_style)
              puts "HTML: #{html.inspect}"
              puts "NEXT_RUN: #{next_run&.paragraph_style.inspect}"
              html += "</ul>"
            end
          end
        end
=end
      else
        case paragraph_style.style_type
        when AppleNote::STYLE_TYPE_TITLE
          html += "</h1>\n" 
        when AppleNote::STYLE_TYPE_HEADING
          html += "</h2>\n" 
        when AppleNote::STYLE_TYPE_SUBHEADING
          html += "</h3>\n" 
        when AppleNote::STYLE_TYPE_MONOSPACED
          html += "</code>" 
        end
      end
    end

    puts "HTML: #{html.inspect}"
    html.gsub!(/<h1>\s*<\/h1>/,'') # Remove empty titles
    html.gsub!(/<u><\/u>/,'') # Remove empty list elements
    html.gsub!(/<s><\/s>/,'') # Remove empty list elements
    html.gsub!(/<sup><\/sup>/,'') # Remove empty list elements
    html.gsub!(/<sub><\/sub>/,'') # Remove empty list elements
    html.gsub!(/<b><\/b>/,'') # Remove empty list elements
    html.gsub!(/<i><\/i>/,'') # Remove empty list elements
    html.gsub!(/<b><i><\/i><\/b>/,'') # Remove empty list elements
    html.gsub!(/<li><\/li>/,'') # Remove empty list elements
    html.gsub!(/\n<\/h1>/,'</h1>') # Remove extra line breaks in front of h1
    html.gsub!(/\n<\/h2>/,'</h2>') # Remove extra line breaks in front of h2
    html.gsub!(/\n<\/h3>/,'</h3>') # Remove extra line breaks in front of h3
    html.gsub!("\u2028",'<br/>') # Translate \u2028 used to denote newlines in lists into an actual HTML line break



    return html
  end
end

