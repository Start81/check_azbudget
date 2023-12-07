# check_azbudget
check budget usage in azure

### prerequisites

This script uses theses libs : REST::Client, Data::Dumper, JSON, Readonly, Monitoring::Plugin, File::Basename

to install them type :

```
sudo cpan REST::Client Data::Dumper JSON Readonly Monitoring::Plugin File::Basename
```
## Use case 
```bash
check_azbudget.pl 1.1.0

This nagios plugin is free software, and comes with ABSOLUTELY NO WARRANTY.
It may be used, redistributed and/or modified under the terms of the GNU
General Public Licence (see http://www.fsf.org/licensing/licenses/gpl.txt).

check_azbudget.pl is a Nagios check that uses Azure s REST API to get azure budget usage and forecast

Usage: check_azbudget.pl [-v] -T <TENANTID> -I <CLIENTID> -s <SUBID> -p <CLIENTSECRET> [-f] [-b <BUDGET_NAME>] [-w <WARNING>] [-c <CRITICAL>]

 -?, --usage
   Print usage information
 -h, --help
   Print detailed help screen
 -V, --version
   Print version information
 --extra-opts=[section][@file]
   Read options from an ini file. See https://www.monitoring-plugins.org/doc/extra-opts.html
   for usage and examples.
 -T, --tenant=STRING
 The GUID of the tenant to be checked
 -I, --clientid=STRING
 The GUID of the registered application
 -p, --clientsecret=STRING
 Access Key of registered application
 -s, --subscriptionid=STRING
 Subscription GUID
 -f, --forecast
 check forecast budget default currentSpend
 -b, --budgetname=STRING
 name of the budget to check
 -w, --warning=threshold
   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.
 -c, --critical=threshold
   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.
 -t, --timeout=INTEGER
   Seconds before plugin times out (default: 30)
 -v, --verbose
   Show details for command-line debugging (can repeat up to 3 times)
```

sample to get cpu usage:

```bash
check_azure_mdb.pl --tenantid=<TENANTID> --clientid=<CLIENTID> --subid=<SUBID> --clientsecret=<CLIENTSECRET> --budgetname=ComputeVM 
```

you may get  :

```bash
OK -  budget ComputeVM usage 44.11 %  | ComputeVM_usage=44.11%;;
```
