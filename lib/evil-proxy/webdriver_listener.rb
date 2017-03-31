require 'selenium/webdriver/support'


module EvilProxy

  #
  # Example Usage:
  #
  #   proxy = ...
  #   listener = EvilProxy::WebDriverListener.new(proxy)
  #   driver = Selenium::WebDriver.for :firefox, :listener => listener
  #
  #   driver.quit
  #   listener.hars
  #   proxy.close
  #
  # If you wish to extend this class see:
  # http://www.rubydoc.info/gems/selenium-webdriver/Selenium/WebDriver/Support/AbstractEventListener
  # for information on the events that can be tracked.
  #
  class WebDriverListener < Selenium::WebDriver::Support::AbstractEventListener
    attr_reader :proxy

    def initialize(proxy, opts = {})
      @proxy = proxy
      proxy.clean_store
    end

    def before_navigate_to(url, driver)
      puts "Navigating to #{url}"
      proxy.new_page("navigate-to-#{url}")
    end

    def before_navigate_back(driver = nil)
      name = "navigate-back"
      name << "-from-#{driver.current_url}" if driver
      proxy.new_page(name)
    end

    def before_navigate_forward(driver = nil)
      name = "navigate-forward"
      name << "-from-#{driver.current_url}" if driver

      proxy.new_page(name)
    end

    def before_click(element, driver)
      name = "click-element-#{identifier_for element}"
      proxy.new_page(name)
    end

    def before_quit(driver)
    end

    def identifier_for(element)
      # can be ovverriden to provide more meaningful info
      element.ref
    end

  end
end
