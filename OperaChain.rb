require 'rubygems'
require 'mechanize'

class OperaChain
  attr_reader :username, :password, :root
  def initialize(username, password)
    @username = username
    @password = password

    @agent = WWW::Mechanize.new do |agent|
      agent.redirect_ok = true
      agent.follow_meta_refresh = true
      agent.user_agent = "Opera Chain v0.0"
    end

    page = @agent.get('http://link.opera.com/')
    form = page.forms.first
    form.user = @username
    form.passwd = @password
    sleep 3
    page = @agent.submit form

    raise "login failed" if page.title =~ /Login Failed/i

    sleep 3
    page = @agent.click page.link_with(:text => 'Bookmarks')

    @root = OperaDirectory.new(@agent, page.search('//ul[@id="folders"]/li').first)      # Root node, "Bookmarks"
  end

  def bookmarks   # Copy of OperaDirectory.all_bookmarks. Maybe make a link?
    if block_given?
      @root.all_bookmarks do |bookmark|
        yield bookmark
      end
    else
      @root.all_bookmarks
    end
  end

  def to_s
    @root.to_s
  end
end



# BookmarkTag == Directory
class OperaDirectory
  attr_reader :title, :parent, :children

  def initialize(agent, node, parent = nil)
    @agent = agent
    @parent = parent
    @link = node.search("./a").first
    @add_link = nil 
    @title = @link.content.strip
    @children = []
    @bookmarks = []
    @cached = false

    # Generate subdirectories
    node.search('./ul/li').each do |sub_node|
      @children << OperaDirectory.new(@agent, sub_node, self)
    end
  end

  def refresh
    @cached = false
  end

  def bookmarks
    cache unless @cached

    @bookmarks
  end

  def all_bookmarks
    if block_given?
      bookmarks.each do |bookmark|
        yield bookmark
      end

      children.each do |subnode|
        subnode.all_bookmarks do |bookmark|
          yield bookmark
        end
      end    
    else
      result = []
      all_bookmarks do |bookmark|
        result << bookmark
      end

      result
    end
  end

  def add(title, link, description = "")
    cache unless @cached

    page = @agent.click @add_link
    form = page.forms.first
    form["name"] = title      # Manual selector because name() is a function
    form.link = link
    form.desc = description
    sleep 3
    page = form.click_button
    cache(page)
  end

  def to_s(level = 0)
    result = "#{'  ' * level}#{@title}\n" 
    bookmarks.each do |bookmark|
      result << "#{'  ' * (level)} - #{bookmark.title}\n"
    end
    @children.each do |subdir|
      result << subdir.to_s(level+1)
    end

    result
  end


  private

  # Loads the bookmarks in this directory
  def cache(page = nil)
    @cached = true
    @bookmarks.clear 
    page ||= @agent.click @link

    unless page.search("//img[@src='http://my.opera.com/community/graphics/link/screens.jpg']").empty?
      # Opera burped and gave us the wrong page. Retry, with throttling.
      puts "Burp!"
      sleep 3
      cache
    else
      @add_link = page.link_with(:text => "Add a bookmark in this folder")
      page.search('//li[@class="xfolkentry"]').each do |node|
        @bookmarks << OperaBookmark.new(@agent, node, self)
      end
    end
  end

end

class OperaBookmark
  attr_reader :title, :url, :parent
  
  def initialize(agent, node, parent)
    @title = node.search("span").first.content
    @url = node.search("a[@class='taggedlink']").first["href"]
    @edit_link = node.search("a[@class='ed']").first
    @delete_link = node.search("a[@class='delete']").first

    @parent = parent
    @agent = agent
  end

  def title=(title)
     form = edit_form
     form["name"] = title
     form.click_button    # Todo: check exceptions
     @title = title

     self
  end
  
  def url=(url)
    form = edit_form
    form.link = url
    form.click_button
    @url = url

    self
  end

  def delete
    @agent.click @delete_link
    @parent.children.delete(self)
    self
  end

  private
  
  def edit_form
    edit_page = @agent.click @edit_link
    edit_page.forms.first
  end
end
