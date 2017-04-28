require 'sinatra/base'
require 'csv'
require 'pry'
require 'lmdb'

class Tulle < Sinatra::Base

  @@SHORTENER_SCHEME = 'http://'
  @@SHORTENER_HOST = '127.0.0.1:9393/'
  @@SHORTENER_PATH = 'r/'
  @@SHORTENER_ERR_ROUTE = 'err/'

  #http://diamond.temple.edu/record=b6296088~S30
  @@DIAMOND_SCHEME = 'http://'
  @@DIAMOND_HOST = 'diamond.temple.edu/'
  @@DIAMOND_PATH = 'record='
  @@DIAMOND_AFFIX = '~S30'

  #http://exl-impl-primo.hosted.exlibrisgroup.com/primo-explore/fulldisplay?vid=01TULI&docid=01TULI_ALMA51183613160003811
  @@TARGET_SCHEME = 'http://'
  @@TARGET_HOST = 'exl-impl-primo.hosted.exlibrisgroup.com/'
  @@TARGET_PATH = 'primo-explore/fulldisplay'
  @@TARGET_QUERY = '?vid=01TULI&docid='

  #http://libqa.library.temple.edu/catalog/991011767249703811
  # @@TARGET_SCHEME = 'http://'
  # @@TARGET_HOST = 'libqa.library.temple.edu/'
  # @@TARGET_PATH = 'catalog/'
  # @@TARGET_QUERY = ''

  # search thoughtz
  # http://exl-impl-primo.hosted.exlibrisgroup.com/primo-explore/search?query=any,contains,otters&vid=01TULI
  # http://diamond.temple.edu/search/?searchtype=X&searcharg=otters
  # http://temple.summon.serialssolutions.com/#!/search?bookMark=ePnHCXMw42LgTQStzc4rAe_hSmEGH2NjAWw3WIAa4lxG4BNAQKeosDGIaoQnBqcGB2tCC04jQzNzY1MO2BAJlM_JwOYPPmqSm0HezTXE2UMXdGpTTmo8dIAjPgl0wIwpsPNsTFgFADzeKa0


  @@env = LMDB.new('./', mapsize: 1_000_000_000)

  @@db_mms2iep = @@env.database
  @@db_customurls = @@env.database
  @@db_alma = @@env.database
  @@db_blacklight = @@env.database
  @@db_diamond = @@env.database

  #36^6 = 2176782336
  @@cust_hash_length = 6
  @@hash_base = 36

  configure do  #  or def initialize ()
    #super()
    @@db_alma = @@env.database('alma_db', create: true)
    @@db_blacklight = @@env.database('blacklight_db', create: true)
    @@db_customurls = @@env.database('custom_urls', create: true)
    @@db_mms2iep = @@env.database('publishing', create: true)
    @@db_diamond = @@env.database('diamond_db', create: true)

    @application_url = @@SHORTENER_SCHEME + @@SHORTENER_HOST

    #puts  @db_mms2iep.stat[:entries]

    if File.exist? "publishing.csv"
      if( @@db_mms2iep.stat[:entries] <= 1 )
        puts Time.now.to_i
        CSV.foreach("publishing.csv", :headers => true) do |row|   # :converters => :integer
          mms, iep = row
          @@db_mms2iep[mms.to_s] = iep.to_s
        end
        puts Time.now.to_i
      end
    end
  end

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html

    def url_hash( *url_id )
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

    def get_perm_path( old_path )
      perm_path = old_path
      #TODO work out various URL formats for parsing each service/site
      return perm_path
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

  end


  get '/' + @@SHORTENER_ERR_ROUTE do
    erb :error
  end

  # route for short url
  get '/' + @@SHORTENER_PATH + '*' do
    link = ''
    begin
    	linkid = params[:captures][0]

      if linkid.length == @@cust_hash_length
        link = @@db_customurls[linkid]
      elsif linkid.length > @@cust_hash_length
        diamond_id = @@db_diamond[linkid]
        link = @@DIAMOND_SCHEME + @@DIAMOND_HOST + @@DIAMOND_PATH + diamond_id + @@DIAMOND_AFFIX
      else
      end
    rescue
      link = @@SHORTENER_SCHEME + @@SHORTENER_HOST + @@SHORTENER_ERR_ROUTE
    end
  	redirect link, 301
  end


  get '/' do
  #  binding.pry
    erb :index
  end

  # else this is a straight redirect
  get '/*' do
    #binding.pry
    path = params[:splat][0]
    perm_path = get_perm_path( path )
    redirect @@SHORTENER_SCHEME + @@SHORTENER_HOST + @@SHORTENER_PATH + perm_path, 302
    #302 found
  end


  post '/' do
    if !params[:url].nil? and !params[:url].empty?
      #TODO Enfore valid URI
      shortcode = ''
      item_id = ''
      @input_url = params[:url]
      uri = URI(@input_url)

      if !uri.scheme #forgot the http:// ? let's help them out
        @input_url = @@DIAMOND_SCHEME + @input_url
        uri = URI(@input_url)
      end

      if uri.host == "diamond.temple.edu"
        path_tokens = uri.path.split(/[=,~]/)
        item_id = path_tokens[1]
        #binding.pry
        shortcode = url_hash( item_id )
        @@db_diamond[shortcode] = item_id
      else #arbitrary links allowed?
        # shortcode = url_hash
        # item_id = @input_url
        # @@db_customurls[shortcode] = item_id
        link = @@SHORTENER_SCHEME + @@SHORTENER_HOST + @@SHORTENER_ERR_ROUTE
        redirect link
      end

      @shortened_url = @@SHORTENER_SCHEME + @@SHORTENER_HOST + @@SHORTENER_PATH + shortcode

    end
    erb :index
  end


  # start the server if ruby file executed directly
  run! if app_file == $0
end
