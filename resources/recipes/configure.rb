# Cookbook:: ips
# Recipe:: configure
# Copyright:: 2024, redborder
# License:: Affero General Public License, Version 3

# Services configuration

extend RbIps::Helpers

# ips services
ips_services = ips_services()

# ip_regex = /^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$/
# resolv_dns_dg = Chef::DataBagItem.load("rBglobal", "resolv_dns")   rescue resolv_dns_dg={}
# monitors_dg   = Chef::DataBagItem.load("rBglobal", "monitors")     rescue monitors_dg={}

# begin
#   domain_db = data_bag_item('rBglobal', 'publicdomain')
# rescue
#   domain_db = {}
# end

# if domain_db["name"].nil? or domain_db["name"]==""
#   node.normal["redBorder"]["cdomain"] = "redborder.cluster"
# else
#   node.normal["redBorder"]["cdomain"] = domain_db["name"]
# end

begin
  sensor_id = node['redborder']['sensor_id'].to_i
rescue
  sensor_id = 0
end

rb_common_config 'Configure common' do
  action :configure
end

rb_selinux_config 'Configure Selinux' do
  if shell_out('getenforce').stdout.chomp == 'Disabled'
    action :remove
  else
    action :add
  end
end

node.normal['redborder']['chef_client_interval'] = 300

directory '/etc/snortpcaps' do
  owner 'root'
  group 'root'
  mode '0755'
  recursive true
  action :create
end

if sensor_id > 0
  node.run_list(['role[intrusion-sensor]', "role[rBsensor-#{sensor_id}]", 'role[intrusion-sensor]'])
end

hosts_entries = update_hosts_file()

template '/etc/hosts' do
  source 'hosts.erb'
  cookbook 'rb-intrusion'
  owner 'root'
  group 'root'
  mode '644'
  retries 2
  variables(hosts_entries: hosts_entries)
end

# Motd

manager = if node['redborder']['cloud']
            `grep "cloud_address" /etc/redborder/rb_init_conf.yml | cut -d' ' -f2`
          else
            `grep "webui_host" /etc/redborder/rb_init_conf.yml | cut -d' ' -f2`
          end

template '/etc/motd' do
  source 'motd.erb'
  owner 'root'
  group 'root'
  mode '0644'
  retries 2
  variables(manager_info: node['redborder']['cdomain'], manager: manager)
end

# CLI Banner configuration
template '/etc/cli_banner' do
  source 'cli_banner.erb'
  cookbook 'rb-intrusion'
  owner 'root'
  owner 'root'
  mode '0644'
  retries 2
end

template '/etc/chef/role-sensor.json' do
  source 'role-sensor.json.erb'
  cookbook 'rb-intrusion'
  owner 'root'
  group 'root'
  mode '0644'
  retries 2
  variables(sensor_id: sensor_id)
end

template '/etc/chef/role-sensor-once.json' do
  source 'role-sensor-once.json.erb'
  cookbook 'rb-intrusion'
  owner 'root'
  group 'root'
  mode '0644'
  retries 2
  variables(sensor_id: sensor_id)
end

template '/etc/sudoers.d/redBorder' do
  source 'redBorder.erb'
  cookbook 'rb-intrusion'
  owner 'root'
  group 'root'
  mode '0440'
  retries 2
end

begin
  ssh_secrets = data_bag_item('passwords', 'ssh')
rescue
  ssh_secrets = {}
end

unless node['redborder']['cloud']
  # ssh user for webui execute commands on
  execute 'create_user_redBorder' do
    command 'sudo useradd -m -s /bin/bash redborder'
    not_if 'getent passwd redborder'
  end

  directory '/home/redborder/.ssh' do
    owner 'redborder'
    group 'redborder'
    mode '0755'
    action :create
  end

  unless ssh_secrets.empty? || ssh_secrets['public_rsa'].nil?
    template '/home/redborder/.ssh/authorized_keys' do
      source 'rsa.pub.erb'
      owner 'redborder'
      group 'redborder'
      mode '0600'
      variables(
        public_rsa: ssh_secrets['public_rsa']
      )
      action :create
    end
  end
end
# template "/opt/rb/etc/sysconfig/iptables" do
#   source "iptables.erb"
#   owner "root"
#   group "root"
#   mode 0644
#   retries 2
#   notifies :restart, "service[iptables]"
# end

# directory "/opt/rb/root/.chef" do
#   owner "root"
#   group "root"
#   mode 0755
#   recursive true
#   action :create
# end

# template "/root/.chef/knife.rb" do
#   source "knife.rb.erb"
#   owner "root"
#   group "root"
#   mode 0600
# end

# template "/etc/yum.repos.d/redBorder-manager.repo" do
#   source "redBorder-manager.repo.erb"
#   owner "root"
#   group "root"
#   mode 0644
#   retries 2
# end

template '/etc/sensor_id' do
  source 'variable.erb'
  cookbook 'rb-intrusion'
  owner 'root'
  group 'root'
  mode '0644'
  retries 2
  variables(variable: sensor_id)
end

geoip_config 'Configure GeoIP' do
  user_id node['redborder']['geoip_user']
  license_key node['redborder']['geoip_key']
  action :add
end

cookbook_file '/usr/share/GeoIP/country.dat' do
  source 'country.dat'
  owner 'root'
  group 'root'
  mode '0644'
end

snmp_config 'Configure snmp' do
  hostname node['hostname']
  cdomain node['redborder']['cdomain']
  if ips_services['snmp']
    action :add
  else
    actopm :remove
  end
end

rb_exporter_config 'Configure rb-exporter' do
  if ips_services['redborder-exporter']
    action :add
  else
    action :remove
  end
end

# rsyslog_config "Configure rsyslog" do
#   vault_nodes node.run_state["sensors_info_all"]["vault-sensor"]
#   action (ips_services["rsyslog"] ? [:add] : [:remove])
# end

if node['redborder']['chef_enabled'].nil? || node['redborder']['chef_enabled']

  groups_in_use = get_groups_in_use_info
  snort3_config 'Configure Snort' do
    sensor_id sensor_id
    groups groups_in_use
    if ips_services['snortd'] && !node['redborder']['snort']['groups'].empty? && sensor_id > 0 && node['redborder']['segments'] && node['cpu'] && node['cpu']['total']
      action :add
    else
      action :remove
    end
  end

  if sensor_id > 0 && node['redborder'] && node['redborder']['segments']
    # Activate bypass on unused segments
    node['redborder']['segments'].each_key do |s|
      next unless s =~ /^bpbr[\d]+$/

      # Switch on bypass on those segments that are not in use
      next unless groups_in_use.select { |g| g['segments'].include?(s) }.empty?

      execute "bypass_#{s}" do
        command "/usr/lib/redborder/bin/rb_bypass.sh -b #{s} -s on"
        ignore_failure true
        action :run
      end
    end

    # Delete unnecesary files:
    groups = node['redborder']['snort']['groups'].keys.map(&:to_i)

    [
      { files: '/etc/sysconfig/snort-*', regex: %r{/snort-(\d+)$} },
      { files: '/etc/snort/*', regex: %r{/(\d+)$} },
      { files: '/var/log/snort/*', regex: %r{/(\d+)$} },
    ].each do |x|
      Dir.glob(x[:files]).each do |f|
        match = f.match(x[:regex])
        if match && !groups.include?(match[1].to_i)
          if File.directory?(f)
            directory f do
              recursive true
              action :delete
            end # do
          else
            file f do
              action :delete
            end
          end
        end
      end
    end

    # Clean rubish for snort and barnyard instances should not be running
    %w(snortd).each do |s|
      next unless File.exist?("/etc/init.d/#{s}")
      execute "cleanstop_#{s}" do
        command "/etc/init.d/#{s} cleanstop"
        ignore_failure true
        action :run
      end
    end
  end
end

# template "/etc/rb_snmp_pass.yml" do
#   source "rb_snmp_pass.yml.erb"
#   cookbook "rb-ips"
#   owner "root"
#   group "root"
#   mode 0755
#   retries 2
#   variables(:monitors => monitors_dg["monitors"])
#   notifies :stop, "service[snmptrapd]", :delayed
#   notifies :restart, "service[snmpd]", :delayed
#   notifies :start, "service[snmptrapd]", :delayed
# end

dnf_package 'watchdog' do
  action :upgrade
end

template '/etc/watchdog.conf' do
  source 'watchdog.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  retries 2
  notifies :restart, 'service[watchdog]'
end

template '/etc/watchdog.d/020-check-snort.sh' do
  source 'watchdog_020-check-snort.sh.erb'
  owner 'root'
  group 'root'
  mode '0755'
  retries 2
  notifies :restart, 'service[watchdog]', :delayed
end

template '/etc/watchdog.d/030-check-cpu.sh' do
  source 'watchdog_030-check-cpu.sh.erb'
  owner 'root'
  group 'root'
  mode '0755'
  retries 2
  notifies :restart, 'service[watchdog]', :delayed
end

if node['redborder']['ipsrules'] && node['redborder']['cloud']
  node['redborder']['ipsrules'].to_hash.each do |groupid, _ipsrules|
    if node['redborder']['ipsrules'][groupid]['command'].nil? || node['redborder']['ipsrules'][groupid]['command'].empty?
      next
    end
    if node['redborder']['ipsrules'][groupid]['timestamp'].to_i <= 0
      next
    end
    if node['redborder']['ipsrules'][groupid]['timestamp_last'].to_i >= node['redborder']['ipsrules'][groupid]['timestamp'].to_i
      next
    end
    if node['redborder']['ipsrules'][groupid]['uuid'].nil? || node['redborder']['ipsrules'][groupid]['uuid'].empty?
      next
    end

    original_command = node['redborder']['ipsrules'][groupid]['command'].to_s
    command = original_command.gsub(/^sudo(\s+-E)?\s+/, '').gsub(/;/, ' ')

    unless command.start_with?('/bin/env BOOTUP=none /usr/lib/redborder/bin/rb_get_sensor_rules.sh ')
      next
    end

    execute "download_rules_#{groupid}" do
      command "/usr/lib/rvm/bin/rvm ruby-2.7.5@global do /usr/lib/redborder/scripts/rb_get_sensor_rules_cloud.rb -c '#{command}' -u #{node['redborder']['ipsrules'][groupid]['uuid'].to_s}"
      ignore_failure true
      live_stream true
      action :run
      notifies :create, "ruby_block[update_rule_timestamp_#{groupid}]", :immediately
    end

    ruby_block "update_rule_timestamp_#{groupid}" do
      block do
        node.normal['redborder']['ipsrules'][groupid]['timestamp_last'] = node['redborder']['ipsrules'][groupid]['timestamp']
      end
      action :nothing
    end
  end
end

# service "iptables" do
#   service_name "iptables"
#   ignore_failure true
#   supports :status => true, :reload => false, :restart => true
#   action([:start])
# end

rbmonitor_config 'Configure redborder-monitor' do
  name node['hostname']
  if ips_services['redborder-monitor'] && sensor_id > 0
    action :add
  else
    action :remove
  end
end

dnf_package 'bp_watchdog' do
  action :upgrade
end

service 'bp_watchdog' do
  service_name 'bp_watchdog'
  ignore_failure true
  supports status: true, reload: true, restart: true
  if node['redborder']['has_bypass']
    action([:start, :enable])
  else
    action([:stop, :disable])
  end
end

service 'watchdog' do
  service_name node['redborder']['watchdog']['service']
  ignore_failure true
  supports status: true, restart: true
  action([:start, :enable])
end

# service "chef-client" do
#   service_name "chef-client"
#   ignore_failure true
#   supports :status => true, :reload => true, :restart => true
#   action([:enable])
# end

service 'sshd' do
  service_name 'sshd'
  ignore_failure true
  supports status: true, reload: false, restart: true
  action [:start, :enable]
end

rbcgroup_config 'Configure cgroups' do
  action :add
end

rb_clamav_config 'Configure ClamAV' do
  action(ips_services['clamav'] ? :add : :remove)
end

rb_chrony_config 'Configure Chrony' do
  if ips_services['chrony']
    action :add
  else
    action :remove
  end
end

execute 'force_chef_client_wakeup' do
  command '/usr/lib/redborder/bin/rb_wakeup_chef'
  ignore_failure true
  if sensor_id > 0
    action :nothing
  else
    action :run
  end
end

# if (node["redBorder"]["force-run-once"].nil? or node["redBorder"]["force-run-once"]==false or !node["redBorder"]["force-run-once"])
#   template "/etc/chef/client.rb" do
#     source "chef_client.rb.erb"
#     owner "root"
#     group "root"
#     mode 0644
#     retries 2
#     variables(:joined => sensor_id>0 )
#   end
# else
#   node.normal["redBorder"]["force-run-once"]=false
# end

# if File.exists?("/etc/yum.repos.d/redBorder.repo")
#   file "/etc/yum.repos.d/redBorder.repo" do
#       action :delete
#   end
# end

# template "/etc/yum.repos.d/CentOS-Base.repo" do
#   source "CentOS-Base.repo.erb"
#   owner "root"
#   group "root"
#   mode 0644
#   retries 2
#   backup false
# end

# template "/opt/rb/etc/chef/uptime" do
#   source "variable.erb"
#   owner "root"
#   group "root"
#   mode 0644
#   retries 2
#   backup false
#   variables(:variable => Time.now.to_i)
# end

# template "/etc/ssh/sshd_config" do
#   source "sshd_config.erb"
#   owner "root"
#   group "root"
#   mode 0755
#   retries 2
#   notifies :restart, "service[sshd]", :delayed
# end

# template "/etc/pam.d/system-auth" do
#   source "system-auth.erb"
#   owner "root"
#   group "root"
#   mode 0755
#   retries 2
#   notifies :restart, "service[sshd]", :delayed
# end

# template "/etc/pam.d/password-auth" do
#   source "password-auth.erb"
#   owner "root"
#   group "root"
#   mode 0755
#   retries 2
#   notifies :restart, "service[sshd]", :delayed
# end

if File.exist?('/etc/init.d/rb-lcd')
  execute 'rb-lcd' do
    lcd = !Dir.glob('/dev/ttyUSB*').empty?
    only_if "#{lcd}"
    command '/bin/env WAIT=1 /etc/init.d/rb-lcd start'
    ignore_failure true
    action :nothing
  end.run_action(:run)
end
