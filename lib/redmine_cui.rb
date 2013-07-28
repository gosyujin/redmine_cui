# -*- coding: utf-8 -*-
require "redmine_cui/version"

require "pit"
require "nokogiri"

require "net/http"
require "uri"

module RedmineCui
  extend self

  API_KEY = Pit.get("kh_redmine")["api_key"]
  ISSUES  = "http://172.24.175.229/redmine/issues.xml"
  ISSUE  = "http://172.24.175.229/redmine/issues"

  # option
  LIMIT = 2
  TRACKER_ID = ""
  STATUS_ID = "*" # open, closed, * (all)

  def issues
    header = { 'X-Redmine-API-Key' => API_KEY }
    issues = request(:GET, "#{ISSUES}?limit=#{LIMIT}&status_id=#{STATUS_ID}", header)
    # case return ASCII-8BIT when redmine use mysql ?
    if issues.encoding == Encoding::ASCII_8BIT then
      #puts "ascii_8bit force_enc"
      issues = issues.force_encoding(Encoding::UTF_8)
    end
    puts "====================================================="
    Nokogiri::XML(issues).xpath('/issues/issue').each do |issue|
      children = issue.children
      id = get_issue_content(:CONTENT, children, "id")

      journals = request(:GET, "#{ISSUE}/#{id}.xml?include=journals", header)
      if journals.encoding == Encoding::ASCII_8BIT then
        #puts "ascii_8bit force_enc"
        jounals = journals.force_encoding(Encoding::UTF_8)
      end
      Nokogiri::XML(journals).xpath('/issue').each do |i|
        children = i.children
        sub        = get_issue_content(:CONTENT, children, "subject")
        desc       = get_issue_content(:CONTENT, children, "description")
        start      = get_issue_content(:CONTENT, children, "start_date")
        due        = get_issue_content(:CONTENT, children, "due_date")
        done_ratio = get_issue_content(:CONTENT, children, "done_ratio")
        estimate   = get_issue_content(:CONTENT, children, "estimated_hours")
        create     = get_issue_content(:CONTENT, children, "created_on")
        update     = get_issue_content(:CONTENT, children, "updated_on")
        project    = get_issue_content(:NAME   , children, "project")
        status     = get_issue_content(:NAME   , children, "status")
        priority   = get_issue_content(:NAME   , children, "priority")
        author     = get_issue_content(:NAME   , children, "author")
        category   = get_issue_content(:NAME   , children, "category")
        journals   = children.at("journals")
        # FIXME custom field

        puts "No.#{id} | AUTHOR: #{author}"
        puts "PRI: #{priority} | START: #{start} | DUE: #{due}"
        puts "-----------------------------------------------------"
        puts "#{sub}"
        puts "-----------------------------------------------------"
        puts "#{desc}"

        children.at("journals").xpath('journal').each do |j|
          children = j.children
          user    = get_issue_content(:NAME   , children, "user")
          notes   = get_issue_content(:CONTENT, children, "notes")
          create  = get_issue_content(:CONTENT, children, "created_on")
          details = get_issue_content(:CONTENT, children, "details")

          puts "-----------------------------------------------------"
          puts ">>>>NAME: #{user}"
          puts ">>>>"
      puts "#{notes}"
        end
        puts "====================================================="
      end
    end
  end

private

  def get_issue_content(path, children, child)
    case path
    when :CONTENT
      content = children.at(child).content
      content == "" ? "unset" : content
    when :NAME
      name = children.at(child)["name"]
      name == "" ? "unset" : name
    end
  end

  def request(method, end_point, header=nil, body=nil)
    uri = URI.parse(end_point)

    http = Net::HTTP.Proxy(ENV['proxy'], ENV['proxy_port']).new(uri.host, uri.port)
    http.start do |http|
      case method
      when :GET
        req = Net::HTTP::Get.new(uri.request_uri, header)
        http.request(req) do |res|
          return res.body
        end
      when :POST
        req = Net::HTTP::Post.new(uri.request_uri, header)
        req.body = JSON.generate(body)
        http.request(req) do |res|
          return res.body
        end
      when :POST2
        http.request_post(uri.request_uri, body) do |res|
          return res.body
        end
      else
        puts "else"
      end
    end
  end
end

RedmineCui::issues
