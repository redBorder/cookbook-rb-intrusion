Name: cookbook-rb-intrusion
Version: %{__version}
Release: %{__release}%{?dist}.1
BuildArch: noarch
Summary: cookbook to deploy rb-intrusion in redborder environments

License: AGPL 3.0
URL: https://github.com/redBorder/cookbook-example
Source0: %{name}-%{version}.tar.gz

Requires: bind-utils

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/var/chef/cookbooks/rb-intrusion
cp -f -r  resources/* %{buildroot}/var/chef/cookbooks/rb-intrusion
chmod -R 0755 %{buildroot}/var/chef/cookbooks/rb-intrusion
install -D -m 0644 README.md %{buildroot}/var/chef/cookbooks/rb-intrusion/README.md

%pre

%post
case "$1" in
  1)
    # This is an initial install.
    :
  ;;
  2)
    # This is an upgrade.
    su - -s /bin/bash -c 'source /etc/profile && rvm gemset use default && env knife cookbook upload rb-intrusion'
  ;;
esac

%files
%defattr(0644,root,root)
%attr(0755,root,root)
/var/chef/cookbooks/rb-intrusion
%defattr(0644,root,root)
/var/chef/cookbooks/rb-intrusion/README.md


%doc

%changelog
* Fri Oct 31 2025 Luis Blanco <ljblanco@redborder.com>
- Add bind-utils dependency since we use dig for domain resolution
