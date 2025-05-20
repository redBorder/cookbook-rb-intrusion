# Add manager node ip addr to /etc/hosts
# We need this for the kafka problem
# Is replaying with manager.domain and
# The ips need to be able to resolv this

# This check can be deprecated since we started to control /etc/hosts with
# Chef, hosts.erb template and update_hosts_file.rb library
# Activate if you need to check something different rather than
# /etc/hosts

ruby_block 'update_hosts_file_if_needed' do
  block do
    def managerToIp(str)
      ipv4_regex = /\A(\d{1,3}\.){3}\d{1,3}\z/
      ipv6_regex = /\A(?:[A-Fa-f0-9]{1,4}:){7}[A-Fa-f0-9]{1,4}\z/
      dns_regex = /\A[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+\z/

      return str if str =~ ipv4_regex || str =~ ipv6_regex

      if str =~ dns_regex
        ip = `dig +short #{str}`.strip
        return ip unless ip.empty?
      end
      nil
    end

    unless node['redborder']['cloud']
      # Read webui_host from the rb_init_conf.yml file
      webui_host_command = "grep '^webui_host:' /etc/redborder/rb_init_conf.yml | awk '{print $2}'"
      webui_host = managerToIp `#{webui_host_command}`.strip

      # Search for a node matching the webui_host IP address
      matching_node_name = search(:node, "ipaddress:#{webui_host}").first&.name

      # Update /etc/hosts if a matching node is found
      if matching_node_name
        node_name_with_suffix = "#{matching_node_name}.node"
        hosts_file = '/etc/hosts'

        unless ::File.readlines(hosts_file).grep(/#{Regexp.escape(node_name_with_suffix)}/).any?
          ::File.open(hosts_file, 'a') { |file| file.puts "#{webui_host} #{node_name_with_suffix}" }
        end # THE ELSE should always happen, since we are controlling the file through template /etc/hosts
      end # else IPS was registered using Virtual IP
    end
  end
  action :run
end
