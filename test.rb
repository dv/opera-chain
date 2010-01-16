#!/usr/bin/ruby

require 'rubygems'
gem 'minitest'
require 'minitest/unit'

require 'OperaChain.rb'

MiniTest::Unit.autorun

class OperaChainTest < MiniTest::Unit::TestCase

  def setup
    unless $chain
      puts "Username: ";    username = gets.strip
      puts "Password: ";    password = gets.strip

      $chain = OperaChain.new(username, password)
    end

    @chain = $chain
  end

  def teardown
  end

  def test_login_fail
  end

  def test_not_nil
    refute_nil(@chain)
  end

  def test_add_bookmark_html
  end

  def test_add_bookmark
    title = "Test add_bookmark #{rand(1000)}"
    url = "http://opera.com"
    description = "Opera\nIt's a very nice browser, but needs more plugin support."

    directory = @chain.bookmarks[-1].parent
    sleep 3
    directory.add(title, url, description)

    # Check if the bookmark is added correctly
    bookmark = directory.bookmarks.find do |bookmark|
      bookmark.title == title
    end

    refute_nil(bookmark)
    assert_equal(url, bookmark.url)
    # This does not actually exist: bookmark.description
    # assert_equal(description, bookmark.description)
  end
end
