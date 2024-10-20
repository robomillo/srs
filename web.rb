require 'sinatra'
require 'pg'
require 'json'
require 'net/http'
require 'uri'


def  get_morphology(word)
  encoded_word = URI.encode_www_form_component(word)
  url = URI.parse("http://localhost:8080/nlp/#{encoded_word}")
  req = Net::HTTP::Get.new(url)
  res = Net::HTTP.start(url.host, url.port) do |http|
    http.request(req)
  end
  if res.code == '200'
    return res.body
  else
    nil
  end
end


def get_pronunciation(word)
  encoded_word = URI.encode_www_form_component(word)

  url = URI.parse("https://translate.google.com.vn/translate_tts?ie=UTF-8&q=#{encoded_word}&tl=pl&client=tw-ob")
  req = Net::HTTP::Get.new(url.to_s)
  res = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
    http.request(req)
  end

  if res.code == '200'
    # Save the audio to a file
    file_path = "./public/#{word}.mp3"
    File.open(file_path, 'wb') do |file|
      file.write(res.body)
    end
    file_path
  else
    nil
  end
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
    qs = '(%s)' % (1..params.size).map {|i| "$#{i}"}.join(',')
    sql = "select ok, js from srs.#{func}#{qs}"
    r = @db.exec_params(sql, params)[0]
    [
      (r['ok'] == 't'),
      JSON.parse(r['js'], symbolize_names: true)
    ]
  end
end
API = DBAPI.new

get '/' do
  ok, @decks = API.a('decks')
  erb :home
end

post '/' do
  deck = params[:deck]
  front = params[:front]
  back = params[:back]
  morph = get_morphology(back)

  pronunciation_file_path = get_pronunciation(back)
  if pronunciation_file_path
    back += " <audio src=\"#{back}.mp3\"></audio>"
  end


  API.a('add', deck, front, back, morph)

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
  morph = get_morphology(back)

  if !back.include?('<audio')
    pronunciation_file_path = get_pronunciation(back)
    if pronunciation_file_path
      back += " <audio src=\"#{back}.mp3\"></audio>"
    end
  end

  API.a('edit', params[:id], params[:deck], front, back, morph)
  redirect to('/next?deck=%s' % params[:deck])
end

post '/card/:id/review' do
  ok, c = API.a('review', params[:id], params[:rating])
  redirect to('/next?deck=%s' % c[:deck])
end

