#!/usr/bin/env ruby
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__),"ruby-dbus","lib"))
require 'dbus'
require 'thread'

class Job < Struct.new(:id, :receiver, :time, :action, :params)
  def <=>; o time <=> o.time; end
end
class Dispatcher
  def initialize
    @mutex = Mutex.new
    @jobs = Array.new
    start
  end

  def add_job job
    @mutex.synchronize do
      @jobs << job
      @jobs.sort!
    end
    @d.wakeup
  end
  def delete_job job_or_id, action=nil
    @mutex.synchronize do
      if action == nil
        job = job_or_id
        raise "no job given" if job != Job
        @jobs.delete job
      else
        id = job_or_id
        @jobs.delete_if do |job|
          job.id == id and (action.nil? or job.action == action)
        end
      end
    end
  end
  def execute_job job
    @mutex.synchronize do
      job.receiver.send(job.action, *job.params)
    end
  end
  def next_job
    @mutex.synchronize do
      @jobs.first
    end
  end
private
  def start
    @d = Thread.new do
      loop do
        job = next_job
        if job and (intervall = job.time - Time.now) > 0
          sleep intervall
        elsif job.nil?
          sleep
        end # else -> execute next job
        @mutex.synchronize do
          job = @jobs.first
          if !job.nil? and Time.now >= job.time
            job.receiver.send(job.action, *job.params)
            @jobs.delete job
          end
        end
      end
    end
  end
end

class NotifyDaemon < DBus::Object
  EXPIRED   = 1 # The notification expired.
  DISMISSED = 2 # The notification was dismissed by the user.
  CLOSED    = 3 # The notification was closed by a call to CloseNotification.
  UNDEFINED = 4 # Undefined/reserved reasons.

  def initialize config
    super "/org/freedesktop/Notifications"
    @last_id = 0
    @opened = Hash.new
    @config = config
    service = config[:bus].request_service "org.freedesktop.Notifications"
    service.export self
  end

  dbus_interface "org.freedesktop.Notifications" do
    dbus_method :Notify, "in app_name:s, in id:u, in icon:s, in summary:s, in body:s, in actions:as, in hints:a{sv}, in timeout:i, out return_id:u" do |*params|
      puts "Notify: #{params.inspect}" if $DEBUG
      id = @last_id += 1
      timeout = (params[7] > 0) ? params[7] : @config[:expiretime]
      @opened[id] = Thread.new do
        open_notification *params
        sleep timeout
        close_notification id, EXPIRED if @opened[id]
      end
      return id
    end
    dbus_method :CloseNotification, "in id:u" do |id|
      puts "CloseNotification #{id}" if $DEBUG
      close_notification id, CLOSED
    end
    dbus_method :GetCapabilities, "out return_caps:as" do |*params|
      puts "GetCapabilities #{params.inspect}" if $DEBUG
      return [@config[:capabilities]]
    end
    dbus_method :GetServerInformation, "out return_name:s, out return_vendor:s, out return_version:s, out return_spec_version:s" do |*params|
      puts "GetServerInformation #{params.inspect}" if $DEBUG
      return [@config[:serverinfos][:name], @config[:serverinfos][:vendor], @config[:serverinfos][:version], @config[:serverinfos][:spec]]
    end
    dbus_signal :NotificationClosed, "id:u, reason:u"
    dbus_signal :ActionInvoked, "id:u, action_key:s"
  end

  def close_notification id, reason
    if @opened[id]
      @opened.delete(id).kill
      NotificationClosed, id, reason
    end
  end

  def open_notification app_name, id, icon, summary, body, actions, hints, timeout
    # TODO replace old notification if id is set
    system "echo 'Notice #{summary} #{body}' | wmiir write /event"
  end

  def start
    main = DBus::Main.new
    main << @config[:bus]
    main.run
  end
end

config = {
  :expiretime => 3,
  :capabilities => [
    "actions",
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
  },
  :bus => DBus.session_bus,
  :dispatcher => Dispatcher.new
}

NotifyDaemon.new(config).start

