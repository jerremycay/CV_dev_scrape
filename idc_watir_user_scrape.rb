require 'rubygems'
require 'watir-webdriver'
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
    @agent = Watir::Browser.new :ff
    puts "Scraper was initialized."
  end
  
end

class IdcUserScraper < UserScraper
  attr_accessor :initial_user_page, :query_counter
  def initialize(attributes = {})
    super
    @query_counter = 0
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
     url = agent.goto("https://my.idc.ac.il/my.policy")
       # Check if moved to error page already, and return to main page.
       if url == "https://my.idc.ac.il/my.logout.php3?errorcode=19" || url == "https://my.idc.ac.il/my.logout.php3?errorcode=20"
         @scrape_logger.info("#{__method__} - arrived session TO page on login. Clicking link to return...")
         puts "#{__method__} - arrived session TO page on login. Clicking link to return..." # to do remove
         agent.link(:text=>"click here.").click
       end
       if agent.url != "https://my.idc.ac.il/my.policy"
         raise "failed_to_reach_login_page_exception uri:#{agent.url}"
       end
     login_form = agent.form(:id => "auth_form")
     if nil == login_form
      raise "couldnt_find_login_form_exception #{}"
     end
     login_form.text_field(:name=>"username").set(user_name)
     login_form.text_field(:name=>"password").set(password)
     login_form.submit

     #There is a session timeout on login many times. we try again...
     if agent.url == "https://my.idc.ac.il/my.logout.php3?errorcode=20"
       puts "session expired login problem"
       agent.link(:text=>"click here.").click
       login_form = agent.form(:id => "auth_form")
       login_form.text_field(:name=>"username").set(user_name)
       login_form.text_field(:name=>"password").set(password)
       login_form.submit
     end
     # to do - make a better login check, like looking for the login error message, session TO/wrong pass
     # maybe look for some contents inside too
     if agent.url != "http://my.idc.ac.il/idsocial/he/Pages/homepage.aspx"
       raise "couldnt_login_form_exception uri:#{agent.url}"
     end
   end

   def get_semester_selection_page()
     #agent.td(:xpath => ".//*[@id='nav']/li[5]/table/tbody/tr/td[1]").fire_event("onmouseover")
     #agent.span(:text => "סטודנטים").fire_event("onmouseover")
     #agent.fire_event("arrowOver('ctl00_IDCNewTopNavigation_g_e43a7861_bd5b_442b_bcad_a7e87ec66223_arrowImg_64','/_layouts/STYLES/IDsocial/hp/he/arrow_mm_blue.gif');")
     #agent.link(:text => "תחנת מידע ורישום לקורסים").click
     #agent.frame(:src => %r{http://www.idc.ac.il/MyHomePage/informationService/logStudentServicesYedionHebIDSocial.asp\?uid=})
     # The uid can be extracted with: uid = %r{uid=(\d+)}.match(iframe.src)
     #redirecting_page = page2.form.submit
     #user_welcome_page = redirecting_page.form.submit
     agent.goto "http://my.idc.ac.il/idsocial/he/Pages/application.aspx?aid=44"
     link = agent.frame(:id => "ContextMenuFrame").link(:text => %r{רשימת מערכת שעות})
     agent.goto(link.href)
   end



   # Change the conditions in this func to scrape other semesters
   def filter_semester_list(semester_list_selector)
      semester_list = []
      semester_list_selector.options.each do |semester|
        if semester.text == 'א' || semester.text == 'ב' || semester.text == 'ג' || semester.text == 'שנתי'
          semester_list << {:text => semester.text, :value => semester.value}
        else
          @scrape_logger.debug("method #{__method__} - semester #{semester.text} was ignored")
        end

      end
      return semester_list
   end

  # Change the conditions in this func to scrape other years
   def filter_years_list(year_list_selector)
      year_list = []
      year_list_selector.options.each do |year|
        if year.text.match(/ - (\d+)/)[1].to_i > 2005
          year_list << {:text => year.text, :value => year.value}
        else
          @scrape_logger.debug("method #{__method__} - year #{year.text} was ignored")
        end

      end
      return year_list
   end

   # To do - implement!
   def get_years_semesters_hash(form)
     years_semesters_hash = []
     years_list = filter_years_list(form.select_list(:id=>"R1C1"))
     semesters_list = filter_semester_list(form.select_list(:id=>"R1C2"))
     years_list.each do |year|
       years_semesters_hash << {:value => year[:value], :name => year[:text], :semesters => semesters_list}
     end

     return years_semesters_hash
   end

   def get_trimmed_cell_data(cell)
    return cell.text.strip.gsub("\302\240",'')
   end

   # The function extracts the lessons data on a valid semester page
   def extract_semester_lessons_data(page)
     lessons_schedule_for_semester = []
     lesson_lines = page.css("#myTable0 tbody tr")
     # Validate
     if lesson_lines.length.to_i == 0
       @scrape_logger.warn("method #{__method__} - less than 1 line in lessons table")
       return lessons_schedule_for_semester
     end

     lesson_lines.each do |line|
       lesson_cells = line.css("td")
       lessons_schedule_for_semester << {:semester => get_trimmed_cell_data(lesson_cells[0]),
                                         :short_code => get_trimmed_cell_data(lesson_cells[1]),
                                         :name => get_trimmed_cell_data(lesson_cells[2]),
                                         :type => get_trimmed_cell_data(lesson_cells[3]),
                                         :teacher => get_trimmed_cell_data(lesson_cells[4]),
                                         :points => get_trimmed_cell_data(lesson_cells[5]),
                                         :weekly_hours => get_trimmed_cell_data(lesson_cells[6]),
                                         :time => get_trimmed_cell_data(lesson_cells[7]),
                                         :room => get_trimmed_cell_data(lesson_cells[8]),
                                         :full_code => get_trimmed_cell_data(lesson_cells[9]),
                                         :school => get_trimmed_cell_data(lesson_cells[10]),
                                         :site => get_trimmed_cell_data(lesson_cells[11])}
     end

     return lessons_schedule_for_semester
   end

   # The function submits the form for the required year/semester, checks the page validity, sends the pae to
   def get_semester_data(form, year, semester)
     lessons_schedule_for_semester = []
     form.select_list(:id=>"R1C1").option(:value => year).select
     form.select_list(:id=>"R1C2").option(:value => semester).select
     form.button(:class =>"sbttn").click

     #Check if there are lessons on this semester
     if agent.h1(:xpath => "/html/body/table[2]/tbody/tr/td/table/tbody/tr/td/h1").exist? &&
         agent.h1(:xpath => "/html/body/table[2]/tbody/tr/td/table/tbody/tr/td/h1").text.match(/אין רישומים לקורסים במסגרת התחום שהוכנס/)
       @scrape_logger.debug("method #{__method__} - no lessons for year #{year} semester #{semester}")
       return nil
     end

     #Check if it is a valid lessons page
     if !agent.h1(:xpath => "/html/body/table[2]/tbody/tr/td/table[2]/tbody/tr/td/h1").exists? ||
       !agent.h1(:xpath => "/html/body/table[2]/tbody/tr/td/table[2]/tbody/tr/td/h1").text.match(/רשימת מערכת שעות שנה/)
       @scrape_logger.warn("method #{__method__} - unknown page received for year #{year} semester #{semester}")
       return nil
     end

     @scrape_logger.debug("method #{__method__} - calling extract_semester_lessons_data for year #{year} semester #{semester}")
     # to do - remove
     #output = File.open("lessons.html", "w+") {|f| f.write(agent.html) }

     lessons_schedule_for_semester =  extract_semester_lessons_data(Nokogiri::HTML.parse(agent.html))
     return lessons_schedule_for_semester
   end

   def serialize_user_courses(years_semesters_hash, serialization_file = "serialized_user_courses")
     File.open(serialization_file, 'w+') do |f|
        Marshal.dump(years_semesters_hash,f)
      end
   end

   def deserialize_user_courses(serialization_file = "serialized_user_courses")
     years_semesters_hash = []
     File.open(serialization_file, 'r') do |f|
         years_semesters_hash = Marshal.load(f)
     end
     return years_semesters_hash
   end

   # Class entry point...
   # to do - comments and try catch blocks
   # to do !!!!!!!!! - fix the overriding bug!!! all courses are written on 2011 sem 0 ! WHY???????????
   def get_user_courses(user_name="frank.kesem", password= "naftasucks")
     login_and_get_initial_page(user_name, password)
     get_semester_selection_page()
     form = agent.form(:name=>"form")
     years_semesters_hash = []
     years_semesters_hash = get_years_semesters_hash(form)
     years_semesters_hash.each do |year|
       year[:semesters].each do |semester|
         semester[:courses] = get_semester_data(form, year[:value], semester[:value])
         agent.back
       end
     end

     serialize_user_courses(years_semesters_hash)

     return years_semesters_hash
   end


end


# Debugging helper function.
# Paste them into the terminal (irb) and run.
# Change function return values and check them for debuggings.
# Remove when finished
def console_funcs
  require "idc_watir_user_scrape"    
  scr = IdcUserScraper.new
  years_semesters_hash = scr.get_user_courses()
  agent = scr.agent
  page = Nokogiri::HTML.parse(agent.html)
  years_semesters_hash = scr.get_years_semesters_hash()
  puts years_semesters_hash

  # dump page to file
  output = File.open("login.html", "w+") {|f| f.write(user_home_page.parser.to_html) }
  
end



scr = IdcUserScraper.new
scr.get_user_courses()
