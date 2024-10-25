FROM ruby:3.3.5

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 4567

CMD ["ruby", "web.rb", "-o", "0.0.0.0"]
