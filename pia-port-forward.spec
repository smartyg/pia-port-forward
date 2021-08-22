#
# spec file for package kernel-scripts
#
# Copyright (c) 2020 SUSE LINUX GmbH, Nuernberg, Germany.
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
Source1:        pff.service
Source2:        pff.timer
Source3:        pff.conf
Source9:        LICENSE
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
Provides:       %{_libexecdir}/%{name}/run-kernel-scripts
Requires:       coreutils
Requires:       find
Requires:       systemd >= 236

%description
This opens and/or renew a port bind on the PIA (Private Internet Access) VPN service. After a port is aquired custom scripts can be run to update/change other services on the running system.

%prep
cp %{SOURCE0} %{_builddir}
cp %{SOURCE2} %{_builddir}
cp %{SOURCE3} %{_builddir}
cp %{SOURCE9} %{_builddir}

%build
sed -i -e "s:@ETCDIR@:%_sysconfdir:g" run-kernel-scripts
sed -i -e "s:@RUNDIR@:%_rundir:g" run-kernel-scripts


%install
install -m 750 -d %{buildroot}%{_sysconfdir}
install -m 750 -d %{buildroot}%{_sysconfdir}/%{name}
install -m 750 -d %{buildroot}%{_sysconfdir}/%{name}/general
install -m 750 -d %{buildroot}%{_libexecdir}/%{name}
install -m 750 pff.sh %{buildroot}%{_sbindir}/ppf

install -D -m 644 %{SOURCE1} %{buildroot}%{_unitdir}/ppf.service
install -D -m 644 %{SOURCE2} %{buildroot}%{_unitdir}/ppf.timer

install -d -m 0755 %{buildroot}%{_tmpfilesdir}
install -m 0644 %{SOURCE2} %{buildroot}%{_tmpfilesdir}/ppf.conf

%pre
%service_add_pre pff.service ppf.timer

%post
%service_add_post pff.service ppf.timer
%tmpfiles_create %_tmpfilesdir/ppf.conf

%preun
%service_del_preun pff.service ppf.timer

%postun
%service_del_postun pff.service ppf.timer

%files
%defattr(-,root,root)
%license LICENSE
%{_libexecdir}/%{name}
%{_libexecdir}/%{name}/run-kernel-scripts
%dir %{_sysconfdir}/%{name}
%dir %{_sysconfdir}/%{name}/pre-install.d
%dir %{_sysconfdir}/%{name}/post-install.d
%dir %{_sysconfdir}/%{name}/pre-uninstall.d
%dir %{_sysconfdir}/%{name}/post-uninstall.d
%dir %{_sysconfdir}/%{name}/config

%changelog

