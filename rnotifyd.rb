#!/usr/bin/env ruby
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__),"ruby-dbus","lib"))
require 'dbus'

# TODO make it thread save?
class NotifyDaemon < DBus::Object
  EXPIRED   = 1 # The notification expired.
  DISMISSED = 2 # The notification was dismissed by the user.
  CLOSED    = 3 # The notification was closed by a call to CloseNotification.
  UNDEFINED = 4 # Undefined/reserved reasons.

  def initialize config
    super "/org/freedesktop/Notifications"
    @last_id = 0
    @opened = Hash.new
    @bus = DBus.session_bus
    @config = config
    service = @bus.request_service "org.freedesktop.Notifications"
    service.export self
  end

  dbus_interface "org.freedesktop.Notifications" do
    dbus_method :Notify, "in app_name:s, in id:u, in icon:s, in summary:s, in body:s, in actions:as, in hints:a{sv}, in timeout:i, out return_id:u" do |*params|
      puts "Notify: #{params.inspect}" if $DEBUG
      # TODO replace old notification if id is set
      @last_id += 1
      id = @last_id
      @opened[id] = Thread.new do
        open_notification *params
        sleep @config[:expiretime]
        close_notification id, EXPIRED if @opened[id]
      end
      id
    end
    dbus_method :CloseNotification, "in id:u" do |*params|
      puts "CloseNotification #{params.inspect}" if $DEBUG
      close_notification @last_id, CLOSED
    end
    dbus_method :GetCapabilities, "out return_caps:as" do |*params|
      puts "GetCapabilities #{params.inspect}" if $DEBUG
      [@config[:capabilities]]
    end
    dbus_method :GetServerInformation, "out return_name:s, out return_vendor:s, out return_version:s, out return_spec_version:s" do |*params|
      puts "GetServerInformation #{params.inspect}" if $DEBUG
      [@config[:serverinfos][:name], @config[:serverinfos][:vendor], @config[:serverinfos][:version], @config[:serverinfos][:spec]]
    end
  end

  def action_invoked id, action_key
    dbus_signal :ActionInvoked, "#{id}:u", "#{action_key}:s"
  end
  def close_notification id, reason
    if @opened[id]
      @opened.delete(id).kill
      dbus_signal :NotificationClosed, "#{id}:u", "#{reason}:u"
    end
  end

  def open_notification app_name, id, icon, summary, body, actions, hints, timeout
    system "echo 'Notice #{summary} #{body}' | wmiir write /event"
  end
  def start
    main = DBus::Main.new
    main << @bus
    main.run
  end
end

config = {
  :expiretime => 3,
  :capabilities => [
  # "actions",
    "body",
  # "body-hyperlinks",
  # "body-images",
  # "body-markup",
  # "icon-multi",
  # "icon-static",
  # "sound",
  ],
  :serverinfos => {
    :name    => "rnotifyd",
    :vendor  => "nougad",
    :version => "0.02",
    :spec   => "0.9",
  }
}

NotifyDaemon.new(config).start

