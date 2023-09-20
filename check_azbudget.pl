#!/usr/bin/perl -w 
#===============================================================================
# Script Name   : check_azbudget.pl
# Usage Syntax  : check_azbudget.pl [-v] -t <TENANTID> -i <CLIENTID> -s <SUBID> -p <CLIENTSECRET>  [-f] [-b <BUDGET_NAME>] [-w <WARNING>] [-c <CRITICAL>]
# Author        : Start81 (DESMAREST JULIEN)
# Version       : 1.1.0
# Last Modified : 06/09/2023 
# Modified By   : Start81 (DESMAREST JULIEN)
# Description   : check azure budget 
# Depends On    : REST::Client, Data::Dumper, Getopt::Long, JSON, Readonly, Monitoring::Plugin 
#
# Changelog:
#    Legend:
#       [*] Informational, [!] Bugix, [+] Added, [-] Removed
#
# - 28/09/2021 | 1.0.0 | [*] initial realease
# - 07/02/2023 | 1.0.1 | [*] Reviewing
# - 30/06/2023 | 1.0.2 | [!] bug fix when forcast is empty
# - 06/09/2023 | 1.1.0 | [!] Rework script use Monitoring::Plugin
#===============================================================================

use Data::Dumper;
use JSON;
use Getopt::Long;
use warnings;
use File::Basename;
use REST::Client;
use strict;
use Readonly;
use Monitoring::Plugin;
Readonly our $VERSION => '1.1.0';

my $o_verb;
sub verb { my $t=shift; print $t,"\n" if ($o_verb) ; return 0}
my $me = basename($0);
my $np = Monitoring::Plugin->new(
    usage => "Usage: %s [-v] -T <TENANTID> -I <CLIENTID> -s <SUBID> -p <CLIENTSECRET> [-f] [-b <BUDGET_NAME>] [-w <WARNING>] [-c <CRITICAL>] \n",
    plugin => $me,
    shortname => " ",
    blurb => "$me is a Nagios check that uses Azure s REST API to get azure budget usage and forecast",
    version => $VERSION,
    timeout => 30
);
#write content in a file
sub write_file {
    my ($content,$tmp_file_name) = @_;
    my $fd;
    verb("write $tmp_file_name");
    if (open($fd, '>', $tmp_file_name)) {
            print $fd $content;
            close($fd);       
    } else {
        my $msg ="UNKNOWN unable to write file $tmp_file_name";
        $np->plugin_exit('UNKNOWN',$msg);
    }
    
    return 0
}

#Read previous token  
sub read_token_file {
    my ($tmp_file_name) = @_;
    my $fd;
    my $token ="";
    verb("read $tmp_file_name");
    if (open($fd, '<', $tmp_file_name)) {
        while (my $row = <$fd>) {
            chomp $row;
            $token=$token . $row;
        }
        close($fd);
    } else {
        my $msg ="unable to read $tmp_file_name";
        $np->plugin_exit('UNKNOWN',$msg);
    }
    return $token
    
}

#get a new acces token
sub get_access_token{
    my ($clientid,$clientsecret,$tenantid) = @_;
    verb(" tenantid = " . $tenantid);
    verb(" clientid = " . $clientid);
    verb(" clientsecret = " . $clientsecret);
    #Get token
    my $client = REST::Client->new();
    my $payload = 'grant_type=client_credentials&client_id=' . $clientid . '&client_secret=' . $clientsecret . '&resource=https%3A//management.azure.com/';
    my $url = "https://login.microsoftonline.com/" . $tenantid . "/oauth2/token";
    $client->POST($url,$payload);
    if ($client->responseCode() ne '200') {
        my $msg = "UNKNOWN response code : " . $client->responseCode() . " Message : Error when getting token" . $client->{_res}->decoded_content;
        $np->plugin_exit('UNKNOWN',$msg);
    }
    return $client->{_res}->decoded_content;
}

$np->add_arg(
    spec => 'tenant|T=s',
    help => "-T, --tenant=STRING\n"
          . ' The GUID of the tenant to be checked',
    required => 1
);
$np->add_arg(
    spec => 'clientid|I=s',
    help => "-I, --clientid=STRING\n"
          . ' The GUID of the registered application',
    required => 1
);
$np->add_arg(
    spec => 'clientsecret|p=s',
    help => "-p, --clientsecret=STRING\n"
          . ' Access Key of registered application',
    required => 1
);
$np->add_arg(
    spec => 'subscriptionid|s=s',
    help => "-s, --subscriptionid=STRING\n"
          . ' Subscription GUID ',
    required => 1
);
$np->add_arg(
    spec => 'forecast|f',
    help => "-f, --forecast\n"  
         . ' check forecast budget default currentSpend',
    required => 0
);
$np->add_arg(
    spec => 'budgetname|b=s', 
    help => "-b, --budgetname=STRING\n"  
         . ' name of the budget to check',
    required => 0
);
$np->add_arg(
    spec => 'warning|w=s',
    help => "-w, --warning=threshold\n" 
          . '   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.',
);
$np->add_arg(
    spec => 'critical|c=s',
    help => "-c, --critical=threshold\n"  
          . '   See https://www.monitoring-plugins.org/doc/guidelines.html#THRESHOLDFORMAT for the threshold format.',
);
$np->getopts;

my $subid = $np->opts->subscriptionid;
my $tenantid = $np->opts->tenant;
my $clientid = $np->opts->clientid;
my $clientsecret = $np->opts->clientsecret; 
my $o_warning = $np->opts->warning;
my $o_critical = $np->opts->critical;
my $o_budget_name = $np->opts->budgetname;
my $o_forecast = $np->opts->forecast if (defined $np->opts->forecast);
$o_verb = $np->opts->verbose if (defined $np->opts->verbose);
my $o_timeout = $np->opts->timeout;
if ($o_timeout > 60){
    $np->plugin_die("Invalid time-out");
}
verb(" subid = ".$subid);
verb(" tenantid = ". $tenantid);
verb(" clientid = ". $clientid);
verb(" clientsecret = ". $clientsecret);
#Get token
my $tmp_file = "/tmp/$clientid.tmp";
my $token;
my $token_json;
if (-e $tmp_file) {
    #Read previous token
    $token = read_token_file ($tmp_file);
    $token_json = from_json($token);
    #check token expiration
    my $expiration = $token_json->{'expires_on'} - 60;
    my $current_time = time();
    if ($current_time > $expiration ) {
        #get a new token
        $token = get_access_token($clientid,$clientsecret,$tenantid);
        write_file($token,$tmp_file);
        $token_json = from_json($token);
    }
} else {
        $token = get_access_token($clientid,$clientsecret,$tenantid);
        write_file($token,$tmp_file);
        $token_json = from_json($token);
}
$token = $token_json->{'access_token'};

verb("Authorization :" .$token);
#get budget list
my $response_json; 
my $client = REST::Client->new();
$client->addHeader('Authorization', 'Bearer '. $token);
$client->addHeader('Content-Type', 'application/json;charset=utf8');
$client->addHeader('Accept', 'application/json');
my $url = "https://management.azure.com/subscriptions/$subid/providers/Microsoft.Consumption/budgets?api-version=2019-10-01";
$client->GET($url);
if($client->responseCode() ne '200'){
    my $msg ="UNKNOWN response code : " . $client->responseCode() . " Message : Error when getting budget " . $client->responseContent ();
    $np->plugin_exit('UNKNOWN',$msg);
}
$response_json = from_json($client->responseContent ());
verb(Dumper($response_json));
my $i = 0;

my $name;
my $amount_spend;
my $amount;
my $msg = "";
my $name_of_check;
my $status;

my $budget_founded = 0;

my @budgets_list;
my @criticals = ();
my @warnings = ();
my @unknown = ();
my @ok = ();
my $result;
#reading response
while (exists ($response_json->{'value'}->[$i])){
    verb(Dumper($response_json->{'value'}->[$i]));
    $name = $response_json->{'value'}->[$i]->{'name'};
    if ((!$o_budget_name) or ($name eq  $o_budget_name)  ){
        $budget_founded = 1;
        if (defined ($o_forecast)){
            $amount_spend =  $response_json->{'value'}->[$i]->{'properties'}->{'currentSpend'}->{'amount'} ;
            if (exists($response_json->{'value'}->[$i]->{'properties'}->{'forecastSpend'}->{'amount'})) {
                $amount_spend = $response_json->{'value'}->[$i]->{'properties'}->{'forecastSpend'}->{'amount'} ;
                $name_of_check = "forecast usage"; 
            }else{
                $name_of_check = "usage (no forecast available)"; 
            }
        } else {
            $amount_spend = $response_json->{'value'}->[$i]->{'properties'}->{'currentSpend'}->{'amount'};
            $name_of_check = "usage";
        }
        $amount = $response_json->{'value'}->[$i]->{'properties'}->{'amount'};
        if ($amount == 0 ) {
            push (@unknown,"budget $name amount is zero");
        } else {
            $result = ($amount_spend*100)/(($amount));
            $msg =" budget " . $name . " " . $name_of_check . " " . substr($result,0,5) . " % ";
            $np->add_perfdata(label => $name . "_usage", value => substr($result,0,5), uom => '%', warning => $o_warning, critical => $o_critical);
            if ((defined($o_warning) || defined($o_critical))) {
                $np->set_thresholds(warning => $o_warning, critical => $o_critical);
                $status = $np->check_threshold($result);
                push( @criticals, $msg) if ($status==2);
                push( @warnings, $msg) if ($status==1);
                push (@ok,$msg) if ($status==0);
            } else {
                push (@ok,$msg);
            }
            
        }

        
        
    }else {
         push(@budgets_list,$name);
    }
    
    $i++;
     
}
if ($budget_founded == 0){
    $msg = " budget " . $o_budget_name. " not found in subscription " . $subid . " available budget(s) is(are) : " . join(", ", @budgets_list);
    $np->plugin_exit('UNKNOWN',$msg);
}
$np->plugin_exit('CRITICAL', join(', ', @criticals)) if (scalar @criticals > 0);
$np->plugin_exit('WARNING', join(', ', @warnings)) if (scalar @warnings > 0);
$np->plugin_exit('UNKNOWN', join(', ', @unknown)) if (scalar @unknown > 0);

$np->plugin_exit('OK', join(', ', @ok));