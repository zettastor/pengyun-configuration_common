package Sas2208;
use strict;
use warnings FATAL => 'all';
use FindBin '$RealBin';
use lib "$RealBin";
use Common;
use Class::DevInfo;
use SasCommon;

use constant CARD_TYPE_SAS => "CardTypeSas2208";

use constant SAS2IRCU_TOOL_PATH_CONFIG_NAME => "sas2ircu.tool.path";
use constant SAS2IRCU_TOOL_PATH_DEFAULT => "/opt/sas2208tool/sas2ircu";

use constant LSPCI_PATTERN_CONFIG_NAME => "sas2ircu.raid.pattern";
use constant LSPCI_PATTERN_DEFAULT => "LSI.+SAS 2208";

use constant CARD_NAME => "Sas2208";

my $sas2ircuToolPath = Common::getConfigItem(SAS2IRCU_TOOL_PATH_CONFIG_NAME);
$sas2ircuToolPath = SAS2IRCU_TOOL_PATH_DEFAULT if !(defined $sas2ircuToolPath);

my $lspciPattern = Common::getConfigItem(LSPCI_PATTERN_CONFIG_NAME);
$lspciPattern = LSPCI_PATTERN_DEFAULT if !(defined $lspciPattern);

sub isCardTypeBelongToThisCard {
    my ($self, $cardType) = @_;
    return isSas2208CardType($cardType);
}

#/root/sas2ircu 0 locate 1:6 on
sub lightOn {
    my ($self, $devInfo) = @_;
    return lightControl($devInfo, "on");
}

#/root/sas2ircu 0 locate 1:6 off
sub lightOff {
    my ($self, $devInfo) = @_;
    return lightControl($devInfo, "off");
}

# return: devInfo array
sub getDevInfosByDevName {
    my ($self, $devName) = @_;

    if (!hasSas2208Card()) {
        return ();
    }

    my $devInfo = queryDevInfoByDevNameThroughWwn($devName);
    if (Class::DevInfo::hasControllerId($devInfo)) {
        return ($devInfo);
    }

    return ();
}

sub isSas2208CardType {
    my ($cardType) = @_;
    return ($cardType eq CARD_TYPE_SAS);
}

sub hasSas2208Card {
    #>02:00.0 Serial Attached SCSI controller [0107]: LSI Logic / Symbios Logic SAS2208 PCI-Express Fusion-MPT SAS-2 [1000:0087] (rev 05)

    my $cardName = CARD_NAME;
    return Common::hasCardAndCmdToolByLspciPattern($cardName, $lspciPattern, $sas2ircuToolPath);
}

#/root/sas2ircu <controller #> LOCATE <Encl:Bay> <Action>
sub lightControl {
    my ($devInfo, $action) = @_;

    Common::myDebugLog("Light $action device:".Class::DevInfo::toJson($devInfo));
    my $cardType = Class::DevInfo::getCardType($devInfo);
    if (!isSas2208CardType($cardType)) {
        Common::myErrorLog("Light $action failed. Device:".Class::DevInfo::toJson($devInfo)."is not ".CARD_NAME." card");
        return 0;
    }

    my $controllerId = Class::DevInfo::getControllerId($devInfo);
    my $slotNumber = Class::DevInfo::getSlotNumber($devInfo);
    my $enclosureId = Class::DevInfo::getEnclosureId($devInfo);

    my $cmd = $sas2ircuToolPath." $controllerId locate $enclosureId:$slotNumber $action";
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

# query devInfo by devName through wwn
sub queryDevInfoByDevNameThroughWwn {
    my ($devName) = @_;

    my $wwn = Common::getWwnByDevName($devName);
    if (!($wwn)) {
        Common::myErrorLog("Get WWN for $devName failed.");
        return Class::DevInfo::newEmpty();
    }

    my $devInfo = SasCommon::queryDevInfoByWwnFromCard($wwn, $sas2ircuToolPath, CARD_TYPE_SAS);
    if (Class::DevInfo::hasControllerId($devInfo)) {
        Class::DevInfo::setDevName($devInfo, $devName);
        return ($devInfo);
    }

    return Class::DevInfo::newEmpty();
}

1;
