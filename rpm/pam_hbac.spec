%if 0%{?fedora} > 16 || 0%{?rhel} > 6
%global security_parent_dir /%{_libdir}
%else
%global security_parent_dir /%{_lib}
%endif

Name:           pam_hbac
Version:	1.2
Release:	1%{?dist}
Summary:	A PAM module that evaluates HBAC rules stored on an IPA server

License:	GPLv3+
URL:		https://github.com/jhrozek/pam_hbac
Source0:	https://github.com/jhrozek/pam_hbac/archive/1.2.tar.gz

BuildRequires:	autoconf
BuildRequires:	automake
BuildRequires:	libtool
BuildRequires:	m4
BuildRequires:	pkgconfig

BuildRequires:	gettext-devel
BuildRequires:	pam-devel
BuildRequires:	openldap-devel
BuildRequires:	glib2-devel


%description
pam_hbac is a PAM module that can be used by PAM-aware applications to check
access control decisions on an IPA client machine. It is meant as a fall-back
for environments that can't use SSSD for some reason.


%prep
%setup -q


%build
autoreconf -if
%configure --libdir=/%{security_parent_dir} \
           --with-pammoddir=/%{security_parent_dir}/security \
           --disable-man-pages \
           ${null}

make %{?_smp_mflags}


%install
make install DESTDIR=$RPM_BUILD_ROOT
rm -f $RPM_BUILD_ROOT/%{security_parent_dir}/security/*.la


%files
%defattr(-,root,root,-)
%doc README* COPYING* ChangeLog NEWS
%{security_parent_dir}/security/pam_hbac.so
%dir %{_datadir}/doc/pam_hbac
%{_datadir}/doc/pam_hbac/COPYING
%{_datadir}/doc/pam_hbac/README.AIX
%{_datadir}/doc/pam_hbac/README.HPUX
%{_datadir}/doc/pam_hbac/README.FreeBSD
%{_datadir}/doc/pam_hbac/README.Solaris
%{_datadir}/doc/pam_hbac/README.RHEL-5
%{_datadir}/doc/pam_hbac/README.RHEL-6
%{_datadir}/doc/pam_hbac/README.md

%changelog
* Thu Feb 06 2026 pam_hbac maintainers - 1.2-2
- Rebuild for OpenLDAP 2.6.x on AIX 7.2/7.3
- Link libldap/liblber by full path (pinned to /opt/freeware/lib)
- Remove RHEL-5 workarounds and asciidoc requirement
- Disable man pages on AIX

* Thu Jan 11 2018 Jakub Hrozek <jakub.hrozek@posteo.se> - 1.2-1
- Package 1.2

* Thu May 26 2016 Jakub Hrozek <jakub.hrozek@posteo.se> - 1.0-1
- Package 1.0

* Sat Feb 27 2016 Jakub Hrozek <jakub.hrozek@posteo.se> - 0.1-1
- Initial upstream packaging
