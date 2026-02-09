%if 0%{?fedora} > 16 || 0%{?rhel} > 6
%global security_parent_dir %{_libdir}
%else
# AIX: PAM modules live in /usr/lib/security
%global security_parent_dir /usr/lib
%endif

Name:           pam_hbac
Version:	1.2
Release:	5.0
Summary:	A PAM module that evaluates HBAC rules stored on an IPA server

License:	GPLv3+
URL:		https://github.com/jhrozek/pam_hbac
Source0:	%{name}-%{version}.tar.gz

BuildRequires:	autoconf
BuildRequires:	automake
BuildRequires:	libtool
BuildRequires:	m4
BuildRequires:	pkgconfig

BuildRequires:	gettext-devel
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
./configure --sysconfdir=/etc/security/ldap \
            --with-pammoddir=%{security_parent_dir}/security \
            --disable-man-pages

make %{?_smp_mflags}


%install
mkdir -p $RPM_BUILD_ROOT%{security_parent_dir}/security
# Install the .so directly from libtool's build dir — the .a produced
# by "make install" on AIX is not a proper standalone loadable module
cp src/.libs/pam_hbac.so $RPM_BUILD_ROOT%{security_parent_dir}/security/pam_hbac.so
chmod 755 $RPM_BUILD_ROOT%{security_parent_dir}/security/pam_hbac.so


%files
%defattr(-,root,root,-)
%doc README* COPYING* ChangeLog NEWS
%{security_parent_dir}/security/pam_hbac.so

%changelog
* Fri Feb 06 2026 pam_hbac maintainers - 1.2-5.0
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
