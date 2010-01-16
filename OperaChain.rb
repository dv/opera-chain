#!/usr/bin/ruby
#
# Opera Chain Prototype
# =====================
#
# Testground for testing Opera Link
#
# Note 1: Uninstall the default mechanize gem, and install v0.6.3 for Scrubyt to work:
# 				sudo gem install mechanize -v=0.6.3
# 				sudo gem install hpcricot -v=0.5
# Note 2: Fuck Scrubyt. Support is worthless, doesn't work half the time. It's an interesting concept
#         just not well executed :(
# Note 3: Using Mechanize (and hpricot)
# http://weare.buildingsky.net/2007/02/14/scraping-gmail-with-mechanize-and-hpricot
#     and nokogiri!
#
# Note 4: Apparently Opera does throttle a bit, I haven't figured out the smallest possible delays yet, 
#         but 10s is sufficient, apparently.
#
# Note 5: Throttling is unecessary but recommended anyway not to annoy Opera. Set at 1s
#
# Note 6: You cannot add folders using Opera Link. Also, it doesn't work with tags. So for example, in an
#         implementation to sync with delicious.com, one could use Directories for tags. For every tag one
#         wants to sync in Opera, one needs to create the Directory manually. Nested Directories act like
#         double tags, e.g.
#
#             Bookmarks -> Design > Fonts
#
#         will contain all bookmarks from delicious tagged with "design" and "fonts".
#
# Note 7: While subfolders is already contained in the source, we'll visit the pages anyway. This is easier
#         to parse and we need to check the bookmarks in the directories anyway.
#
# Note 8: Disregard that, we'll create all the bookmarkdirectories in one go.
#
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

  def bookmarks   # Copy of OperaBookmark.all_bookmarks. Maybe make a link?
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

  def bookmarks
    cache unless @cached

    @bookmarks
  end

  def all_bookmarks
    if block_given?
      @bookmarks.each do |bookmark|
        yield bookmark
      end

      directory.children.each do |subnode|
        all_bookmarks(subnode) do |bookmark|
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

    @add_link = page.link_with(:text => "Add a bookmark in this folder")
    page.search('//li[@class="xfolkentry"]').each do |node|
      @bookmarks << OperaBookmark.new(@agent, node, self)
    end
  end

end

class OperaBookmark
  attr_reader :title, :url, :parent
  
  # Node is returned by nokogiri
  #
  # <li class="xfolkentry">
  # <a href="/relix/account/link/bookmarks/delete/delete.pl?id=A9DDE925A8D740328C78256549CBE773&amp;key=7341839ded7167406cbeb124da00995288fd2a08" title="delete bookmark" class="delete"><img src="http://my.opera.com/community/graphics/account/icon-delete.gif" width="17" height="15" alt="delete bookmark"></a><a href="/relix/account/link/bookmarks/editbookmark/?id=A9DDE925A8D740328C78256549CBE773" title="edit bookmark" class="ed"><img src="http://my.opera.com/community/graphics/account/icon-edit.gif" height="15" alt="edit bookmark"></a><a href="http://redir.opera.com/bookmarks/kayak" class="taggedlink" target="_blank"><img src="favicon.pl?key=9cfb084676a5a9ca84f381aa248dc064" width="16" height="16" alt=""><span>Kayak</span></a>
  # </li>
  #
  #
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


# Add bookmark
#root_node.children[2].add("Crowdway", "http://crowdway.com/", "Best site in the universe!")

#all_bookmarks(root_node) do |bookmark|
#  puts bookmark.title

#  if bookmark.title == "Test 1111"
#    puts " --> Changing to 'Oink Oink'"
#    bookmark.title = "Oink Oink"
#  end
#end



# Go to the first folder
#page.search('//li[@class="xfolkentry"]//
