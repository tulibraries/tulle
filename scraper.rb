# frozen_string_literal: true

require "rubygems"
require "json"
require "net/http"
require "uri"
require "csv"

csv = CSV.open("./out.csv", "wb")
url_str = "http://localhost:8984/solr/blacklight-core/select?defType=edismax&indent=on&q=*:*&fl=id,control_number_display&wt=json&sort=id%20asc&facet=false&rows=10000"

cursorMark = ""
nextCursorMark = "*"

while cursorMark != nextCursorMark
  cursorMark = nextCursorMark
  cursor_params = ["cursorMark", cursorMark]
  cursor_uri = URI.parse(url_str)
  params = URI.decode_www_form(cursor_uri.query || "")
  cursor_uri.query = URI.encode_www_form(params << cursor_params)

  puts cursor_uri.to_s

  http = Net::HTTP.new(cursor_uri.host, cursor_uri.port)
  request = Net::HTTP::Get.new(cursor_uri.request_uri)

  response = http.request(request)

  if response.code == "200"
    result = JSON.parse(response.body)

    nextCursorMark = result["nextCursorMark"]
    puts nextCursorMark

    result["response"]["docs"].each do |doc|
      doc["control_number_display"].each do |cnd|
        csv << [doc["id"], cnd]
      end
    end

  else
    puts "Error" + response.code
  end
end
