require 'json'
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

  attr_accessor :previous_run, :next_run, :tag_is_open

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
    unless @active_html_node.parent.nil?
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

    style_attrs = {}
    case paragraph_style&.alignment
    when AppleNote::STYLE_ALIGNMENT_CENTER
      style_attrs["text-align"] = "center"
    when AppleNote::STYLE_ALIGNMENT_RIGHT
      style_attrs["text-align"] = "right"
    when AppleNote::STYLE_ALIGNMENT_JUSTIFY
      style_attrs["text-align"] = "justify"
    end
    if style_attrs.any?
      open_html_tag("div", { style: style_attrs.map { |k, v| "#{k}: #{v}" }.join("; ") })
    end

    # Handle fonts and colors
    style_attrs = {}
    if font
      if font.font_name
        style_attrs["font-family"] = "'#{font.font_name.gsub("'", "\\\\'")}'"
      end
      if font.point_size
        style_attrs["font-size"] = "#{font.point_size}px"
      end
    end
    if color
      style_attrs["color"] = color.full_hex_string
    end
    if style_attrs.any?
      open_html_tag("span", { style: style_attrs.map { |k, v| "#{k}: #{v}" }.join("; ") })
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
        puts "NEW LINE NODE: #{@active_html_node.node_name.inspect}"
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
  def generate_html(text_to_insert, fragment)
    puts "GENERATE HTML TEXT: #{text_to_insert.inspect}"
    puts "GENERATE HTML SELF: #{self.inspect}"
    puts "GENERATE HTML NODE: #{fragment.node_name.inspect}"
    @active_html_node = fragment
    @html_added_tag_depth = 0
    @tag_is_open = !text_to_insert.end_with?("\n")
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
      end
    end

    case paragraph_style&.style_type
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
      if paragraph_style&.indent_amount.to_i > 0
        list_tag = "ul"
        list_attrs = { class: "none" }
      end
    end

    if list_tag
      depth = paragraph_style&.indent_amount.to_i
      unless is_any_list?
        depth -= 1
      end
      puts "DEPTH: #{depth.inspect}"

      inside_li = false
      if paragraph_style&.style_type != previous_run&.paragraph_style&.style_type && paragraph_style&.indent_amount.to_i == 0
        puts "USING ROOT-diff"
        # @active_html_node = @active_html_node.ancestors.last || @active_html_node
      elsif previous_run&.is_any_list? || previous_run&.paragraph_style&.indent_amount.to_i > 0
        if paragraph_style&.indent_amount.to_i > previous_run&.paragraph_style&.indent_amount.to_i || (paragraph_style&.indent_amount.to_i == previous_run&.paragraph_style&.indent_amount.to_i && previous_run&.tag_is_open)
          puts "FINDING LAST LI"
          inside_li = true
          @active_html_node = fragment.last_element_child.css("li").last || fragment
        elsif depth >= 0
          puts "FINDING LAST UL"
          amount = paragraph_style&.indent_amount.to_i
          @active_html_node = fragment.last_element_child.at_xpath(".//*[@data-apple-notes-indent-amount=#{amount}]", "self::node()[@data-apple-notes-indent-amount=#{amount}]") || fragment
          puts "FINDING LAST UL: #{@active_html_node.last_element_child.inspect}"
          puts "FINDING LAST UL: #{paragraph_style&.indent_amount.inspect}"
          puts "FINDING LAST UL: #{@active_html_node.last_element_child.css("[data-apple-notes-indent-amount=#{paragraph_style&.indent_amount.to_i}]").inspect}"
          puts "FINDING LAST UL: #{@active_html_node.inspect}"
        end
      else
        puts "USING ROOT"
      end
      puts "GENERATE HTML ACTIVE NODE: #{@active_html_node.node_name.inspect}"

      indent = paragraph_style&.indent_amount.to_i - previous_run&.paragraph_style&.indent_amount.to_i + 1
      puts "LIST INDENT RAW: #{indent.inspect}"
      if indent <= 0 && (!previous_run&.is_any_list? || paragraph_style&.style_type != previous_run&.paragraph_style&.style_type)
        indent = 1
      end
      puts "LIST INDENT: #{indent.inspect}"

      start = previous_run&.paragraph_style&.indent_amount.to_i
      if inside_li
        start += 1
      end
      puts "NORMAL START: #{start.inspect}"
      start = @active_html_node.attr("data-apple-notes-indent-amount")&.to_i || @active_html_node.ancestors("[data-apple-notes-indent-amount]")&.first&.attr("data-apple-notes-indent-amount")&.to_i
      if start
        start += 1
      else
        start = 0
      end
      puts "HTML START: #{start.inspect}"
      indent_range = (start..paragraph_style&.indent_amount.to_i)
      puts "LIST INDENT RANGE: #{indent_range.inspect}"
      indent_range.each_with_index do |indent_amount, index|
        if index > 0
          open_html_tag("li")
        end

        open_html_tag(list_tag, list_attrs.merge({
          "data-apple-notes-indent-amount" => indent_amount,
        }))
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

=begin
    puts "CLOSING X TIMES: #{@html_added_tag_depth}"
    @html_added_tag_depth.times do
      # puts "CLOSING NODE: #{@active_html_node.inspect}"
      # puts "CLOSING NODE.PARENT: #{@active_html_node.parent.inspect}"
      puts "CLOSING X BEFORE: #{@active_html_node.node_name.inspect}"
      close_html_tag
      puts "CLOSING X AFTER: #{@active_html_node.node_name.inspect}"
    end
=end

    return fragment
  end
end

