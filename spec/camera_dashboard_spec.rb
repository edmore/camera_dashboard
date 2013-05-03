require_relative '../camera_dashboard.rb'
require 'rack/test'
require 'capybara/rspec'

set :environment, :test

def app
  Sinatra::Application
end

def setup
  Capybara.app = Sinatra::Application.new
end

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

feature  "Grid View" do
  setup
  scenario "should display the dashboard" do
    page.driver.browser.authorize 'admin', 'admin'
    visit("/")
    page.should have_content("IP Camera Dashboard")
    page.should have_link("Grid View")
    page.should have_link("Tiled View")
    page.should have_link("Manage")
  end
end

feature  "Tiled View" do
  setup
  scenario "should display the tiled view" do
    page.driver.browser.authorize 'admin', 'admin'
    visit("/tiled")
    page.should have_content("IP Camera Dashboard")
    page.should have_content("Venue")
    page.should have_content("Last Updated")
  end
end

feature "Manage" do
  setup
  scenario "should display the venue information" do
    page.driver.browser.authorize 'admin', 'admin'
    visit("/venues")
    page.should have_content("IP Camera Information")
    page.should have_link("Dashboard")
    page.should have_content("Venue Name")
    page.should have_content("Last Synced")
  end
end
