require 'sinatra/base'
require 'csv'
#require 'pry'
require 'lmdb'

class Tulle < Sinatra::Base

  @@SHORTENER_SCHEME = 'http://'
  @@SHORTENER_HOST = 'library.temple.edu'  #'127.0.0.1:9393/'  '45.33.71.165'
  @@SHORTENER_PATH = 'r'
  @@SHORTENER_ERR_ROUTE = 'err'
  @@SHORTENER_STATS_ROUTE = 'stats'

  #http://diamond.temple.edu/record=b6296088~S30
  @@DIAMOND_SCHEME = 'http://'
  @@DIAMOND_HOST = 'diamond.temple.edu'
  @@DIAMOND_PATH = 'record='
  @@DIAMOND_AFFIX = '~S30'

  #https://temple-primo.hosted.exlibrisgroup.com/primo-explore/fulldisplay?docid=01TULI_ALMA51383143480003811&context=L&vid=TULI&search_scope=default_scope&tab=default_tab&lang=en_US
  @@PRIMO_HOSTED_SCHEME = 'https://'
  @@PRIMO_HOST = 'temple-primo.hosted.exlibrisgroup.com'

  @@PRIMO_ITEM_PATH = '/primo-explore/fulldisplay'
  @@PRIMO_ITEM_QUERY = 'docid=01TULI_ALMA'
  @@PRIMO_ITEM_AFFIX = '&context=L&vid=TULI&search_scope=default_scope&tab=default_tab&lang=en_US'

  @@PRIMO_ACCOUNT_PATH = '/primo-explore/account'
  @@PRIME_ACCOUNT_QUERY = 'vid=TULI&lang=en_US&section=overview'

  @@SEARCH_FAQ_PATH = '/library-search-faq'

  #http://libqa.library.temple.edu/catalog/991011767249703811
  # @@TARGET_SCHEME = 'http://'
  # @@TARGET_HOST = 'libqa.library.temple.edu/'
  # @@TARGET_PATH = 'catalog/'
  # @@TARGET_QUERY = ''

  # search~thoughtz
  # http://exl-impl-primo.hosted.exlibrisgroup.com/primo-explore/search?query=any,contains,otters&vid=01TULI
  # http://diamond.temple.edu/search/?searchtype=X&searcharg=otters
  # http://temple.summon.serialssolutions.com/#!/search?bookMark=ePnHCXMw42LgTQStzc4rAe_hSmEGH2NjAWw3WIAa4lxG4BNAQKeosDGIaoQnBqcGB2tCC04jQzNzY1MO2BAJlM_JwOYPPmqSm0HezTXE2UMXdGpTTmo8dIAjPgl0wIwpsPNsTFgFADzeKa0


  #one gigarecord ought to be enough for anybody
  @@env = LMDB.new('./', mapsize: 1_000_000_000)

  @@db_primo = @@env.database
  #@@db_customurls = @@env.database
  @@db_alma = @@env.database
  #@@db_blacklight = @@env.database
  @@db_diamond = @@env.database

  #36^6 = 2176782336
  @@cust_hash_length = 6
  @@hash_base = 36

  set :logging, true
  logfilename = "#{settings.root}/log/#{settings.environment}.log"
  $logger = ::Logger.new(logfilename)
  # @@logger.sync = true

  before {
    $logger.level = Logger::DEBUG
    env["rack.logger"] = $logger
    env["rack.errors"] =  $logger
  }

  configure do  #  or def initialize () #super()
    enable :logging
    print "Logging to " + logfilename + "\n"

    Sinatra::Base.use Rack::CommonLogger, $logger

    #set :public_folder, '/public'
    #set :static, true

    @@db_alma = @@env.database('alma_db', create: true)
    #@@db_blacklight = @@env.database('blacklight_db', create: true)
    #@@db_customurls = @@env.database('custom_urls', create: true)
    @@db_primo = @@env.database('publishing_db', create: true)
    @@db_diamond = @@env.database('diamond_db', create: true)

    @application_url = URI::HTTP.build(:host => @@SHORTENER_HOST)

    #puts  @db_mms2iep.stat[:entries]

    if File.exist? "PID and MMS ID.csv"
      puts @@db_primo.stat[:entries]
      csvsize =  IO.readlines('PID and MMS ID.csv').size
      puts csvsize
      if( @@db_primo.stat[:entries] < 2000000 )
        puts "Beginning primo IDs ingest " + Time.now.to_s
        CSV.foreach("PID and MMS ID.csv", :headers => false, :encoding => 'utf-8') do |row|   # :converters => :integer
          mms, iep = row
          @@db_primo[mms.to_s] = iep.to_s
        end
        puts "Done primo IDs ingest " + Time.now.to_s
      end
    end

    if File.exist? "01tuli_inst_BIB_IDs.csv"
      puts @@db_alma.stat[:entries]
      csvsize = IO.readlines('01tuli_inst_BIB_IDs.csv').size
      puts csvsize
      if( @@db_alma.stat[:entries] < 2000000 )
        puts "Beginning alma IDs ingest " + Time.now.to_s
        CSV.foreach("01tuli_inst_BIB_IDs.csv", :headers => false, :encoding => 'utf-8') do |row|   # :converters => :integer
          mms, diamond = row
          @@db_alma[diamond.to_s[0..7]] = mms.to_s
        end
        puts "Done alma IDs ingest " + Time.now.to_s
      end
    end

  end

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html

    def url_hash( url_id = '' )
      #TODO ensure no collisions?
      haststr = ''
      if !url_id.nil? and !url_id.empty?
        haststr = url_id.to_i(@@hash_base).to_s
      else
        rand_space = @@hash_base**@@cust_hash_length
        hashint = rand(rand_space)
        haststr = hashint.to_s(@@hash_base)
      end
      return haststr
    end

    def get_perm_path( id )
      #link =  URI::HTTP.build(:host => @@DIAMOND_HOST, :path => '/' + @@DIAMOND_PATH + diamond_id + @@DIAMOND_AFFIX)
      almaid = @@db_alma[id]
      primoid = @@db_primo[almaid]
      primo_query =  + @@PRIMO_ITEM_QUERY + primoid + @@PRIMO_ITEM_AFFIX
      perm_url = URI::HTTPS.build(:scheme => @@PRIMO_HOSTED_SCHEME, :host => @@PRIMO_HOST, :path => @@PRIMO_ITEM_PATH, :query => primo_query )
      return perm_url
    end

    def find_value( needle, haystack )
      found = ''
      db = haystack
      db.cursor do |c|
        key, value = c.next
        if( value == needle )
          found = key
          break
        end
      end
      return found
    end

    def dump_db( db )
      db_array = {}
      db.cursor do |c|
        c.first
        loop do
          key, value = c.get
          #puts key + " " + value
          db_array[key] = value
          break if !c.next
        end
      end
      return db_array
    end

  end

  # get %r{.*/diamond_sunset.png} do
  #   redirect('/public/diamond_sunset.png')
  # end

  get '/' + @@SHORTENER_STATS_ROUTE do
    @stats = dump_db( @@db_diamond )
    erb :stats
  end


  get '/' + @@SHORTENER_ERR_ROUTE do
    erb :error
  end


  # route for short url
  get '/' + @@SHORTENER_PATH + '/' + '*' do
    link = ''
    begin
      logger.info  "new shorturl request:"
      logger.info  params
    	linkid = params[:captures][0]
      logger.info "linkid: " + linkid
      logger.info "referrer: " + request.referrer.to_s

      # if linkid.length == @@cust_hash_length
      #   link = @@db_customurls[linkid]
      # els
      if linkid.length > @@cust_hash_length
        link = get_perm_path( @@db_diamond[linkid] )
      else
        logger.info  "error linkid.length: " + linkid.length
      end
      logger.info  "retrieved link: " + link.to_s
    rescue Exception => e
      logger.info  "shorturl lookup/redirect error"
      logger.info  e.message
      logger.info  e.backtrace.inspect
      link = URI::HTTP.build(:host => @@SHORTENER_HOST, :path => '/' + @@SHORTENER_ERR_ROUTE)
    end
  	redirect link, 301
    #301 moved permanently
  end


  get '/' do
    erb :index
  end


  get '/patroninfo' do
    begin
      logger.info "new shorturl patroninfo redirect:"
      logger.info params
      logger.info "referrer: " + request.referrer.to_s
      link = URI::HTTPS.build(:host => @@PRIMO_HOST, :path => @@PRIMO_ACCOUNT_PATH, :query => @@PRIME_ACCOUNT_QUERY)
      redirect link, 301
    rescue Exception => e
        logger.info  "shorturl patroninfo error"
        logger.info  e.message
        logger.info  e.backtrace.inspect
        erb :index
      end
    #301 moved permanently
  end

  get '/' + @@DIAMOND_PATH + '*' do
    begin
      logger.info "new shorturl redirect:"
      logger.info params
      logger.info "referrer: " + request.referrer.to_s
      if params[:captures].is_a? String
        linkid = params[:captures]
      else
        linkid = params[:captures][0]
      end
      linkid = linkid[0..7]
      logger.info linkid
      link = get_perm_path( linkid )
      logger.info link
      redirect link, 301
    rescue Exception => e
      logger.info  "shorturl redirect error"
      logger.info  e.message
      logger.info  e.backtrace.inspect
      link = URI::HTTPS.build(:host => @@SHORTENER_HOST, :path => @@SEARCH_FAQ_PATH)
      redirect link, 302
    end
  end

  # else this is a straight redirect
  get '/*' do
    logger.info "new faq redirect:"
    logger.info params
    logger.info "referrer: " + request.referrer.to_s
    link = URI::HTTPS.build(:host => @@SHORTENER_HOST, :path => @@SEARCH_FAQ_PATH)
    redirect link, 302
    #302 found
  end


  post '/' do
    logger.info  "new shorturl post:"
    if !params[:url].nil? and !params[:url].empty?
      logger.info  params

      #TODO Enfore valid URI
      shortcode = ''
      item_id = ''
      @input_url = params[:url]
      uri = URI(@input_url)

      logger.info uri

      if !uri.scheme #forgot the http:// ? let's help 'em out
        @input_url = @@DIAMOND_SCHEME + @input_url
        uri = URI(@input_url)
      end

      begin
        if uri.host == @@DIAMOND_HOST  #{}"diamond.temple.edu"
          path_tokens = uri.path.split(/[=,~]/)
          logger.info "path tokens: " + path_tokens.to_s
          if path_tokens.length > 2
            item_id = path_tokens[1]
            if !item_id.nil? and !item_id.empty?
              logger.info "item id: " + item_id.to_s
              shortcode = url_hash( item_id )
              @@db_diamond[shortcode] = item_id
            end
          end
        end
        if shortcode.empty?
          #arbitrary links allowed?
          # shortcode = url_hash
          # item_id = @input_url
          # @@db_customurls[shortcode] = item_id
          logger.info "shorturl post got invalid link"
          link = URI::HTTP.build(:host => @@SHORTENER_HOST, :path => '/' + @@SHORTENER_ERR_ROUTE)
          redirect link
        else
          @shortened_url = URI::HTTP.build(:host => @@SHORTENER_HOST, :path => '/' + @@SHORTENER_PATH + '/' + shortcode)
        end
      rescue Exception => e
        logger.info  "shorturl post/generation error"
        logger.info  e.message
        logger.info  e.backtrace.inspect
        link = URI::HTTP.build(:host => @@SHORTENER_HOST, :path => '/' + @@SHORTENER_ERR_ROUTE)
      end
    end
    erb :index
  end


  # start the server if ruby file executed directly
  run! if app_file == $0
end
