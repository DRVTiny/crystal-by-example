# TODO: Write documentation for `Sele`
require "selenium"
module Sele
  RESOLUTION = "1024x768"
  SITE_URL = "https://avito.ru"
  
  driver = Selenium::Driver.for(
    :chrome,
    base_url: "http://localhost:9515"
  )
  
  capabilities = Selenium::Chrome::Capabilities.new
  capabilities.chrome_options.args=["no-sandbox", "headless", "disable-gpu"]
  session = driver.create_session(capabilities)
  width, height = RESOLUTION.split("x").map {|m| m.to_i64}
  session.window_manager.resize_window(width, height)
  
  session.navigate_to(SITE_URL)
  body = session.find_element(:css, "body")
  
  search_inp = session.find_element(:css, ".input-input-Zpzc1")
  search_inp.send_keys("Gary Fisher\n")
  
  session.find_elements(:css, ".pagination-page").each do |el|
    if el.enabled?
      puts "pagination element not displayed" unless el.displayed?
      puts({SITE_URL, el.attribute("href")}.join("/"))
    else
      puts "pagination element not enabled"
    end
  end
  
  session.screenshot("avito.png")
  system("gpicview avito.png")
  
  driver.stop  
end
