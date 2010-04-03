#!/usr/bin/env ruby
$LOAD_PATH << "/home/feitel/notification/ruby-dbus/lib/"
require 'dbus'
require 'pp'
bus = DBus::SessionBus.instance
service = bus.service("org.freedesktop.Notifications")
notify = service.object("/org/freedesktop/Notifications")
notify.default_iface = "org.freedesktop.Notifications" 
puts notify.introspect
iface = notify["org.freedesktop.Notifications"]

pp iface.methods

iface.on_signal(bus, "ActionInvoked") do |*params| puts params.inspect end
iface.on_signal(bus, "NotificationClosed") do |*params| puts params.inspect end

puts iface.GetCapabilities.inspect
puts iface.GetServerInformation.inspect
#                 app_name,     id, icon,    summary,   body,           actions,                                      hints,                                                    timeout
id = iface.Notify("client-test", 0, "info", "subject", "B<b>od</b>Y", ["button1", "button1", "button2", "button2"], {"urgency" => [DBus::Type::Type.new(DBus::Type::BYTE), 1 ]}, -1)
puts id
#iface.CloseNotification id

main = DBus::Main.new  
main << bus  
main.run  
