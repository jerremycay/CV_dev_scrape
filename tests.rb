#require 'sinatra'



#get '/' do
#    str_hash = {:name => "עופר", :last => "בן- נון"}
#    return str_hash.inspect.to_s
#end
##########
#scrape user data
##########











##########
#scrape_idc
##########

# Was inside the class!!
def console_funcs
  require "idc_scrape"    
  scr = IdcScraper.new
  
  schools = scr.scrape_idc(0,-1, "serialized_schools_1")
  course_data = scr.retrieve_course_data("121005201", "52", "30", "1", "1")
  scr.scrape_logger.debug(course_data)
  
  course_data = scr.parse_course_page(course_page)
  school_field = scr.main_form.field_with(:name => "ddlSchool")
end


# Was inside the class!!
def test_stuff
  #school_options.delete(school_options.select {|s| s[:value] == "-1"})
  year_field = main_form.field_with(:name => "ddlYear")

  #for select test
  madmah_option = school_field.option_with(:value => "30")
  page = agent.submit(main_form)

  search_form.field_with(:name => "q").value = "Hello"
  search_results = agent.submit(search_form)
  puts search_results.body

  form = agent.page.forms.first
  form.password = "secret"
  form.submit

  agent.page.link_with(:text => "Wish List").click
  agent.page.search(".edit_item").each do |item|
    Product.create!(:name => item.text.strip)
  end
end


def test_hebrew(school_options)
  puts school_options[0][:name]
  puts "בית הספר לפסיכולוגיה"
  x = "בית הספר לפסיכולוגיה"
  puts school_options[0][:name] == "בית הספר לפסיכולוגיה"
  puts school_options[0][:name] == x
  puts x == "בית הספר לפסיכולוגיה"
end


class Klass
   def initialize(str)
    @str = str
  end
  def sayHello
    @str
  end
end

    

    
def test_serialize()
  arr_hash = [{:first => "ofer", :last=> "Ben- Noon"}, {:first => "Dana", :last=> "El-On"}, {:some => "thing"}]
  pp arr_hash
  File.open('ser_test', 'w+') do |f|
    Marshal.dump(arr_hash,f)
  end
  
  obj = []
  File.open('ser_test', 'r') do |fr|
    obj = Marshal.load(fr)
  end
  pp obj
  puts (obj == arr_hash)
end


def test_ex()
  begin
    puts "begin"
    eval str
  rescue => exception
    exception_data = "\n\n#{exception.class}: #{exception.message}\n    from " + exception.backtrace.join("\n    from ") + "\n\n"
    puts exception_data
    raise
  ensure
    puts "ensure"
  end
end

def test_range
  arr = %w{a b c}
  arr[0..1].each do |let|
    puts let
  end
end


def test_param(a = "1", b="2", c= "3")
  puts a+b+c
end
