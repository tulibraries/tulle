# frozen_string_literal: true

require "sinatra/base"
require "logger"
require "csv"
require "lmdb"

class Tulle < Sinatra::Base
  @@SHORTENER_SCHEME = "http://"
  @@SHORTENER_HOST = "library.temple.edu"
  @@SHORTENER_WEB_DIR = "link_exchange"
  @@SHORTENER_PATH = "r"
  @@SHORTENER_ERR_ROUTE = "err"
  @@SHORTENER_STATS_ROUTE = "stats"

  #http://diamond.temple.edu/record=b6296088~S30
  @@DIAMOND_SCHEME = "http://"
  @@DIAMOND_HOST = "diamond.temple.edu"
  @@DIAMOND_PATH = "record="
  @@DIAMOND_SUFFIX = "~S30"

  #https://temple-primo.hosted.exlibrisgroup.com/primo-explore/fulldisplay?docid=01TULI_ALMA51383143480003811&context=L&vid=TULI&search_scope=default_scope&tab=default_tab&lang=en_US
  @@PRIMO_HOSTED_SCHEME = "https://"
  @@PRIMO_HOST = "temple-primo.hosted.exlibrisgroup.com"
  @@PRIMO_FILTER_PREFIX = "01TULI_ALMA"
  @@PRIMO_ITEM_PATH = "/primo-explore/fulldisplay"
  @@PRIMO_ITEM_QUERY = "docid=01TULI_ALMA"
  @@PRIMO_ITEM_SUFFIX = "&context=L&vid=TULI&search_scope=default_scope&tab=default_tab&lang=en_US"

  @@PRIMO_ACCOUNT_PATH = "/primo-explore/account"
  @@PRIMO_ACCOUNT_QUERY = "vid=TULI&lang=en_US&section=overview"

  @@SEARCH_FAQ_PATH = "/library-search-faq"

  #http://libqa.library.temple.edu/catalog/catalog/991011767249703811
  @@BL_QA_HOST = "libqa.library.temple.edu/"
  @@BL_QA_PATH = "/catalog/catalog/"

  #https://librarybeta.temple.edu/catalog/991036802751503811
  @@BL_SCHEME = "https://"
  @@BL_BETA_HOST = "librarybeta.temple.edu"
  @@BL_PROD_HOST = "librarysearch.temple.edu"
  @@BL_PATH = "/catalog/"

  @@BL_HOST = @@BL_PROD_HOST

  @@cust_hash_length = 6
  #864305631152
  @@diamond_hash_length = 12
  #16151540936649808398486373
  #16144537081828078306495333
  @@primo_hash_length = 26
  #2650455608142374095187122021
  #2650455223671232256193288037
  @@alma_hash_length = 28
  @@hash_base = 36

  logfilename = "#{settings.root}/log/#{settings.environment}.log"

  $logger = ::Logger.new(logfilename)
  $logger.level = Logger::DEBUG
  # $logger.sync = true
  print "Logging to " + logfilename + "\n"
  Sinatra::Base.use Rack::CommonLogger, $logger

  before {
    env["rack.logger"] = $logger
    env["rack.errors"] = $logger
    #one gigarecord ought to be enough for anybody
    @@env = LMDB.new("./", mapsize: 1_000_000_000)
    @@db_diamond_primo = @@env.database("diamond_primo_db", create: true)
    @@db_alma = @@env.database("alma_db", create: true)
    # @@db_primo = @@env.database('publishing_db', create: true)
    @@db_shorturls = @@env.database("diamond_db", create: true)
  }

  after {
    @@env.close
  }

  configure do  #  or def initialize () #super()

    set :logging, true
    @application_url = URI::HTTP.build(host: @@SHORTENER_HOST)

    @@env = LMDB.new("./", mapsize: 1_000_000_000)
    @@db_diamond_primo = @@env.database("diamond_primo_db", create: true)
    @@db_shorturls = @@env.database("diamond_db", create: true)
    @@db_alma = @@env.database("alma_db", create: true)

    diamondprimofile = "01tuli_inst_ds.csv"
    if File.exist? diamondprimofile
      puts "Diamond-Primo db size: " + @@db_diamond_primo.stat[:entries].to_s
      csvsize = IO.readlines(diamondprimofile).size
      puts "Diamond-Primo file size: " + csvsize.to_s
      # if( @@db_diamond_primo.stat[:entries] <= 2000000 )
      puts "Beginning primo-diamond IDs ingest " + Time.now.to_s
      CSV.foreach(diamondprimofile, headers: false, encoding: "utf-8") do |row|   # :converters => :integer
        iep, diamond = row
        @@db_diamond_primo[diamond.to_s[0..7]] = iep.to_s
      end
      File.delete(diamondprimofile)
      puts "Done primo-diamond IDs ingest " + Time.now.to_s
      # end
    end

    # Primo to Diamond reverse lookup for Blacklight catalog imports begin here
    # pidandmmsidcsvfile = "PID and MMS ID.csv"
    # new mapping file created by cross-referencing 01tuli_inst_ds.csv and 01tuli_inst_BIB_IDs.csv
    pidandmmsidcsvfile = "alma_primo_map.csv"
    if File.exist? pidandmmsidcsvfile
      puts "Alma-Primo db size = " + @@db_alma.stat[:entries].to_s
      csvsize = IO.readlines(pidandmmsidcsvfile).size
      puts "pidandmmsidcsvfile file size = " + csvsize.to_s
      puts "Beginning pidandmmsidcsvfile IDs ingest " + Time.now.to_s
      loadfailed = false
      CSV.foreach(pidandmmsidcsvfile, headers: false, encoding: "utf-8") do |row|   # :converters => :integer
        begin
          mms, iep = row
          @@db_alma[iep.to_s] = mms.to_s
        rescue
          puts "Error in line " + row.to_s + " " + mms.to_s + " " + iep.to_s
          loadfailed = true
          break
        end
      end
      if loadfailed == false
        File.delete(pidandmmsidcsvfile)
      end
      puts "Done pidandmmsidcsvfile IDs ingest " + Time.now.to_s
      # end
    end

    almapublishingidelectronicfull = "alma-publishing-id-electronic-full.csv"
    if File.exist? almapublishingidelectronicfull
      puts "Alma-Primo db size = " + @@db_alma.stat[:entries].to_s
      csvsize = IO.readlines(almapublishingidelectronicfull).size
      puts "almapublishingidelectronicfull file size = " + csvsize.to_s
      puts "Beginning almapublishingidelectronicfull IDs ingest " + Time.now.to_s
      loadfailed = false
      CSV.foreach(almapublishingidelectronicfull, headers: true, encoding: "us-ascii", col_sep: ",") do |row|   # :converters => :integer
        begin
          #mms, iep = row
          mms = row[0]
          iep = row[1]
          @@db_alma[iep.to_s] = mms.to_s
        rescue
          puts "Error in line " + row.to_s + " " + mms.to_s + " " + iep.to_s
          loadfailed = true
          break
        end
      end
      if loadfailed == false
        File.delete(almapublishingidelectronicfull)
      end
      puts "Done almapublishingidelectronicfull IDs ingest " + Time.now.to_s
    end

    almapublishingidphysicalpostmigration = "alma-publishing-id-physical-post-migration.csv"
    if File.exist? almapublishingidphysicalpostmigration
      puts "Alma-Primo db size = " + @@db_alma.stat[:entries].to_s
      csvsize = IO.readlines(almapublishingidphysicalpostmigration).size
      puts "almapublishingidphysicalpostmigration file size = " + csvsize.to_s
      # if( @@db_alma.stat[:entries] < 2000000 )
      puts "Beginning almapublishingidphysicalpostmigration IDs ingest " + Time.now.to_s
      loadfailed = false
      CSV.foreach(almapublishingidphysicalpostmigration, headers: true, encoding: "utf-8", col_sep: ",") do |row|   # :converters => :integer
        begin
          mms = row[0]
          iep = row[1]
          @@db_alma[iep.to_s] = mms.to_s
        rescue
          puts "Error in line " + row.to_s + " " + mms.to_s + " " + iep.to_s
          loadfailed = true
          break
        end
      end
      if loadfailed == false
        File.delete(almapublishingidphysicalpostmigration)
      end
      puts "Done almapublishingidphysicalpostmigration IDs ingest " + Time.now.to_s
      # end
    end

    augmentfile = "Diamond-Primo-manual-updated.csv"
    if File.exist? augmentfile
      puts @@db_diamond_primo.stat[:entries]
      csvsize = IO.readlines(augmentfile).size
      puts csvsize
      begin
        puts "Beginning manual IDs ingest " + Time.now.to_s
        CSV.foreach(augmentfile, headers: false, encoding: "utf-8") do |row|   # :converters => :integer
          diamond, mms = row
          @@db_diamond_primo[diamond.to_s[0..7]] = mms.to_s
        end
        puts "Done manual IDs ingest " + Time.now.to_s
        File.delete(augmentfile)
      rescue Exception => e
        puts e.message
        puts e.backtrace.inspect
      end
    end

    old_mappings_backup = "tulle_mappings_20180810.csv"
    if File.exist? old_mappings_backup
      puts "Mappings db size: " + @@db_shorturls.stat[:entries].to_s
      csvsize = IO.readlines(old_mappings_backup).size
      puts "Mappings file size: " + csvsize.to_s
      puts "Beginning old mappings ingest " + Time.now.to_s
      begin
        CSV.foreach(old_mappings_backup, headers: false, encoding: "utf-8") do |row|   # :converters => :integer
          hash, cat = row
          @@db_shorturls[hash.to_s] = cat.to_s
        end
        puts "Done old mappings ingest " + Time.now.to_s
        File.delete(old_mappings_backup)
      rescue Exception => e
        puts e.message
        puts e.backtrace.inspect
      end
    end
  end

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html

    def url_hash(url_id = "")
      #TODO ensure no collisions?
      hashstr = ""
      if !url_id.to_s.empty?
        hashstr = url_id.to_i(@@hash_base).to_s
      else
        rand_space = @@hash_base**@@cust_hash_length
        hashint = rand(rand_space)
        hashstr = hashint.to_s(@@hash_base)
      end
      return hashstr
    end

    def get_perm_path(id)
      #link =  URI::HTTP.build(:host => @@DIAMOND_HOST, :path => '/' + @@DIAMOND_PATH + diamond_id + @@DIAMOND_SUFFIX
      perm_url = ""
      url_id = ""
      primo_id = ""
      logmsg = ""
      begin
        if !id.to_s.empty?
          if id[0] == "b" # this is a diamond id
            primo_id = @@db_diamond_primo[id.to_s]
            url_id = @@db_alma[primo_id.to_s]
            # if !almaid.to_s.empty?
            #   primoid = @@db_primo[almaid].to_s
            # end
          elsif id.to_s.size == 17 #this is a primo id
            url_id = @@db_alma[id.to_s]
          elsif id.to_s.size == 18 #this is an alma id
            url_id = id.to_s
          end
        end
        if !url_id.to_s.empty?
          # primo_query = @@PRIMO_ITEM_QUERY + url_id + @@PRIMO_ITEM_SUFFIX
          # perm_url = URI::HTTPS.build(:scheme => @@PRIMO_HOSTED_SCHEME, :host => @@PRIMO_HOST, :path => @@PRIMO_ITEM_PATH, :query => primo_query).to_s
          perm_url = URI::HTTPS.build(scheme: @@BL_SCHEME, host: @@BL_HOST, path: @@BL_PATH + url_id.to_s).to_s
        else
          logger.info "get_perm_path ERROR: " + id.to_s + " not found in db. Primo ID=" + primo_id.to_s
          perm_url = get_faq_link()
        end
      rescue Exception => e
        logmsg += " get_perm_path lookup/redirect error "
        logmsg += e.message.to_s
        logmsg += e.backtrace.inspect.to_s
        logger.info logmsg
        perm_url = get_faq_link()
      end
      return perm_url
    end

    def get_err_link()
      link = @application_url.to_s + "/" + @@SHORTENER_WEB_DIR + "/" + @@SHORTENER_ERR_ROUTE
      return link
    end

    def get_faq_link()
      link = URI::HTTPS.build(host: @@SHORTENER_HOST, path: @@SEARCH_FAQ_PATH)
      return link
    end

    def dump_db(db)
      db_array = {}
      db.cursor do |c|
        c.first rescue return db_array
        loop do
          key, value = c.get
          db_array[key] = value
          break if !c.next
        end
      end
      return db_array
    end

  end

  get "/" + @@SHORTENER_STATS_ROUTE do
    @stats = dump_db(@@db_shorturls)
    erb :stats
  end


  get "/" + "*" + "/" + @@SHORTENER_ERR_ROUTE do
    logmsg = "new shorturl error request " + request.referrer.to_s
    logger.info logmsg
    erb :error
  end

  get "/" + @@SHORTENER_ERR_ROUTE do
    logmsg = "new shorturl error request " + request.referrer.to_s
    logger.info logmsg
    erb :error
  end


  # route for short url
  get "/" + @@SHORTENER_PATH + "/" + "*" do
    link = ""
    logmsg = ""
    begin
      logmsg += "new shorturl request: " + params[:splat].to_s
      if !params[:splat].to_s.empty?
        linkid = params[:splat][0]
        logmsg += " linkid: " + linkid.to_s + " referrer: " + request.referrer.to_s
        if linkid.length == @@diamond_hash_length || linkid.length == @@primo_hash_length || linkid.length == @@alma_hash_length
          newid = @@db_shorturls[linkid]
          if !newid.to_s.empty?
            link = get_perm_path(newid)
          else
            link = get_faq_link()
            logmsg += " error linkid not found in shorturls db: " + linkid
          end
        else
          logmsg += " error linkid.length: " + linkid.length.to_s
        end
        logmsg += " retrieved link: " + link.to_s
      else
        logmsg += " error params[:splat] length: " + params[:splat].to_s
      end
    rescue Exception => e
      logmsg += " shorturl lookup/redirect error "
      logmsg += e.message.to_s
      logmsg += e.backtrace.inspect.to_s
      logger.info logmsg
      link = get_faq_link()
    end
    logger.info logmsg
    redirect link, 301
  end


  get "/" do
    erb :index
  end


  get "/patroninfo" do
    logmsg = ""
    begin
      logmsg += "new shorturl patroninfo redirect: " + params.to_s
      logmsg += " referrer: " + request.referrer.to_s
      link = URI::HTTPS.build(host: @@PRIMO_HOST, path: @@PRIMO_ACCOUNT_PATH, query: @@PRIMO_ACCOUNT_QUERY)
      logger.info logmsg
      redirect link, 301
    rescue Exception => e
      logmsg += " shorturl patroninfo error "
      logmsg += e.message
      logmsg += e.backtrace.inspect
      logger.info logmsg
      erb :index
    end
  end

  # The old diamond domain points here. Redirect those links to the new catalog
  get "/" + @@DIAMOND_PATH + "*" do
    logmsg = ""
    begin
      logmsg += "new shorturl redirect: " + params.to_s
      logmsg += " referrer: " + request.referrer.to_s
      if params[:splat].is_a? String
        linkid = params[:splat]
      else
        linkid = params[:splat][0]
      end
      linkid = linkid[0..7]
      logmsg += " link id: " + linkid.to_s
      link = get_perm_path(linkid)
      if link.to_s.empty?
        logmsg += " Error looking up id: " + linkid.to_s
      else
        logmsg += " URL: " + link.to_s
      end
      logger.info logmsg
      redirect link, 301
    rescue Exception => e
      logmsg += " shorturl redirect error "
      logmsg += e.message
      logmsg += e.backtrace.inspect
      logger.info logmsg
      link = get_faq_link()
      redirect link, 302
    end
  end

  # else this is a straight redirect
  get "/*" do
    logmsg = "new faq redirect: "
    logmsg += params.to_s
    logmsg += " referrer: " + request.referrer.to_s
    link = URI::HTTPS.build(host: @@SHORTENER_HOST, path: @@SEARCH_FAQ_PATH)
    logger.info logmsg
    redirect link, 302
    #302 found
  end


  post "/" do
    logmsg = "new shorturl post: "

    begin
      if !params[:url].to_s.empty?
        logmsg += params.to_s
        shortcode = ""
        item_id = ""

        @input_url = params[:url].strip
        uri = URI(@input_url)

        logmsg += " URI: " + uri.to_s

        if !uri.scheme #forgot the http:// ? let's help 'em out
          logmsg += " Adding scheme. "
          @input_url = @@BL_SCHEME + @input_url
          uri = URI(@input_url)
        end

        if uri.host == @@DIAMOND_HOST  #{}"diamond.temple.edu"
          path_tokens = uri.path.split(/[=,~]/)
          logmsg += " Diamond Path tokens: " + path_tokens.to_s
          if path_tokens.length > 2
            item_id = path_tokens[1]
            if !item_id.to_s.empty?
              logmsg += " item id: " + item_id.to_s
              shortcode = url_hash(item_id)
              @@db_shorturls[shortcode] = item_id
            end
          end
          logger.info logmsg
        elsif uri.host == @@PRIMO_HOST
          path_tokens = URI::decode_www_form(uri.query).to_h
          logmsg += " Primo Query tokens: " + path_tokens.to_s
          id = path_tokens["docid"]  #01TULI_ALMA21252407250003811
          if !id.to_s.empty? && (id[0..10] == @@PRIMO_FILTER_PREFIX)
            item_id = id[11..27]
            logmsg += " item id: " + item_id.to_s
            shortcode = url_hash(item_id)
            @@db_shorturls[shortcode] = item_id
          end
          logger.info logmsg
        elsif uri.host == @@BL_PROD_HOST || uri.host == @@BL_BETA_HOST
          path_tokens = uri.path.split("/")
          logmsg += " Blacklight Path tokens: " + path_tokens.to_s
          # check for well-formed BL catalog URL. Disallow articles and bento links
          if path_tokens.length >= 2 && path_tokens.include?("catalog") && !path_tokens.include?("articles") && !path_tokens.include?("bento")
            item_id = path_tokens.last
            logmsg += " item id: " + item_id.to_s
            # check that the token is a numeric id
            if !item_id.to_s.empty? && item_id.to_s !~ /\D/
              shortcode = url_hash(item_id)
              @@db_shorturls[shortcode] = item_id
            end
          end
          logger.info logmsg
        else
          logmsg += " host " + uri.host.to_s + " did not match any known catalog host"
          logger.info logmsg
        end
        # we will end up here if the submitted link was invalid
        # if so, redirect the user to the instructions page
        if shortcode.to_s.empty?
          logmsg += " ERROR: shorturl post got invalid link. "
          link = get_err_link()
          logger.info logmsg
          redirect link
        else
          @shortened_url = URI::HTTP.build(host: @@SHORTENER_HOST, path: "/" + @@SHORTENER_PATH + "/" + shortcode)
        end
      end
    rescue Exception => e
      logmsg += " shorturl post/generation error: "
      logmsg += e.message.to_s
      logmsg += e.backtrace.inspect.to_s
      link = get_err_link()
      logmsg += " link: " + link.to_s
      logger.info logmsg
      redirect link
    end
    logger.info logmsg
    erb :index
  end


  # start the server if ruby file executed directly
  run! if app_file == $0
end
