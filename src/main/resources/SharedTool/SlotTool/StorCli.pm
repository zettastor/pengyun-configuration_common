package StorCli;
use strict;
use warnings FATAL => 'all';
use FindBin '$RealBin';
use bignum qw(hex);
use lib "$RealBin";
use Common;
use Class::DevInfo;

use constant CARD_TYPE_SAS3108 => "CardTypeSas3108";
use constant TOOL_PATH_CONFIG_NAME => "storcli.tool.path";
use constant TOOL_PATH_DEFAULT => "/opt/MegaRAID/storcli/storcli64";
use constant LSPCI_PATTERN_CONFIG_NAME => "storcli.raid.pattern";
use constant LSPCI_PATTERN_DEFAULT => "MegaRAID\\s*SAS-3\\s*3108";
use constant CARD_NAME => "SAS3108";

my $toolPath = Common::getConfigItem(TOOL_PATH_CONFIG_NAME);
$toolPath = TOOL_PATH_DEFAULT if !(defined $toolPath);

my $lspciPattern = Common::getConfigItem(LSPCI_PATTERN_CONFIG_NAME);
$lspciPattern = LSPCI_PATTERN_DEFAULT if !(defined $lspciPattern);

# read raid info once, so we don't need to read too many times
my @raidAllInfos = readRaidAllInfos();

sub isCardTypeBelongToThisCard {
    my ($self, $cardType) = @_;
    return isCardTypeMatch($cardType);
}

#/opt/MegaRAID/storcli/storcli64 /cx/ex/sx start locate
sub lightOn {
    my ($self, $devInfo) = @_;
    return lightControl($devInfo, "start");
}

#/opt/MegaRAID/storcli/storcli64 /cx/ex/sx stop locate
sub lightOff {
    my ($self, $devInfo) = @_;
    return lightControl($devInfo, "stop");
}

# return: devInfo array
sub getDevInfosByDevName {
    my ($self, $devName) = @_;

    if (!hasThisRaidCard()) {
        return ();
    }

    my $devInfo = queryDevInfoByDevNameThroughWwn($devName);
    if (Class::DevInfo::hasControllerId($devInfo)) {
        return ($devInfo);
    }

    return ();
}

sub queryDevInfoByDevNameThroughWwn {
    my ($devName) = @_;

    my $wwn = Common::getWwnByDevName($devName);
    if (!($wwn)) {
        Common::myErrorLog("Get WWN for $devName failed.");
        return Class::DevInfo::newEmpty();
    }

    my $devInfo = queryDevInfoByWwnFromCard($wwn);
    if (Class::DevInfo::hasControllerId($devInfo)) {
        Class::DevInfo::setDevName($devInfo, $devName);
        return ($devInfo);
    }

    return Class::DevInfo::newEmpty();
}

sub queryDevInfoByWwnFromCard {
    # /opt/MegaRAID/storcli/storcli64 /call/eall/sall show all
    #>Drive /c0/e22/s0 Device attributes :
    #>==================================
    #>SN = 27F0A00VF4ND
    #>WWN = 500003979832EEA8

    my ($wwnQueryed) = @_;
    Common::myDebugLog("Query device info by wwn:[$wwnQueryed] from card");

    ## we meet wwn got by udevadm is different from got by raid command.
    my @wwnAdapterList = Common::wwnAdapter($wwnQueryed);

    my $controllerId = undef;
    my $enclosureId = undef;
    my $slotNumber = undef;
    my $serialNumber = undef;
    my $diskType = undef;
    foreach my $line (@raidAllInfos) {
        chomp($line);
        if ($line =~/\s*Drive\s*\/c(\d+)\/e(\d+)\/s(\d+)\s*Device\s*attributes\s*:/) {
            Common::myDebugLog("Find one slot:[$line]");
            $controllerId = $1;
            $enclosureId = $2;
            $slotNumber = $3;
        } elsif ($line =~ /\s*SN\s*=\s*([0-a-zA-Z]*)/) {
            $serialNumber = $1;
        } elsif ($line =~ /.*\s?(HDD|SDD)\s?.*/i) {
            $diskType = $1;
        } elsif ($line =~ /\s*WWN\s*=\s*([\da-fA-F]+)/) {
            my $wwn = undef;
            foreach my $element (@wwnAdapterList) {
                if ($line =~ /\s*WWN\s*=\s*$element/i){
                    $wwn = $element;
                    Common::myDebugLog("Find adapter info for WWN:[$wwnQueryed] success. new wwn number:$wwn");
                    last;
                }
            }

            if (defined $wwn
                && defined $controllerId
                && defined $enclosureId
                && defined $slotNumber) {
                Common::myDebugLog("Find card info for WWN:[$wwnQueryed] success."
                    ."ControllerId:[$controllerId] Slot Number:[$slotNumber] Enclosure position:[$enclosureId].");

                if (undef $serialNumber) {
                    $serialNumber = undef;
                }

                if (undef $diskType) {
                    $diskType = undef;
                }

                return Class::DevInfo::newByWwnAdapterSlotEnclosureCardType($wwn, $controllerId, $slotNumber, $enclosureId, CARD_TYPE_SAS3108, $serialNumber, $diskType);
            } else {
                $controllerId = undef;
                $enclosureId = undef;
                $slotNumber = undef;
                $serialNumber = undef;
                $diskType = undef;
            }
        }
    }

    return Class::DevInfo::newEmpty();
}

sub equalWwn {
    my ($wwnInSystem, $wwnFromCard) = @_;
    Common::myDebugLog("Compare wwn: from system:[$wwnInSystem] from card:[$wwnFromCard]");

    if ($wwnInSystem =~ /$wwnFromCard/i
        || hex($wwnInSystem) == hex($wwnFromCard)) {
        Common::myDebugLog("Compare wwn: from system:[$wwnInSystem] from card:[$wwnFromCard] is equal.");
        return 1;
    }

    if (hex($wwnInSystem) == hex($wwnFromCard) + 1) {
        Common::myDebugLog("Compare wwn: from system:[$wwnInSystem] from card:[$wwnFromCard] might equal.");
        return 1;
    } else {
        Common::myDebugLog("Compare wwn: from system:[$wwnInSystem] from card:[$wwnFromCard] not equal.");
        return 0;
    }
}

sub hasThisRaidCard {
    #>01:00.0 RAID bus controller: LSI Logic / Symbios Logic MegaRAID SAS-3 3108 [Invader] (rev 02)

    my $cardName = CARD_NAME;
    return Common::hasCardAndCmdToolByLspciPattern($cardName, $lspciPattern, $toolPath);
}

# /opt/MegaRAID/storcli/storcli64 /call/eall/sall show all
sub readRaidAllInfos {
    if (!hasThisRaidCard()) {
        Common::myDebugLog("Don't have ".CARD_NAME." raid card. Can't init raid infos.");
        return ();
    }

    Common::myDebugLog("Init raid infos for ".CARD_NAME." at begining.");
    my $cmd = $toolPath." /call/eall/sall show all";
    my ($retCode, @lines) = Common::execCmd($cmd);
    return @lines;
}

sub isCardTypeMatch {
    my ($cardType) = @_;
    return ($cardType eq CARD_TYPE_SAS3108);
}

#/opt/MegaRAID/storcli/storcli64 /cx/ex/sx start|stop locate
sub lightControl {
    my ($devInfo, $action) = @_;

    Common::myDebugLog("Light $action device:".Class::DevInfo::toJson($devInfo));
    my $cardType = Class::DevInfo::getCardType($devInfo);
    if (!isCardTypeMatch($cardType)) {
        Common::myErrorLog("Light $action failed. Device:".Class::DevInfo::toJson($devInfo)."is not ".CARD_NAME." card");
        return 0;
    }

    my $controllerId = Class::DevInfo::getControllerId($devInfo);
    my $slotNumber = Class::DevInfo::getSlotNumber($devInfo);
    my $enclosureId = Class::DevInfo::getEnclosureId($devInfo);

    my $cmd = $toolPath." /c$controllerId/e$enclosureId/s$slotNumber $action locate";
    my ($retCode, @retLines) = Common::execCmd($cmd);

    if ($retCode == 0) {
        Common::myDebugLog("Light $action device success.");
        return 1;
    } else {
        Common::myDebugLog("Light $action device failed.");
        return 0;
    }
}

1;
