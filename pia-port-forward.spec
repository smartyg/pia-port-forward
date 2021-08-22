#
# spec file for package kernel-scripts
#
# Copyright (c) 2021 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

%define short_name ppf

Name:           pia-port-forward
Version:        0.0.1
Release:        0
Summary:        Enables port forwarding over a PIA VPN
License:        GPL-2.0-or-later
Group:          System/Daemons
Url:            https://www.github.com/smartyg/pia-port-forward
Source0:        %{name}-%{version}.tar.xz
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
Provides:       %{_libexecdir}/%{short_name}/openvpn-set-gateway.sh
Requires:       systemd >= 236

%description
This opens and/or renew a port bind on the PIA (Private Internet Access) VPN service. After a port is aquired custom scripts can be run to update/change other services on the running system.

%prep
%setup -q -n %{name}-%{version}

%build
sed -i -e "s:@RUNDIR@:%_rundir:g" openvpn-set-gateway.sh

%install
install -m 700 -d %{buildroot}%{_sysconfdir}
install -m 700 -d %{buildroot}%{_sysconfdir}/%{short_name}
install -m 700 -d %{buildroot}%{_sysconfdir}/%{short_name}/general
install -m 600 user.conf %{buildroot}%{_sysconfdir}/%{short_name}/user.conf

install -m 750 -d %{buildroot}%{_sbindir}
install -m 750 ppf.sh %{buildroot}%{_sbindir}/ppf

install -m 750 -d %{buildroot}%{_libexecdir}/%{short_name}
install -m 750 openvpn-set-gateway.sh %{buildroot}%{_libexecdir}/%{short_name}/openvpn-set-gateway.sh

install -D -m 644 ppf@.service %{buildroot}%{_unitdir}/ppf@.service
install -D -m 644 ppf@.timer %{buildroot}%{_unitdir}/ppf@.timer

install -d -m 0755 %{buildroot}%{_tmpfilesdir}
install -m 0644 ppf.conf %{buildroot}%{_tmpfilesdir}/ppf.conf

%pre
%service_add_pre ppf@.service ppf@.timer

%post
%service_add_post ppf@.service ppf@.timer
%tmpfiles_create %_tmpfilesdir/ppf.conf

%preun
%service_del_preun ppf@.service ppf@.timer

%postun
%service_del_postun ppf@.service ppf@.timer

%files
%defattr(-,root,root)
%license LICENSE
%{_sbindir}/ppf
%{_libexecdir}/%{short_name}
%dir %{_sysconfdir}/%{short_name}
%config %{_sysconfdir}/%{short_name}/user.conf
%dir %{_sysconfdir}/%{short_name}/general
%{_unitdir}/ppf*
%{_tmpfilesdir}/ppf.conf
%ghost %{_rundir}/%{short_name}

%changelog
