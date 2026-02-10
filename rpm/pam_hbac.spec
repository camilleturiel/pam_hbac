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

# AIX: openssl/libcrypto live inside .a archives, not as standalone .so
# RPM's auto-dependency scanner finds .so references that no RPM provides
AutoReq:	no

BuildRequires:	autoconf
BuildRequires:	automake
BuildRequires:	libtool
BuildRequires:	m4
BuildRequires:	pkgconfig

BuildRequires:	gettext-devel
BuildRequires:	openldap-devel >= 2.6.9
BuildRequires:	glib2-devel

Requires:	openldap >= 2.6.9


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
make install DESTDIR=$RPM_BUILD_ROOT
rm -f $RPM_BUILD_ROOT%{security_parent_dir}/security/*.la
# AIX libtool installs as .a — extract the .so member
cd $RPM_BUILD_ROOT%{security_parent_dir}/security
ar -x pam_hbac.a
rm -f pam_hbac.a
# Member may be pam_hbac.so.0 — rename to pam_hbac.so
if [ -f pam_hbac.so.0 ] && [ ! -f pam_hbac.so ]; then
    mv pam_hbac.so.0 pam_hbac.so
fi
chmod 755 pam_hbac.so
# Install pam_test_client (built by make but not installed by make install)
cd /opt/freeware/src/packages/BUILD/%{name}-%{version}
mkdir -p $RPM_BUILD_ROOT/opt/freeware/bin
cp pam_test_client $RPM_BUILD_ROOT/opt/freeware/bin/pam_test_client
chmod 755 $RPM_BUILD_ROOT/opt/freeware/bin/pam_test_client


%files
%defattr(-,root,root,-)
%doc README* COPYING* ChangeLog NEWS
%{security_parent_dir}/security/pam_hbac.so
/opt/freeware/bin/pam_test_client

%post
# AIX: ensure LIBPATH includes /opt/freeware/lib for pam_hbac runtime deps
if [ "$(uname -s)" = "AIX" ]; then
    LIBPATH_LINE="LIBPATH=/opt/freeware/lib:/usr/lib"
    if [ -f /etc/environment ]; then
        if ! grep -q "^LIBPATH=.*\/opt\/freeware\/lib" /etc/environment; then
            echo "$LIBPATH_LINE" >> /etc/environment
            # Restart sshd to pick up new LIBPATH
            stopsrc -s sshd && startsrc -s sshd
        fi
    fi
fi

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
