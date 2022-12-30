package Mega3508;
use strict;
use warnings FATAL => 'all';
use FindBin '$RealBin';
use lib "$RealBin";
use Common;
use Class::DevInfo;
use MegaCommon;

use constant CARD_TYPE_MEGA => "CardTypeMega3508";

use constant MEGA_TOOL_PATH_CONFIG_NAME => "mega3508.tool.path";
use constant MEGA_TOOL_PATH_DEFAULT => "/opt/MegaRAID/MegaCli/MegaCli64";

use constant LSPCI_PATTERN_CONFIG_NAME => "mega3508.raid.pattern";
use constant LSPCI_PATTERN_DEFAULT => "LSI.*MegaRAID.*SAS3508";

use constant CARD_NAME => "Mega3508";

my $megaToolPath = Common::getConfigItem(MEGA_TOOL_PATH_CONFIG_NAME);
$megaToolPath = MEGA_TOOL_PATH_DEFAULT if !(defined $megaToolPath);

my $lspciPattern = Common::getConfigItem(LSPCI_PATTERN_CONFIG_NAME);
$lspciPattern = LSPCI_PATTERN_DEFAULT if !(defined $lspciPattern);

sub isCardTypeBelongToThisCard {
    my ($self, $cardType) = @_;
    return isMega3508CardType($cardType);
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
    if (!hasMega3508Card()) {
        return ();
    }

    my $devInfo = MegaCommon::queryDevInfoByDevNameThroughWwn($devName, $megaToolPath, CARD_TYPE_MEGA);
    if (Class::DevInfo::hasControllerId($devInfo)) {
        return ($devInfo);
    }

    my @devInfos = MegaCommon::queryDevInfoByDevNameThroughPath($devName, $megaToolPath, CARD_TYPE_MEGA);

    return @devInfos;
}

sub isMega3508CardType {
    my ($cardType) = @_;
    return ($cardType eq CARD_TYPE_MEGA);
}

sub hasMega3508Card {
    #lspci -nn | grep -i -E "lsi.*megaraid.*sas\s*3508"
    #>03:00.0 RAID bus controller [0104]: LSI Logic / Symbios Logic MegaRAID SAS 3508 [Thunderbolt] [1000:005b] (rev 05)

    my $cardName = CARD_NAME;
    return Common::hasCardAndCmdToolByLspciPattern($cardName, $lspciPattern, $megaToolPath);
}

#sub queryDevInfoByDevNameThroughPath {
#    my ($devName) = @_;
#
#    Common::myDebugLog("Query Device info through pci path for device:[$devName]");
#    my $pciPath = Common::getPciPathByDevName($devName);
#    if (!($pciPath)) {
#        return ();
#    }
#
#    # pci path pattern: pci-0000:{Bus Number}:{Device Number}:{Function Number}-scsi-0:[0,7]:{Target Id}:0
#    # pci-0000:03:00.0-scsi-0:2:2:0
#    if (!($pciPath =~ /pci-0000:(\d+):(\d+)\.(\d+)-scsi-\d+:\d+:(\d+):\d+/)) {
#        Common::myErrorLog("Can't get targetId from Pci path:[$pciPath]");
#        return ();
#    }
#
#    my $busNumFromPath = hex($1);
#    my $deviceNumFromPath = hex($2);
#    my $functionNumFromPath = hex($3);
#
#    # we'll use this to match at last
#    my $targetIdFromPath = $4;
#
#    #use the three para below to find ControllerId
#    my $controllerId = getAdapterIdByBusDeviceFunctionNum($busNumFromPath, $deviceNumFromPath, $functionNumFromPath);
#    if (!(defined $controllerId)) {
#        Common::myErrorLog("Can't get controllerId by bus number:[$busNumFromPath]".
#            "device number:[$deviceNumFromPath] function number:[$functionNumFromPath]");
#        return ();
#    }
#
#    # one targetId may be has multi physical device
#    #/opt/Mega3508/MegaCli/MegaCli64 -ldpdinfo -a0 | grep -E "^Virtual Drive|^Enclosure Device ID|^Slot Number|^WWN"
#    #>Virtual Drive: 0 (Target Id: 0)
#    #>Enclosure Device ID: 32
#    #>Slot Number: 0
#    #>WWN: 55CD2E404B7ACE50
#    #>Virtual Drive: 1 (Target Id: 1)
#    #>Enclosure Device ID: 32
#    #>Slot Number: 3
#    #>WWN: 5000C500A2FD069B
#
#    my $cmd = $megaToolPath." -ldpdinfo -a$controllerId | grep -E \"^Virtual Drive|^Enclosure Device ID|^Slot Number|^WWN|^Inquiry Data|^Media Type\"";
#    Common::myDebugLog("exec cmd:[$cmd]");
#    my $cmdRetMsg = qx($cmd);
#    my $cmdRetCode = $?;
#    Common::myDebugLog("exec cmd:[$cmd] retMsg:[$cmdRetMsg]");
#
#    if ($cmdRetCode != 0) {
#        Common::myErrorLog("exec cmd:[$cmd] failed. retCode:[$cmdRetCode]");
#        return ();
#    }
#
#    my @lines = split(/[\r\n]/, $cmdRetMsg);
#    my $targetId = undef;
#    my @enclosureIds = ();
#    my @slotNums = ();
#    my @wwns = ();
#    my @serialNums = ();
#    my @diskTypes = ();
#
#    foreach my $line (@lines) {
#        chomp($line);
#
#        if ($line =~ /Virtual\s*Drive:\s*\d+\s*\(Target\s*Id:\s*(\d+)\)/) {
#            my $currentTargetId = $1;
#            if (int($currentTargetId) == int($targetIdFromPath)) {
#                $targetId = $currentTargetId;
#                #get the info one by one
#                @enclosureIds = ();
#                @slotNums = ();
#                @wwns = ();
#                @serialNums = ();
#                @diskTypes = ();
#            } elsif (defined $targetId) {
#                last;
#            }
#        } elsif ($line =~ /Enclosure\s*Device\s*ID:\s*(\d+)/) {
#            push(@enclosureIds, $1);
#        } elsif ($line =~ /Slot\s*Number:\s*(\d+)/) {
#            push(@slotNums, $1);
#        } elsif ($line =~ /WWN:\s*(\w+)/) {
#            push(@wwns, $1);
#        } elsif ($line =~ /Inquiry Data:\s*(([0-9a-zA-Z]*)ST|WD-([0-9a-zA-Z]*)WDC|(B[0-9a-zA-Z]*N)|([0-9a-zA-Z]?))/) {
#            if ($2) {
#                push(@serialNums, $2);
#            } elsif ($3) {
#                push(@serialNums, $3);
#            } elsif ($4) {
#                push(@serialNums, $4);
#            } elsif ($5) {
#                push(@serialNums, $5);
#            }
#        } elsif ($line =~ /Media\s*Type:\s*([a-zA-Z]*)/) {
#            if ($1 =~ /Solid/i) {
#                push(@diskTypes, "SSD");
#            } else {
#                push(@diskTypes, "HDD");
#            }
#        }
#    }
#
#    if (!(defined $targetId)
#        || scalar @enclosureIds != scalar @slotNums
#                || scalar @slotNums != scalar @wwns) {
#        Common::myErrorLog("Can't get targetId info from cmdRetMsg.");
#        return ();
#    }
#
#    my @devInfos = ();
#    for (my $index = 0; $index < scalar @enclosureIds; $index++) {
#        my $enclosureId = $enclosureIds[$index];
#        my $slotNum = $slotNums[$index];
#        my $wwn = $wwns[$index];
#        my $serialNum = $serialNums[$index];
#        my $diskType = $diskTypes[$index];
#        my $devInfo = Class::DevInfo::newByWwnAdapterSlotEnclosureCardType(
#            $wwn, $controllerId, $slotNum, $enclosureId, CARD_TYPE_MEGA, $serialNum, $diskType
#        );
#        Class::DevInfo::setDevName($devInfo, $devName);
#        Common::myDebugLog("Find device:".Class::DevInfo::toJson($devInfo));
#        push(@devInfos, $devInfo);
#    }
#
#    return @devInfos;
#}
#
#sub getAdapterIdByBusDeviceFunctionNum {
#    my ($busNumParam, $deviceNumParam, $functionNumParam) = @_;
#
#    #/opt/Mega3508/MegaCli/MegaCli64 -AdpGetPciInfo -aall | grep -E "^PCI|^Bus Number|^Device Number|^Function Number"
#    #>PCI information for Controller 0
#    #>Bus Number      : 3
#    #>Device Number   : 0
#    #>Function Number : 0
#
#    Common::myDebugLog("Query adapter id by bus number[$busNumParam], device number[$deviceNumParam], function number[$functionNumParam]");
#    my $cmd = $megaToolPath." -AdpGetPciInfo -aall | grep -E \"^PCI|^Bus Number|^Device Number|^Function Number\"";
#    Common::myDebugLog("Exec cmd:[$cmd]");
#    my $cmdRetMsg = qx($cmd);
#    my $cmdRetCode = $?;
#    Common::myDebugLog("Exec cmd:[$cmd] retMsg:[$cmdRetMsg]");
#
#    if ($cmdRetCode != 0) {
#        Common::myErrorLog("Exec cmd:[$cmd] failed.");
#        return undef;
#    }
#
#    my @lines = split(/[\r\n]/, $cmdRetMsg);
#    my $controllerId = undef;
#    my $busNum = undef;
#    my $deviceNum = undef;
#    my $functionNum = undef;
#    foreach my $line (@lines) {
#        chomp($line);
#
#        if ($line =~ /PCI\s*information\s*for\s*Controller\s*(\d+)/) {
#            $controllerId = $1;
#        } elsif ($line =~ /Bus\s*Number\s*:\s*(\d+)/) {
#            $busNum = $1;
#        } elsif ($line =~ /Device\s*Number\s*:\s*(\d+)/) {
#            $deviceNum = $1;
#        } elsif ($line =~ /Function\s*Number\s*:\s*(\d+)/) {
#            $functionNum = $1;
#        }
#
#        if (defined $controllerId
#            && defined $busNum
#            && defined $deviceNum
#            && defined $functionNum) {
#            if (equalIntOrHexWithIntStr($busNum, $busNumParam)
#                && equalIntOrHexWithIntStr($deviceNum, $deviceNumParam)
#                && equalIntOrHexWithIntStr($functionNum, $functionNumParam)) {
#                Common::myDebugLog("Find ControllerId:[$controllerId] by Bus number:[$busNum] device number:[$deviceNum] function number:[$functionNumParam]");
#                return $controllerId;
#            } else {
#                Common::myDebugLog("ControllerId:[$controllerId] Bus number:[$busNum] device number:[$deviceNum] "
#                    ."function number:[$functionNumParam] can't match continue.");
#                $controllerId = undef;
#                $busNum = undef;
#                $deviceNum = undef;
#                $functionNum = undef;
#            }
#        }
#    }
#
#    return undef;
#}
#
## compare param1 and param2, param1 maybe int or hex, param2 is hex
#sub equalIntOrHexWithIntStr {
#    my ($left, $right) = @_;
#
#    if (int($left) == int($right)) {
#        return 1;
#    }
#
#    if (hex($left) == int($right)) {
#        return 1;
#    }
#
#    return 0;
#}

#/opt/MegaRAID/MegaCli/MegaCli64 -PdLocate {[-start] | -stop} -physdrv[E0:S0,E1:S1,...] -aN|-a0,1,2|-aALL
#/opt/MegaRAID/MegaCli/MegaCli64 -pdlocate -start -physdrv[32:6] -a0
sub lightControl {
    my ($devInfo, $action) = @_;

    Common::myDebugLog("Light $action device:".Class::DevInfo::toJson($devInfo));
    my $cardType = Class::DevInfo::getCardType($devInfo);
    if (!isMega3508CardType($cardType)) {
        Common::myErrorLog("Light $action failed. Device:".Class::DevInfo::toJson($devInfo)
            ."is not Mega3508 card");
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

## query devInfo by devName through wwn
#sub queryDevInfoByDevNameThroughWwn {
#    my ($devName) = @_;
#
#    my $wwn = Common::getWwnByDevName($devName);
#    if (!($wwn)) {
#        Common::myErrorLog("Get WWN for $devName failed.");
#        return Class::DevInfo::newEmpty();
#    }
#
#    #use wwn match the dev info's wwn, if match we get it, otherwise we'll use next method
#    my $devInfo = MegaCommon::queryDevInfoByWwnFromCard($wwn, $megaToolPath, CARD_TYPE_MEGA);
#    if (Class::DevInfo::hasControllerId($devInfo)) {
#        Class::DevInfo::setDevName($devInfo, $devName);
#        return $devInfo;
#    }
#
#    return Class::DevInfo::newEmpty();
#}

1;
