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

a = WWW::Mechanize.new do |agent|
#  agent.user_agent_alias = 'Opera Chain v0.0'
end

# BookmarkTag == Directory
class OperaDirectory
  attr_reader :title, :parent, :children

  def initialize(node, parent = nil)
    @parent = parent
    @link = node.search("./a").first
    @title = @link.content.strip
    @children = []

    # Generate subdirectories
    node.search('./ul/li').each do |sub_node|
      @children << OperaDirectory.new(sub_node, self)
    end
  end


  private

  # Loads the bookmarks and directories in this directory
  def load(recursive = false)
    page = agent.click link
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
  def initialize(node, parent, agent)
    @title = node.search("span").first.content
    @url = node.search("a[@class='taggedlink']").first["href"]
    @edit_link = node.search("a[@class='ed']").first
    @delete_link = node.search("a[@class='delete']").first

    @parent = parent
    @agent = agent
  end

  def title=(title)
     form = edit_form
     form.name = title    # Or "edit-name"?     
     agent.submit form    # Todo: check exceptions
     @title = title

     self
  end
  
  def url=(url)
    form = edit_form
    form.link = url       # Or edit-link? 
    agent.submit form
    @url = url

    self
  end

  def delete
    agent.click delete_link

    self
  end

  private
  
  def edit_form
    edit_page = agent.click edit_link
    edit_page.forms.first
  end
end


# For prototype only: make html_body public so we can
# check the output
class WWW::Mechanize::Page
  public :html_body
end

page = a.get('http://link.opera.com/')

form = page.forms.first

puts "Type your username: "
form.user = gets.strip
puts "Type your password: "
form.passwd = gets.strip

sleep 1
page = a.submit form

if page.title =~ /Login Failed/i
  puts "Login Failed!"
  puts page.html_body
  # Todo: check if we can submit the form here as well
  exit
end
sleep 1
page = a.click page.link_with(:text => 'Bookmarks')

# The following is deprecated:
# Get first level bookmarks directories:
#page.search('//ul[@id="mob-folders"]//a').each do |link|
#  puts link.content + " -> " + link['href']
#end


root_node = OperaDirectory.new(page.search('//ul[@id="folders"]/li').first)      # Root node, "Bookmarks"


# Browse through bookmark directories
def print_node(node, level = 0)
  puts "#{'  ' * level}#{node.title}" 
  node.children.each do |subnode|
    print_node(subnode, level+1)
  end
end

print_node(root_node)

# Go to the first folder
#page.search('//li[@class="xfolkentry"]//
