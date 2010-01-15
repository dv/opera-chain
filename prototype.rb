#!/usr/bin/ruby
#
# Opera Chain Prototype
# =====================
#
# Testground for testing Opera Link with Scrubyt
#
# Note 1: Uninstall the default mechanize gem, and install v0.6.3 for Scrubyt to work:
# 				sudo gem install mechanize -v=0.6.3
# 				sudo gem install hpcricot -v=0.5
# Note 2: Fuck Scrubyt. Support is worthless, doesn't work half the time. It's an interesting concept
#         just not well executed :(
# Note 3: Using Mechanize (and hpricot)
# http://weare.buildingsky.net/2007/02/14/scraping-gmail-with-mechanize-and-hpricot
#
require 'rubygems'
require 'mechanize'

a = WWW::Mechanize.new do |agent|
#  agent.user_agent_alias = 'Opera Chain v0.0'
end

page = a.get('http://link.opera.com/')

form = page.forms.first

puts "Type your username: "
username = gets
puts "Type your password: "
password = gets

form.user = username
form.passwd = password

page = agent.submit form

pp page # pretty print

page = agent.click page.link_with(:text => 'Bookmarks')

# Get first level bookmarks:
page.search('//ul[@id="mob-folders"]//a').each do |link|
  puts link.content + " -> " + link['href']
end

page = agent.click page.link_with(:href => '/relix/account/link/bookmarks/?id=CFF0FB2AB8F0403BB524F77EF43A30E3')



