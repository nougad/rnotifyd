#!/usr/bin/env ruby
$LOAD_PATH << "/home/feitel/notification/ruby-dbus/lib/"
require 'dbus'
require 'pp'
bus = DBus::SessionBus.instance
service = bus.service("org.freedesktop.Notifications")
notify = service.object("/org/freedesktop/Notifications")
notify.default_iface = "org.freedesktop.Notifications" 

puts "---------- service xml ----------"
puts notify.introspect
puts

iface = notify["org.freedesktop.Notifications"]

puts "---------- methods ----------"
pp iface.methods
puts

iface.on_signal(bus, "ActionInvoked") do |*params|
  puts "ActionInvoked #{params.inspect}"
end

iface.on_signal(bus, "NotificationClosed") do |*params|
  puts "NotificationClosed #{params.inspect}"
end


puts "---------- capabilities ----------"
puts iface.GetCapabilities.inspect
puts

puts "---------- server informations ----------"
puts iface.GetServerInformation.inspect
puts

# app_name,     id, icon,    summary,   body,           actions,                                      hints,                                                    timeout
notification = ["client-test", 0, "info", "subject", "B<b>od</b>Y", ["button1", "button1", "button2", "button2"], {"urgency" => [DBus::Type::Type.new(DBus::Type::BYTE), 1 ]}, -1]
sleep 1

id = iface.Notify *notification
puts "send notification id=#{id}"

sleep 4

id = iface.Notify *notification
puts "send notification id=#{id}"
sleep 1
puts "try to close notification"
iface.CloseNotification id.first

main = DBus::Main.new  
main << bus  
main.run  
