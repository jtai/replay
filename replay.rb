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

logfile = ARGV[0]
node = (ARGV[1] || 1).to_i
nodes = (ARGV[2] || 1).to_i

if node > nodes
    puts "Usage: replay.rb logfile [node nodes]"
    exit 0
end

# open log file; should throw exception on error
log = File.open(logfile)

first_ts_s = nil
last_ts_s = nil
lineno = 0
requests = {}
parser_finished = false

# start log parsing thread
Thread.new do
    log.each do |line|
        # LogFormat "%{Host}i %{%d/%b/%Y:%H:%M:%S}t %U%q" replay
        host, timestamp, request = line.split(' ')

        first_ts_s = timestamp if first_ts_s.nil?
        last_ts_s = timestamp # FIXME: log file not perfectly sorted; last line in file may not really be last ts

        if lineno % nodes == node - 1
            requests[timestamp] ||= []
            requests[timestamp] << {:host => host, :request => request}
        end

        lineno += 1

        # if the buffer gets too big, pause for a bit while the HTTP requests thread catches up
        sleep(0.1) if requests.count >= 100
    end
    parser_finished = true
end

# wait for the log parsing thread to buffer up a few entries before we start making requests
(1..100).each do |i|
    break if requests.count >= 10 or parser_finished
    sleep(0.1)
end

# if we can't parse the logs at one log second per real second, we won't be able to feed the thread making the HTTP requests
throw "log parser running too slowly" unless requests.count >= 10 or parser_finished

dt = DateTime.strptime(first_ts_s, '%d/%b/%Y:%H:%M:%S')
first_ts = Time.mktime(dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec)
log_ts = first_ts

start_ts = Time.now

# make http requests
while true
    sys_ts = Time.now

    # convert to string
    log_ts_s = log_ts.strftime('%d/%b/%Y:%H:%M:%S')

    requests_this_second = requests[log_ts_s] || []
    puts "log time: #{(log_ts - first_ts).to_i}, real time: #{(sys_ts - start_ts).round.to_i}, buffer #{requests.count}, making #{requests_this_second.count} requests"
    requests_this_second.each do |info|
        Thread.new do
            sleep(rand())

            req = Net::HTTP::Get.new(info[:request])
            resp = Net::HTTP.start(info[:host], 80) do |http|
                http.request(req);
            end
        end
    end

    # free memory
    requests.delete(log_ts_s)

    # we just processed the last timestamp in the log; exit
    break if log_ts_s == last_ts_s

    # otherwise, get ready to process the next second
    log_ts += 1

    # sleep the remainder of the second so we stay in sync with the log
    sleep(1 - (Time.now - sys_ts))
end

# wait for threads to finish
puts "waiting for threads to finish"
Thread.list.each do |thread|
    thread.join unless thread == Thread.current
end

