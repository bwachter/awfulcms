%define _name AwfulCMS
Name: perl-%{_name}
Version: 0.1
Release: 1
Summary: An awful CMS
Group: Development/Libraries
License: Artistic or GPL
Source0: %{_name}-%{version}.tar.gz
URL: http://bwachter.lart.info/awfulcms/
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}
BuildArch: noarch
BuildRequires: perl(Module::Build)
BuildRequires: perl(Test::More)
BuildRequires: perl(URI::Escape)
BuildRequires: perl(File::Type)
BuildRequires: perl(Time::HiRes)
BuildRequires: perl(Date::Format)
BuildRequires: perl(File::Path)
BuildRequires: perl(GD)
BuildRequires: perl(CGI)
BuildRequires: perl(Pod::Simple::HTML)
Requires: perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))

%description
%{summary}.

%files
%defattr(-,root,root,-)
%{perl_vendorlib}/AwfulCMS/*.pm
%doc %{_mandir}/man3/*.3pm*


%package tools
Summary: Command line tools for AwfulCMS
Group: Development/Libraries
Requires: %{name} = %{version}-%{release}

%description tools
%{summary}.

%files tools
%defattr(-,root,root,-)
%{_bindir}/*
%doc %{_mandir}/man1/*.pl.1.*


%prep
%setup -q -n %{_name}-%{version}

%build
%{__perl} Build.PL --installdirs vendor
./Build


%install
./Build install --installdirs vendor  --destdir %{buildroot}
find %{buildroot} -type f -name .bs -exec rm -f {} ';'
find %{buildroot} -type f -name .packlist -exec rm -f {} ';'


%check
./Build test
