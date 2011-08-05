#!/usr/bin/ruby
#
# replay.rb
# Replay HTTP requests from an apache log file
#
# Copyright (c) 2011 IGN Entertainment
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'date'
require 'thread'
require 'net/http'

if ARGV.empty?
    puts "Usage: replay.rb logfile [node nodes]"
    exit 0
end

log = ARGV[0]
node = (ARGV[1] || 1).to_i
nodes = (ARGV[2] || 1).to_i

if node > nodes
    puts "Usage: replay.rb logfile [node nodes]"
    exit 0
end

lineno = 0

def parse_timestamp(timestamp)
    dt = DateTime.strptime(timestamp, '%d/%b/%Y:%H:%M:%S')
    return Time.mktime(dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec).to_i
end

first_ts = nil
last_ts = nil

requests = {}

# parse access log
puts "parsing #{log}"
File.open(log).each do |line|
    # LogFormat "%{Host}i %{%d/%b/%Y:%H:%M:%S}t %U%q" replay
    host, timestamp, request = line.split(' ')

    timestamp = parse_timestamp(timestamp)

    first_ts = timestamp if first_ts.nil?
    last_ts = timestamp

    if lineno % nodes == node - 1
        requests[timestamp] ||= []
        requests[timestamp] << {:host => host, :request => request}
    end

    lineno += 1
end

start_ts = Time.now.to_i

# make HTTP requests
(first_ts..last_ts).each do |timestamp|
    requests[timestamp] ||= []
    puts "log time: #{timestamp - first_ts}, real time: #{Time.now.to_i - start_ts}, making #{requests[timestamp].count} requests"
    if requests[timestamp].empty?
        sleep 1
    else
        requests[timestamp].each do |info|
            Thread.new do
                req = Net::HTTP::Get.new(info[:request])
                resp = Net::HTTP.start(info[:host], 80) do |http|
                    http.request(req);
                end
            end
            sleep (1.0/requests[timestamp].count)
        end
    end
end

# wait for threads to finish
puts "waiting for threads to finish"
Thread.list.each do |thread|
    thread.join unless thread == Thread.current
end

