require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'logger'


class Scraper
  attr_accessor :agent, :scrape_logger
  def initialize(attributes = {})
    @scrape_logger = Logger.new("scraper.log")
    @scrape_logger.level = Logger::DEBUG
    @scrape_logger.info("run start.")
    @agent = Mechanize.new { |a| a.log = Logger.new("mech.log") }
    @agent.user_agent_alias = 'Windows IE 7'
    puts "Scraper was initialized."
  end
  
end

class IdcScraper < Scraper
  attr_accessor :main_page, :main_form, :query_counter
  
  def initialize(attributes = {})
    super
    @query_counter = 0
    @main_page = retrieve_url("http://www.idc.ac.il/yedion/BySchool.aspx?lng=heb&yY=2012")
    @main_form = @main_page.form_with(:name => "Form1")
    puts "IdcScraper was initialized."
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
 
  def get_school_list
    school_options = []
    school_field = @main_form.field_with(:name => "ddlSchool")
    school_field.options.each do |option|
      school_options << {:name =>option.text, :value => option.value}
    end
    #Remove --other--
    school_options.delete_if {|x| x[:value] == "-1"}
    return school_options
  end
  
  
  
  
  # The next 7 funcs are to retrirve select course under by school option. They are not implemented
  
  
  def query_and_parse_ajax(queried_param,school,year="-1",semester="-1",program="-1")
    base_url = "http://www.idc.ac.il/yedion/GetAJAXData.aspx?"
    params = "prm=#{queried_param}&schl=#{school}&acYear=#{year}&smstr=#{semester}&grp=#{program}&yY=2012&lng=heb"
    url = base_url + params
    ajax_resp = retrieve_url(url).body
    @scrape_logger.debug("ajax - request: #{url} and resp: #{ajax_resp}")
    matches = /^.+Array\((.*)\),new Array\((.*)\),.+;$/.match(ajax_resp)
    values = (matches[1].delete "\"").split(",")
    names = (matches[2].delete "\"").split(",")
    hashes_arr = []
    values.zip(names) {|v,n| hashes_arr << {:name => n, :value => v} }
    @scrape_logger.debug("Ajax built data is: " + hashes_arr)
    return hashes_arr
  end
  
  
  # Example http://www.idc.ac.il/yedion/GetAJAXData.aspx?prm=year&schl=80&acYear=-1&smstr=-1&grp=-1&yY=2012&lng=heb
  def get_years_list(school)
    return query_and_parse_ajax("year",school)
  end
  
  # Example http://www.idc.ac.il/yedion/GetAJAXData.aspx?prm=semester&schl=80&acYear=2&smstr=-1&grp=-1&yY=2012&lng=heb
  def get_semesters_list(school, year)
    return query_and_parse_ajax("semester", school, year)
  end
  
  # Example http://www.idc.ac.il/yedion/GetAJAXData.aspx?prm=group&schl=80&acYear=2&smstr=1&grp=-1&yY=2012&lng=heb
  def get_department_list(school, year, semester)
    return query_and_parse_ajax("group", school, year, semester)
  end
  
  # This function isn't ipmlemented because we don't host this date in ou DB
  # Example http://www.idc.ac.il/yedion/GetAJAXData.aspx?prm=program&schl=80&acYear=2&smstr=1&grp=1801112&yY=2012&lng=heb
  def get_internship_list(school, year, semester, department)
    @scrape_logger.warn("Unimplemented function get_internship_list was called!")
  end
 
  # This function isn't ipmlemented because we don't host this date in ou DB 
  # Example http://www.idc.ac.il/yedion/GetAJAXData.aspx?prm=degree&schl=80&acYear=2&smstr=1&grp=1801112&yY=2012&lng=heb
  def get_degree_list(school, year, semester, department, internship)
    @scrape_logger.warn("Unimplemented function get_degree_list was called!")
  end
 
 # returns all of the school options. not used at the moment... 
 def get_all_form_school_hirerchy
   school_options = get_school_list()
    school_options.each do |school|
      school[:years] = get_years_list(school[:value])
      if school[:years].empty?
        @scrape_logger.debug("School #{school[:name]} :years is empty") #to do remove!
      end
      school[:years].each do |year|
        year[:semesters] = get_semesters_list(school[:value],year[:value])
        if year[:semesters].empty?
          @scrape_logger.debug("School " + school[:name] + "-" + year[:name] + " is empty!") #to do remove!
        end
        year[:semesters].each do |semester|
          semester[:departments] = get_department_list(school[:value],year[:value], semester[:value])
          if semester[:departments].empty?
            @scrape_logger.debug("School " + school[:name] + "-" + year[:name] + "-" + semester[:name] + " is empty!") #to do remove!
          end
        end        
      end
    end
    @scrape_logger.debug(school_options)
    @scrape_logger.debug(school_options.to_s)    
    return school_options
 end
 
 # Returns the courses of a school
 def get_school_courses(school_val)
   school_field = @main_form.field_with(:name => "ddlSchool")
   school_field.value = school_val
   courses_page = @agent.submit(@main_form, @main_form.buttons.first)
   @query_counter += 1
   courses_lines = courses_page.parser.css("table#ResultCoursesList1_dlResults tr")
   courses_arr = []
   courses_lines.each do |noko_course_line|
     course_num = noko_course_line.css(".lightPurple:nth-child(2) span").text
     course_full_name = noko_course_line.css(".lightPurple:nth-child(3) span").text
     course_on_click = noko_course_line.css("td input").attribute("onclick").to_s
     course_url_param = /Ctrl\((\d+),/.match(course_on_click)[1]
     courses_arr << {:number => course_num, :full_name => course_full_name, :url_param => course_url_param}
   end
   @scrape_logger.debug("method #{__method__} returning for school #{school_val} total of #{courses_arr.length} courses summaries.") #to do remove!
   @scrape_logger.debug("method #{__method__} first course instruction data: #{courses_arr[0]}") #to do remove!
   @scrape_logger.debug("method #{__method__} last course instruction data: #{courses_arr[-1]}") #to do remove!
   return courses_arr
 end
 
  #example: http://www.idc.ac.il/yedion/CourseDetails.aspx?yY=2012&lng=heb&grp=122005311&crs=53&smstr=-1&dgr=-1&schl=30&year=-1&crsTp=-1&fclt=-1&prgrm=-1&day=-1&frmH=-1&frmM=-1&tH=-1&tM=-1
  def get_course_page(group_id, course_id, school_id, year, semester, lng="heb")
    base_url = "http://www.idc.ac.il/yedion/CourseDetails.aspx?"
    params = "yY=2012&lng=#{lng}&grp=#{group_id}&crs=#{course_id}&smstr=#{semester}&dgr=-1&schl=#{school_id}&year=#{year}&crsTp=-1&fclt=-1&prgrm=-1&day=-1&frmH=-1&frmM=-1&tH=-1&tM=-1"
    url = base_url + params
    @scrape_logger.debug("q=#{@query_counter}- The generated course page url is - #{url}") #to do remove!
    return retrieve_url(url)
  end
 
  def extract_course_eng_page_data(noko_page)
    page = noko_page.parser
    course_data = {}
    course_data[:eng_name] = page.at_css("#lblCourseName").text.strip
    return course_data
  end
 
 #example: http://www.idc.ac.il/yedion/CourseDetails.aspx?yY=2012&lng=heb&grp=121005201&crs=52&smstr=1&dgr=-1&schl=30&year=1&crsTp=-1&fclt=-1&prgrm=-1&day=-1&frmH=-1&frmM=-1&tH=-1&tM=-1
 def extract_course_heb_page_data(noko_page)
   page = noko_page.parser
   course_data = {}
   course_data[:name] = page.at_css("#lblCourseName").text.strip
   course_data[:id_inside] = page.at_css("#lbltCourseCode").text.strip
   course_data[:degree] = page.at_css("#lbltDegree").text.strip
   course_data[:type] = page.at_css("#lbltCourseType").text.strip
   course_data[:points] = page.at_css("#lbltCreditPoints").text.strip
   course_data[:language] = page.at_css("#lbltLang").text.strip
   course_data[:instructor] = page.at_css("#lbltFaculty").text.strip
   
   course_data[:meetings] = []
   meeting_lines = page.css("#tblMeetings tr")
   if (meeting_lines.length.to_i > 1)
     (0..(meeting_lines.length.to_i/2-1)).each do |n|  
       pos = 1 + n.to_i*2
       meeting_cells = meeting_lines[pos].css("td")
       course_data[:meetings] << {:semester => meeting_cells[0].text.strip, :day => meeting_cells[1].text.strip, :room => meeting_cells[2].text.strip, :hours => meeting_cells[3].text.strip}
     end
   end
   
   course_data[:tests] = []
   tests_lines = page.css("#tblExams tr")
   if (tests_lines.length.to_i > 1)
     (0..(tests_lines.length.to_i-2)).each do |n|  
       pos = 1 + n.to_i
       tests_cells = tests_lines[pos].css("td")
       course_data[:tests] << {:date => tests_cells[0].text.strip, :type => tests_cells[1].text.strip, :term => tests_cells[2].text.strip}
     end
   end
    
   course_data[:recitations] = []
   recitations_lines = page.css("#tblRecitation tr")
   if (recitations_lines.length.to_i > 1)
     (0..(recitations_lines.length.to_i/2-1)).each do |n|  
       pos = 1 + n.to_i*2
       recitations_cells = recitations_lines[pos].css("td")
       course_data[:recitations] << {:semester => recitations_cells[0].text.strip, :day => recitations_cells[1].text.strip, :room => recitations_cells[2].text.strip, :hours => recitations_cells[3].text.strip}
     end
   end
   
   # Ignoring course prerequisites - not retrieving it...
   
   
   course_data[:description] = page.at_css("#txtCourseDesc").text.strip
   course_data[:site] = page.at_css("#hlCourseSite").text.strip

   return course_data
 end
 
 
  def retrieve_course_data (group_id, course_id, school_id, year="-1", semester="-1")
    course_data = extract_course_heb_page_data(get_course_page(group_id, course_id, school_id, year, semester))
    eng_course_data = extract_course_eng_page_data(get_course_page(group_id, course_id, school_id, year, semester, "eng"))
    return course_data.merge!(eng_course_data)
  end
 
 
  # This func will return the extracted school data parsed
  # To do - implement!
   def parse_schools_data(schools)
     parsed_schools = schools
     return parsed_schools
   end
   
   # To do - implement!
   def insert_schools_data_to_db(schools) 
   end
   
   def serialize_schools(schools, serialization_file = "serialized_schools")
     File.open(serialization_file, 'w+') do |f|
        Marshal.dump(schools,f)
      end
   end
   
   def deserialize_schools(serialization_file = "serialized_schools")
     schools = []
     File.open(serialization_file, 'r') do |f|
         schools = Marshal.load(f)
     end
     return schools
   end
   
   # Class entry point.
   # Because the scrape sometimes collapses, because of UNIVERSITY problems, we must allow starting from a spacific ordinal school and finishing
   # on some othe ordinal.
   # For example, scrape_idc(2,2) - will query only the 3rd school...
   # send a serialization_file to change to default (serialized_schools) serialization file.
   def scrape_idc(start_from_school_ord=0, end_with_school_ord = -1, serialization_file = nil)
     begin
       schools = get_school_list()
       schools[start_from_school_ord..end_with_school_ord].each do |school|
         school[:courses] = get_school_courses(school[:value])
         @scrape_logger.info("Retrieving data of school #{school[:name]}(#{school[:value]}) for #{school[:courses].length} courses")
         school[:courses].each do |course|
           extracted_data = retrieve_course_data(course[:url_param],course[:number], school[:value])
           course.merge!(extracted_data)       
         end
         @scrape_logger.info("First course data is: #{school[:courses][0]}")
         @scrape_logger.debug("Last course data is: #{school[:courses][-1]}") #to do remove!
       end
       @scrape_logger.info("Finished retrieving all schools data!")
       schools = parse_schools_data(schools)
       insert_schools_data_to_db(schools)
       @scrape_logger.info("Finished running in #{__method__}.")
       return schools
   
     rescue => exception
       exception_data = "\n\n#{exception.class}: #{exception.message}\n    from " + exception.backtrace.join("\n    from ") + "\n\n"
       @scrape_logger.fatal("Unhandled exception was raised! Exception: #{exception_data}")
       raise
       
     ensure
       (nil == serialization_file) ? serialize_schools(schools) : serialize_schools(schools, serialization_file)
       end
   end
  
end

