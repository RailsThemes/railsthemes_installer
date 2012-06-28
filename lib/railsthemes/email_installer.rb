require 'thor'

module Railsthemes
  class EmailInstaller < Thor
    no_tasks do
      include Railsthemes::Logging
      include Thor::Actions

      def install_from_file_system original_source_filepath
        source_filepath = original_source_filepath.gsub(/\\/, '/')
        if File.directory?(source_filepath)

          logger.warn 'Installing email theme...'
          logger.debug "source_filepath: #{source_filepath}"

          Dir["#{source_filepath}/email/**/*"].each do |src|
            logger.debug "src: #{src}"
            dest = src.sub("#{source_filepath}/email/", '')
            logger.debug "dest: #{dest}"
            if File.directory?(src)
              unless File.directory?(dest)
                logger.debug "mkdir -p #{dest}"
                FileUtils.mkdir_p(dest)
              end
            else
              unless src =~ /\/\./ # remove any pesky hidden files that crept into the archive
                logger.debug "cp #{src} #{dest}"
                FileUtils.cp(src, dest)
              end
            end
          end
        end

        # super-hacky, should install the theme first or create a new controller by hand
        File.open(File.join('app', 'controllers', 'railsthemes_controller.rb'), 'w') do |f|
          f.write <<-EOS
class RailsthemesController < ApplicationController
  # normally every view will use your application layout
  def inner
    render :layout => 'application'
  end

  # this is a special layout for landing and home pages
  def landing
    render :layout => 'landing'
  end
end
          EOS
        end

        inject_into_file File.join('app', 'controllers', 'railsthemes_controller.rb'), :after => 'class RailsthemesController < ApplicationController' do
<<-EOS

  def email
  end

  def send_email
    RailsthemesMailer.test_email(:to => params[:email]).deliver
    render :sent_email
  end
EOS
        end

        # copy-paste, refactor
        if File.exists?(File.join('config', 'routes.rb'))
          lines = Utils.read_file('config/routes.rb').split("\n")
          last = lines.pop
          if lines.grep(/railsthemes#email/).empty?
            lines << "  match 'railsthemes/email' => 'railsthemes#email'"
          end
          if lines.grep(/railsthemes#send_email/).empty?
            lines << "  match 'railsthemes/send_email' => 'railsthemes#send_email'"
          end
          lines << last
          File.open(File.join('config', 'routes.rb'), 'w') do |f|
            lines.each do |line|
              f.puts line
            end
          end
        end

        create_file File.join('app', 'mailers', 'railsthemes_mailer.rb') do
          <<-EOS
class RailsthemesMailer < ActionMailer::Base
  layout 'railsthemes_mailer'

  def test_email options = {}
    mail(:from => "anthony@railsthemes.com", :content_type => "text/html", :to => options[:to])
  end
end
EOS
        end

        create_file File.join('app', 'views', 'railsthemes', 'email.html.erb') do
          <<-EOS
<%= form_tag('/railsthemes/send_email') do |f| %>
  <div><%= label_tag 'email', 'Email to send to' %></div>
  <div><%= email_field_tag 'email' %></div>
  <div><%= submit_tag 'Send' %></div>
<% end %>
EOS

        end

        filename = File.join 'app', 'views', 'railsthemes_mailer', 'test_email.html.erb'
        create_file filename do
          "This text lives at #{filename}, the rest is taken care of by layouts!"
        end

        create_file File.join 'app', 'views', 'railsthemes', 'sent_email.html.erb' do
          "Sent the email to <%= params[:email] %>"
        end
      end
    end
  end
end
