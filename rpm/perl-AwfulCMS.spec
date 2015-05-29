%define _name AwfulCMS
Name: perl-%{_name}
Version: 0.1.3
Release: 1
Summary: An awful CMS
Group: Development/Libraries
License: Artistic-1.0 or GPL-1.0+
Source0: %{_name}-%{version}.tar.gz
URL: http://bwachter.lart.info/awfulcms/
BuildArch: noarch
BuildRequires: perl
BuildRequires: perl-macros
BuildRequires: perl(Module::Build)
BuildRequires: perl(Test::More)
# TODO: autogenerate those from the manifest
%define awfulcms_requires perl(CGI) perl(Date::Format) perl(File::Path) perl(File::Temp) perl(File::Type) perl(GD) perl(Pod::Simple::HTML) perl(Sys::Hostname) perl(Time::HiRes) perl(URI::Escape) perl(Text::Markdown) perl(Tie::RegexpHash)
BuildRequires: %{awfulcms_requires}
# Recommendations:
# included to make sure testcases pass
%define awfulcms_recommends perl(DBI) perl(LWP::UserAgent) perl(Image::ExifTool) perl(HTML::LinkExtor) perl(HTML::FormatText::WithLinks::AndTables) perl(Net::Trackback::Client) perl(Net::Trackback::Ping) perl(XML::Atom)
BuildRequires: %{awfulcms_recommends}
Requires: %{awfulcms_requires} perl(XML::RSS)
Recommends: %{awfulcms_recommends}

%{perl_requires}

%description
%{summary}.

%files
%defattr(-,root,root,-)
%dir %{perl_vendorlib}/%{_name}
%{perl_vendorlib}/%{_name}/*.pm
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
%perl_process_packlist


#check
#./Build test
