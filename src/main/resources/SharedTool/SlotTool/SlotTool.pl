#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Getopt::Long;
use Pod::Usage;
use Module::Load;
use FindBin '$RealBin';
use lib "$RealBin";
use Common;
use Class::DevInfo;

use constant RAID_CARD_TYPE_MODULES_CONFIG => "card.type.modules";

my $lightOnDevName = "";
my $lightOffDevName = "";
my $queryDevName = "";
my $debugFlag = "";
my $help = "";
my $testFlag = "";

GetOptions (
    "light_on=s" => \$lightOnDevName,
    "light_off=s" => \$lightOffDevName,
    "query_disk=s" => \$queryDevName,
    "debug" => \$debugFlag,
    "test" => \$testFlag,
    "help|h" => \$help,
);

pod2usage(0) if $help;

if ($debugFlag) {
    Common::enableDebugMode();
    Common::myDebugLog("Enable debug mode");
}

my @modules = Common::getArrayConfigItemSeparateByComma(RAID_CARD_TYPE_MODULES_CONFIG);
#my @modules = ("MegaRaid", "Sas2308");
foreach my $module (@modules) {
    Common::myDebugLog("Load module:[$module]");
    Module::Load::load($module);
}

if ($lightOnDevName || $lightOffDevName) {
    my $devName = $lightOnDevName ? $lightOnDevName : $lightOffDevName;

    Common::myDebugLog("light operaton to disk:$devName");
    my @devInfos = getDevInfosByDevName($devName);
    Common::myDebugLog("light operaton devinfo[@devInfos], size : ".scalar @devInfos);
    if (scalar @devInfos <= 0) {
        Common::myErrorLog("Can't get device info for $devName");
        Common::printJsonRetMsg(Common->FAILED_RET_CODE, "Can't get device info.");
        exit(Common->FAILED_RET_CODE);
    }

    if ($lightOnDevName) {
        lightOn(@devInfos);
    } else {
        lightOff(@devInfos);
    }
} elsif ($queryDevName) {
    my @devInfos = queryDisks($queryDevName);
    Common::printJsonRetDevInfos(@devInfos);
} elsif ($testFlag) {
} else {
    pod2usage(0);
}

exit 0;

sub queryDisks {
    my ($devNameParam) = @_;
    Common::myDebugLog("Query disk:[$devNameParam].");

    my @devNames = ();
    if ($devNameParam eq Common->QUERY_DISK_ALL) {
        @devNames = Common::getAllDevNamesInSystem();
    } else {
        push(@devNames, $devNameParam);
    }

    if (scalar @devNames <= 0) {
        Common::myErrorLog("Can't get device name");
        return ();
    }

    my @devInfos = ();
    foreach my $devName (@devNames) {
        #get the info one by one
        my @currentDevInfos = getDevInfosByDevName($devName);
        if (scalar @currentDevInfos > 0) {
            push(@devInfos, @currentDevInfos);
            next;
        }

        Common::myDebugLog("device:[$devName] is system disk.");

        # can't get devInfo from raid card, this system disk, just report simple info
        my $wwn = Common::getWwnByDevName($devName);
        if ($wwn) {
            my $devInfo = Class::DevInfo::newWithAllField($devName, $wwn, undef, undef, undef, undef);
            Common::myDebugLog("Query info for system disk:[".Class::DevInfo::toJson($devInfo)."]");
            push(@devInfos, $devInfo);
        } else {
            Common::myErrorLog("Can't query info for system disk:[$devName].");
        }
    }

    return @devInfos;
}

sub getDevInfosByDevName {
    my ($devName) = @_;

    my @devInfos = ();

    foreach my $module (@modules) {
        @devInfos = $module->getDevInfosByDevName($devName);
        if (scalar @devInfos > 0) {
            return @devInfos;
        }
    }
    Common::myDebugLog("can't get devInfo for disk:[$devName].");
    return ();
}

sub lightOn {
    my (@devInfos) = @_;

    my $retMsg = "";
    my $retCode = 1;

    foreach my $devInfo (@devInfos) {
        my $currentRetCode = undef;
        my $devName = Class::DevInfo::getDevName($devInfo);
        my $devType = Class::DevInfo::getCardType($devInfo);
        my $wwn = Class::DevInfo::getWwn($devInfo);

        foreach my $module (@modules) {
            if ($module->isCardTypeBelongToThisCard($devType)) {
                $currentRetCode = $module->lightOn($devInfo);
                last;
            }
        }

        if ($currentRetCode) {
            #Combine the string content, ude .=
            $retMsg .= "Light on device:[$devName] wwn:[$wwn] success. ";
        } else {
            $retMsg .= "Light on device:[$devName] wwn:[$wwn] failed. ";
            $retCode = 0;
        }
    }

    if ($retCode) {
        Common::printJsonRetMsg(Common->SUCCESS_RET_CODE, $retMsg);
        exit(Common->SUCCESS_RET_CODE);
    } else {
        Common::printJsonRetMsg(Common->FAILED_RET_CODE, $retMsg);
        exit(Common->FAILED_RET_CODE);
    }
}

sub lightOff {
    my (@devInfos) = @_;

    my $retMsg = "";
    my $retCode = 1;

    foreach my $devInfo (@devInfos) {
        my $currentRetCode = undef;
        my $devName = Class::DevInfo::getDevName($devInfo);
        my $devType = Class::DevInfo::getCardType($devInfo);
        my $wwn = Class::DevInfo::getWwn($devInfo);

        foreach my $module (@modules) {
            if ($module->isCardTypeBelongToThisCard($devType)) {
                $currentRetCode = $module->lightOff($devInfo);
                last;
            }
        }

        if ($currentRetCode) {
            $retMsg .= "Light off device:[$devName] wwn:[$wwn] success. ";
        } else {
            $retMsg .= "Light off device:[$devName] wwn:[$wwn] failed. ";
            $retCode = 0;
        }
    }

    if ($retCode) {
        Common::printJsonRetMsg(Common->SUCCESS_RET_CODE, $retMsg);
        exit(Common->SUCCESS_RET_CODE);
    } else {
        Common::printJsonRetMsg(Common->FAILED_RET_CODE, $retMsg);
        exit(Common->FAILED_RET_CODE);
    }
}


__END__
=head1 NAME
slot tool - tool to manage raid card

=head1 SYNOPSIS

sample [options] [device name ...]

 Options:
   --light_on devName   light on device light
   --light_off devName  light off device light
   --query_disk devName query device info, with all will query all devices
   --debug              print debug info to stdout
   --help               brief help message

=head1 OPTIONS

=over 8

=item B<--light_on>

Light on device physical light. Need specific device name.

=item B<--light_off>

Light off device physical light. Need specific device name.

=item B<--query_disk>

Query disk infos. Include ControllerId EnclusureId SlotId DevName and so on. Need specific device name or all means all device.

=item B<--debug>

print debug info to stdout.

=item B<--help>

Print a brief help message and exists.

=back

=head1 DESCRIPTION

B<This program> manage raid card

=cut
