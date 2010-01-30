require "open-uri"
require "thread"
require "pp"
require "yaml"

config_ru = File.read("config.ru")
app_id      = config_ru[/:application\s*=>\s*[\'\"](.+)[\'\"]/, 1]
app_version = config_ru[/:version\s*=>\s*[\'\"](.+)[\'\"]/, 1]
$url_base = "http://#{app_version}.latest.#{app_id}.appspot.com"

$log_mutex = Mutex.new
def sync_puts(s)
  $log_mutex.synchronize{
    puts(s)
  }
end

def run_01props_put
  threads = []
  10.times do
    t = Thread.new do
      [1,2,4,8,16,32,64,128].each do |count|
        [true, false].each do |index|
          ["integer", "string"].each do |type|
            s = StringIO.new
            repeat = 5
            url = $url_base + "/01props_put?count=#{count}&type=#{type}&index=#{index}&repeat=#{repeat}"
            open(url) do |f|
              s.puts "######## count=#{count} type=#{type} index=#{index} repeat=#{repeat}"
              yaml_src = f.read
              result = YAML.load(yaml_src)
              s.puts(yaml_src)
            end
            sync_puts s.string
          end
        end
      end
    end
    threads << t
  end
  threads.each do |t|
    t.join
  end
end

# ruby -r dsbench.rb -e parse_01props_put < 01props_put_20100130_175803.ymls | sort
def parse_01props_put
  $stdin.read.split(/^########.+$/).each do |s|
    result = YAML.load(s)
    next unless result
    count  = result[:pars][:count]
    type   = result[:pars][:type]
    index  = result[:pars][:index]
    repeat = result[:pars][:repeat]
    api_ms_per_call  = result[:bench_result][:api_ms] / result[:api_calls].size
    real_ms_per_call = result[:api_calls].inject(0){|sum,a| sum+=a[:real_ms] } / result[:api_calls].size
    key = "#{'%03d' % count}_#{type.to_s[0,1]}_#{index.to_s[0,1]}_#{'%02d' % repeat}"
    puts "#{key},#{'%10.2f' % api_ms_per_call},#{'%10.2f' % real_ms_per_call}"
  end
end