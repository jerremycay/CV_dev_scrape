require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'logger'


########
# This function scrapes the user data.
# Entry point is at get_user_courses
# Implemented until reaching the selection af semester to retrieve its courses.
# To understand the flow, you can call on each page: puts page.uri.to_s 
######

class UserScraper
  attr_accessor :agent, :scrape_logger
  def initialize(attributes = {})
    @scrape_logger = Logger.new("user_scraper.log")
    @scrape_logger.level = Logger::DEBUG
    @scrape_logger.info("run start.")
    @agent = Mechanize.new { |a| a.log = Logger.new("user_mech.log") }
    @agent.user_agent_alias = 'Windows IE 7'
    puts "Scraper was initialized."
  end
  
end

class IdcUserScraper < UserScraper
  attr_accessor :initial_user_page, :query_counter
  def initialize(attributes = {})
    super
    @query_counter = 0
    # to do - make the login here and init initial_user_page
    @agent.follow_meta_refresh = true
    puts "IdcUserScraper was initialized."
  end
  
  def retrieve_url(url, max_tries=15, sleep_sec_before=1.4, sleep_sec_on_failure=72)
    try = 0
    sleep sleep_sec_before
    begin
      try += 1
      @query_counter += 1
      return @agent.get(url)
    rescue => exception
      exception_data = "\n\n#{exception.class}: #{exception.message}\n    from " + exception.backtrace.join("\n    from ") + "\n\n"
      if try.to_i < max_tries 
        @scrape_logger.warn("Couldn't fatch url #{url} on #{try} try. Sleeping for #{sleep_sec_on_failure} seconds and retrying...")
        sleep sleep_sec_on_failure
        @scrape_logger.debug("Woke up and retrying...")
        retry
      else
        @scrape_logger.error("Couldn't fatch url #{url} on #{try} try. Aborting!")
        raise
      end
    end
  end

  # This func will return the extracted school data parsed
  # To do - implement!
   def parse_user_data(user_data)
     parsed_user_data = user_data
     return parsed_user_data
   end
   
   # To do - implement!
   def insert_user_data_to_db(user_data) 
   end
  
   # This func logs in and returns the home page of the user after logging in.
   def login_and_get_initial_page(user_name, password)
     login_page = retrieve_url("https://my.idc.ac.il/my.policy")
     # Check if moved to error page already, and return to main page.
     if login_page.uri.to_s == "https://my.idc.ac.il/my.logout.php3?errorcode=19" || login_page.uri.to_s == "https://my.idc.ac.il/my.logout.php3?errorcode=19"
       @scrape_logger.info("#{__method__} - arrived session TO page on login. Clicking link to return...")
       puts "#{__method__} - arrived session TO page on login. Clicking link to return..." # to do remove
       login_page = login_page.link_with(:text=>"click here.").click
     end
     if login_page.uri.to_s != "https://my.idc.ac.il/my.policy"
       raise "failed_to_reach_login_page_exception uri:#{login_page.uri.to_s}"
     end
     login_form = login_page.form("e1")
     if nil == login_form
       raise "couldnt_find_login_form_exception #{}"
     end
     
     login_form.username = user_name
     login_form.password = password
     user_home_page = agent.submit(login_form, login_form.buttons.first)
     # to do - make a better login check, like looking for the login error message
     # maybe look for some contents inside too
     if user_home_page.uri.to_s != "http://my.idc.ac.il/idsocial/he/Pages/homepage.aspx"
       raise "couldnt_login_form_exception uri:#{user_home_page.uri.to_s}"
     end
     
     return user_home_page
   end
   
   def get_semester_selection_page(user_home_page)
     page1 =   user_home_page.link_with(:text => "תחנת מידע ורישום לקורסים").click
     iframe = page1.iframe_with(:src => %r{http://www.idc.ac.il/MyHomePage/informationService/logStudentServicesYedionHebIDSocial.asp\?uid=})
     # The uid can be extracted with: uid = %r{uid=(\d+)}.match(iframe.src)
     page2 = retrieve_url(iframe.src)
     redirecting_page = page2.form.submit
     user_welcome_page = redirecting_page.form.submit
     select_menu_iframe_src = user_welcome_page.iframe_with(:src => %r{fireflyweb.aspx?}).src
     select_menu_page = retrieve_url(select_menu_iframe_src)
     semester_selection_page = select_menu_page.link_with(:text => %r{רשימת מערכת שעות}).click
     return semester_selection_page
   end
   
   # To do - implement!
   def get_years_semesters_hash(semester_selection_page)
     years_semeters_hash = []
     return years_semeters_hash
   end
   
   # To do - implement!
   def get_lessons_scedule(lessons_schedule_page)
     lessons_scedule_for_semester = []
     return lessons_scedule_for_semester
   end
   
   # Class entry point...
   def get_user_courses(user_name="frank.kesem", password= "naftasucks")
     user_home_page = login_and_get_initial_page(user_name, password)
     semester_selection_page = get_semester_selection_page(user_home_page)
     # To do - implement!
     #years_semeters_hash = get_years_semesters_hash
     #temp return
     return semester_selection_page
   end
   
   
end


# Debugging helper function.
# Paste them into the terminal (irb) and run.
# Change function return values and check them for debuggings.
# Remove when finished
def console_funcs
  require "idc_user_scrape"    
  scr = IdcUserScraper.new
  semester_selection_page = scr.get_user_courses()
  
  # dump page to file
  output = File.open("login.html", "w+") {|f| f.write(user_home_page.parser.to_html) }
  
end

