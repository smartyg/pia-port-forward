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


Name:           pia-port-forward
Version:        0.0.1
Release:        0
Summary:        Enables port forwarding over a PIA VPN
License:        GPL-2.0-or-later
Group:
Url:            https://www.github.com/smartyg/pia-port-forward
Source0:        pff.sh
Source1:        pff@.service
Source2:        pff@.timer
Source3:        pff.conf
Source4:        user.conf
Source5:        openvpn-set-gateway.sh
Source9:        LICENSE
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
Provides:       %{_libexecdir}/%{name}/openvpn-set-gateway.sh
Requires:       systemd >= 236

%description
This opens and/or renew a port bind on the PIA (Private Internet Access) VPN service. After a port is aquired custom scripts can be run to update/change other services on the running system.

%prep

%build
sed -i -e "s:@RUNDIR@:%_rundir:g" %{SOURCE5}

%install
install -m 700 -d %{buildroot}%{_sysconfdir}
install -m 700 -d %{buildroot}%{_sysconfdir}/%{name}
install -m 700 -d %{buildroot}%{_sysconfdir}/%{name}/general
install -m 600 %{SOURCE4} %{buildroot}%{_sysconfdir}/%{name}/user.conf

install -m 750 -d %{buildroot}%{_sbindir}
install -m 750 %{SOURCE0} %{buildroot}%{_sbindir}/ppf

install -m 750 -d %{buildroot}%{_libexecdir}/%{name}
install -m 750 %{SOURCE5} %{buildroot}%{_libexecdir}/%{name}/openvpn-set-gateway.sh

install -D -m 644 %{SOURCE1} %{buildroot}%{_unitdir}/ppf@.service
install -D -m 644 %{SOURCE2} %{buildroot}%{_unitdir}/ppf@.timer

install -d -m 0755 %{buildroot}%{_tmpfilesdir}
install -m 0644 %{SOURCE3} %{buildroot}%{_tmpfilesdir}/ppf.conf

%pre
%service_add_pre pff@.service ppf@.timer

%post
%service_add_post pff@.service ppf@.timer
%tmpfiles_create %_tmpfilesdir/ppf.conf

%preun
%service_del_preun pff@.service ppf@.timer

%postun
%service_del_postun pff@.service ppf@.timer

%files
%defattr(-,root,root)
%license LICENSE
%{_sbindir}/ppf
%{_libexecdir}/%{name}
%{_sysconfdir}/%{name}/*
%{_unitdir}/ppf*
%{_tmpfilesdir}/ppf.conf

%changelog
