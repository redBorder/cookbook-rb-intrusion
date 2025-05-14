module RbIps
  module Helpers
    def get_external_databag_services
      Chef::DataBag.load('rBglobal').keys.grep(/^ipvirtual-external-/).map { |bag| bag.sub('ipvirtual-external-', '') }
    end

    # Is weird to read the file to update it, just because we want not to remove unmanaged system configuration
    def read_hosts_file
      hosts_hash = Hash.new { |hash, key| hash[key] = [] }
      File.readlines('/etc/hosts').each do |line|
        next if line.strip.empty? || line.start_with?('#')
        values = line.split(/\s+/)
        ip = values.shift
        services = values
        hosts_hash[ip].concat(services).uniq!
      end
      hosts_hash # IP => [services and nodes]
    end

    def manager_node_names
      query = Chef::Search::Query.new
      nodes = []
      query.search(:node, 'is_manager:true') do |node|
        nodes << node.name + '.node'
      end
      nodes
    end

    def update_hosts_file
      manager_registration_ip = node['redborder']['manager_registration_ip'] if node['redborder'] && node['redborder']['manager_registration_ip']
      return unless manager_registration_ip # Can be also virtual ip

      running_services = node['redborder']['systemdservices'].values.flatten if node['redborder']['systemdservices']
      databags = get_external_databag_services

      # Hash where services (from databag) are grouped by ip
      grouped_virtual_ips = Hash.new { |hash, key| hash[key] = [] }
      databags.each do |bag|
        virtual_dg = data_bag_item('rBglobal', "ipvirtual-external-#{bag}")
        ip = virtual_dg['ip']

        if ip && !ip.empty?
          grouped_virtual_ips[ip] << bag.gsub('ipvirtual-external-', '')
        else
          grouped_virtual_ips[manager_registration_ip] << bag.gsub('ipvirtual-external-', '')
        end
      end

      # Add running services to localhost
      # Why only localhost is being grouped?
      grouped_virtual_ips['127.0.0.1'] ||= []
      running_services.each { |serv| grouped_virtual_ips['127.0.0.1'] << serv }

      # Group services
      hosts_hash = read_hosts_file
      grouped_virtual_ips.each do |new_ip, new_services|
        new_services.each do |new_service|
          # Avoids having duplicate services in the list
          service_key = new_service.split('.').first
          hosts_hash.each do |_ip, services|
            services.delete_if { |service| service.split('.').first == service_key }
          end

          # Add running services to localhost
          if new_ip == '127.0.0.1' && running_services.include?(new_service)
            hosts_hash['127.0.0.1'] << "#{new_service}.service"
            next #service
          end

          # If there is a virtual ip and IPS is manager mode
          if new_ip && !node['redborder']['cloud']
            hosts_hash[new_ip] << "#{new_service}.service"
            hosts_hash[new_ip] << "#{new_service}.#{node['redborder']['cdomain']}"
          else # Add services with manager_registration_ip
            hosts_hash[manager_registration_ip] << "#{new_service}.service"
            hosts_hash[manager_registration_ip] << "#{new_service}.#{node['redborder']['cdomain']}"
          end
        end
      end

      hosts_hash[manager_registration_ip] = (hosts_hash[manager_registration_ip] || []) + manager_node_names

      # Prepare the lines for the hosts file
      # TODO: include in host entries manager-.node when cluster is implemented
      hosts_entries = []
      hosts_hash.each do |ip, services|
        format_entry = format('%-18s%s', ip, services.join(' '))
        hosts_entries << format_entry unless services.empty?
      end
      hosts_entries
    end
  end
end
