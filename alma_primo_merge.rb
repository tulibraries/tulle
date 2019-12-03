#! /usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "lmdb"

primofile = "link-exchanger-blacklight/IDMappings_3810_3811_ALL/01tuli_inst_ds.csv"
almafile = "link-exchanger-blacklight/IDMappings_3810_3811_ALL/01tuli_inst_BIB_IDs.csv"
outfile = "link-exchanger-blacklight/alma_primo_map.csv"

env = LMDB.new("./link-exchanger-blacklight/", mapsize: 1_000_000_000)
db_primo = env.database("publishing_db", create: true)

if File.exist?(almafile) && File.exist?(primofile)
  File.open(outfile, "a") do |file|
    puts "Beginning primo-diamond IDs ingest " + Time.now.to_s
    CSV.foreach(primofile, headers: false) do |row|   # :converters => :integer
      iep, diamond = row
      db_primo[diamond.to_s[0..7]] = iep.to_s
    end
    puts "Done primo-diamond IDs ingest " + Time.now.to_s

    CSV.foreach(almafile, headers: false) do |row|
      alma, diamond = row
      primo = db_primo[diamond.to_s[0..7]]
      if !primo.to_s.empty?
        file.puts alma.to_s + "," + primo.to_s
      else
        puts "not found: " + alma
      end
    end
  end
end
