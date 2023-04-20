FROM ruby:3.1.1

RUN mkdir -p /app

WORKDIR  /app

COPY Gemfile Gemfile.lock ./

RUN gem install bundler -v 2.3.26

RUN bundle install

COPY . ./