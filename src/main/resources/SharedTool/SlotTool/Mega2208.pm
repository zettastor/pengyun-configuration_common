package Mega2208;
use strict;
use warnings FATAL => 'all';
use FindBin '$RealBin';
use lib "$RealBin";
use Common;
use Class::DevInfo;
use MegaCommon;

use constant CARD_TYPE_MEGA => "CardTypeMega2208";

use constant MEGA_TOOL_PATH_CONFIG_NAME => "mega2208.tool.path";
use constant MEGA_TOOL_PATH_DEFAULT => "/opt/MegaRAID/MegaCli/MegaCli64";

use constant LSPCI_PATTERN_CONFIG_NAME => "mega2208.raid.pattern";
use constant LSPCI_PATTERN_DEFAULT => "LSI.*MegaRAID.*SAS*2208";

use constant CARD_NAME => "Mega2208";

my $megaToolPath = Common::getConfigItem(MEGA_TOOL_PATH_CONFIG_NAME);
$megaToolPath = MEGA_TOOL_PATH_DEFAULT if !(defined $megaToolPath);

my $lspciPattern = Common::getConfigItem(LSPCI_PATTERN_CONFIG_NAME);
$lspciPattern = LSPCI_PATTERN_DEFAULT if !(defined $lspciPattern);

sub isCardTypeBelongToThisCard {
    my ($self, $cardType) = @_;
    return isMega2208CardType($cardType);
}

#/opt/MegaRAID/MegaCli/MegaCli64 -pdlocate -start -physdrv[32:6] -a0
sub lightOn {
    my ($self, $devInfo) = @_;
    return lightControl($devInfo, "start");
}

#/opt/MegaRAID/MegaCli/MegaCli64 -pdlocate -stop -physdrv[32:6] -a0
sub lightOff {
    my ($self, $devInfo) = @_;
    return lightControl($devInfo, "stop");
}

# return: devInfo array
sub getDevInfosByDevName {
    my ($self, $devName) = @_;

    #we need tool to detect
    if (!hasMega2208Card()) {
        return ();
    }

    my $devInfo = MegaCommon::queryDevInfoByDevNameThroughWwn($devName, $megaToolPath, CARD_TYPE_MEGA);
    if (Class::DevInfo::hasControllerId($devInfo)) {
        return ($devInfo);
    }

    my @devInfos = MegaCommon::queryDevInfoByDevNameThroughPath($devName, $megaToolPath, CARD_TYPE_MEGA);

    return @devInfos;
}

sub isMega2208CardType {
    my ($cardType) = @_;
    return ($cardType eq CARD_TYPE_MEGA);
}

sub hasMega2208Card {
    #lspci -nn | grep -i -E "lsi.*megaraid.*sas\s*2208"
    #>03:00.0 RAID bus controller [0104]: LSI Logic / Symbios Logic MegaRAID SAS 2208 [Thunderbolt] [1000:005b] (rev 05)

    my $cardName = CARD_NAME;
    return Common::hasCardAndCmdToolByLspciPattern($cardName, $lspciPattern, $megaToolPath);
}

#/opt/MegaRAID/MegaCli/MegaCli64 -PdLocate {[-start] | -stop} -physdrv[E0:S0,E1:S1,...] -aN|-a0,1,2|-aALL
#/opt/MegaRAID/MegaCli/MegaCli64 -pdlocate -start -physdrv[32:6] -a0
sub lightControl {
    my ($devInfo, $action) = @_;

    Common::myDebugLog("Light $action device:".Class::DevInfo::toJson($devInfo));
    my $cardType = Class::DevInfo::getCardType($devInfo);
    if (!isMega2208CardType($cardType)) {
        Common::myErrorLog("Light $action failed. Device:".Class::DevInfo::toJson($devInfo)
            ."is not Mega2208 card");
        return 0;
    }

    my $controllerId = Class::DevInfo::getControllerId($devInfo);
    my $slotNumber = Class::DevInfo::getSlotNumber($devInfo);
    my $enclosureId = Class::DevInfo::getEnclosureId($devInfo);

    my $cmd = $megaToolPath." -pdlocate -$action -physdrv[$enclosureId:$slotNumber] -a$controllerId";
    Common::myDebugLog("Light $action device. Cmd:[$cmd]");

    my $cmdRetMsg = qx($cmd);
    my $cmdRetCode = $?;
    Common::myDebugLog("Light $action device. Cmd:[$cmd] RetMsg:[$cmdRetMsg]");

    if ($cmdRetCode == 0) {
        Common::myDebugLog("Light $action device success.");
        return 1;
    } else {
        Common::myDebugLog("Light $action device failed.");
        return 0;
    }
}

1;
