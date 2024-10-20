require 'digest'
require 'sinatra'
require 'pg'
require 'json'
require 'net/http'
require 'uri'

def get_morphology(word)
  encoded_word = URI.encode_www_form_component(word)
  url = URI.parse("http://localhost:8080/nlp/#{encoded_word}")
  req = Net::HTTP::Get.new(url)
  res = Net::HTTP.start(url.host, url.port) do |http|
    http.request(req)
  end
  return res.body if res.code == '200'

  nil
end

def pg_array(arr)
  escaped_tags = arr.map do |tag|
    tag.gsub(/\\/, '\\\\\\').gsub(/"/, '\"')
  end

  "{#{escaped_tags.map { |tag| "\"#{tag}\"" }.join(',')}}"
end

def get_pronunciation(word, md5_hash)
  url = URI.parse("https://translate.google.com.vn/translate_tts?ie=UTF-8&q=#{URI.encode_www_form_component(word)}&tl=pl&client=tw-ob")
  req = Net::HTTP::Get.new(url.to_s)
  res = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
    http.request(req)
  end
  return unless res.code == '200'

  File.open("./public/#{md5_hash}.mp3", 'wb') do |file|
    file.write(res.body)
  end
  true
end

# SQL query-builder:
# a('decks') = "select ok, js from srs.decks()"
# a('review', 9, 'good') = "select ok, js from srs.review($1,$2)", [9, 'good']
# returns boolean ok, and parsed JSON
class DBAPI
  def initialize
    @db = PG::Connection.new(dbname: 'srs', user: 'srs', password: 'srs', host: 'localhost', port: 5432)
  end

  def a(func, *params)
    qs = '(%s)' % (1..params.size).map { |i| "$#{i}" }.join(',')
    sql = "select ok, js from srs.#{func}#{qs}"
    r = @db.exec_params(sql, params)[0]
    puts "Result: #{r.inspect}"
    [
      (r['ok'] == 't'),
      JSON.parse(r['js'], symbolize_names: true)
    ]
  end
end
API = DBAPI.new

get '/' do
  _, @decks = API.a('decks')
  erb :home
end

post '/' do
  deck = params[:deck]
  front = params[:front]
  back = params[:back]
  md5_hash = Digest::MD5.hexdigest(back)
  morph = get_morphology(back)
  tags = []
  status = get_pronunciation(back, md5_hash)
  tags << "<audio src=\"#{md5_hash}.mp3\"></audio>" if status
  stringy_tags = pg_array(tags)
  API.a('add', deck, front, back, morph, stringy_tags)

  redirect to('/')
end

get '/next' do
  ok, @card = API.a('next', String(params[:deck]))
  redirect to('/') unless ok
  erb :card
end

post '/card/:id/edit' do
  front = params[:front]
  back = params[:back]
  md5_hash = Digest::MD5.hexdigest(back)
  morph = get_morphology(back)
  tags = []
  status = get_pronunciation(back, md5_hash)
  tags << "<audio src=\"#{back}.mp3\"></audio>" if status

  API.a('edit', params[:id], params[:deck], front, back, morph, pg_array(tags))
  redirect to('/next?deck=%s' % params[:deck])
end

post '/card/:id/review' do
  _, c = API.a('review', params[:id], params[:rating])
  redirect to('/next?deck=%s' % c[:deck])
end
