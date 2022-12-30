package Mega3416;
use strict;
use warnings FATAL => 'all';
use FindBin '$RealBin';
use lib "$RealBin";
use Common;
use Class::DevInfo;
use MegaCommon;

use constant CARD_TYPE_MEGA => "MegaRAID_Tri-Mode_SAS3416";

use constant MEGA_TOOL_PATH_CONFIG_NAME => "mega3416.tool.path";
use constant MEGA_TOOL_PATH_DEFAULT => "/opt/MegaRAID/storcli";

use constant LSPCI_PATTERN_CONFIG_NAME => "mega3416.raid.pattern";
use constant LSPCI_PATTERN_DEFAULT => "LSI.*MegaRAID Tri-Mode SAS3416";

use constant CARD_NAME => "SAS3416";

my $megaToolPath = Common::getConfigItem(MEGA_TOOL_PATH_CONFIG_NAME);
$megaToolPath = MEGA_TOOL_PATH_DEFAULT if !(defined $megaToolPath);

my $lspciPattern = Common::getConfigItem(LSPCI_PATTERN_CONFIG_NAME);
$lspciPattern = LSPCI_PATTERN_DEFAULT if !(defined $lspciPattern);

sub isCardTypeBelongToThisCard {
    my ($self, $cardType) = @_;
    return isMega3416CardType($cardType);
}

#/opt/MegaRAID/storcli /c0/e64/s6 start locate
sub lightOn {
    my ($self, $devInfo) = @_;
    return lightControl($devInfo, "start");
}

#/opt/MegaRAID/storcli /c0/e64/s6 stop locate
sub lightOff {
    my ($self, $devInfo) = @_;
    return lightControl($devInfo, "stop");
}

# return: devInfo array
sub getDevInfosByDevName {
    my ($self, $devName) = @_;

    #we need tool to detect
    if (!hasMega3416Card()) {
        return ();
    }
    Common::myDebugLog(CARD_NAME." : try to get DevInfo by name :$devName  and tool path: $megaToolPath");
    my $devInfo = queryDevInfoByDevNameThroughWwn($devName, $megaToolPath, CARD_TYPE_MEGA);
    if (Class::DevInfo::hasControllerId($devInfo)) {
        Common::myDebugLog(CARD_NAME." : get disk: $devName controllerId: [$devInfo->{controllerId}] by wwn : [$devInfo->{wwn}]");
        return ($devInfo);
    } else {
        return ();
    } 
}

sub isMega3416CardType {
    my ($cardType) = @_;
    return ($cardType eq CARD_TYPE_MEGA);
}

sub hasMega3416Card {
    #lspci -nn | grep -i -E "lsi.*megaraid.*sas\s*3416"
    #>03:00.0 RAID bus controller [0104]: LSI Logic / Symbios Logic MegaRAID SAS 3416 [Thunderbolt] [1000:005b] (rev 05)

    my $cardName = CARD_NAME;
    return Common::hasCardAndCmdToolByLspciPattern($cardName, $lspciPattern, $megaToolPath);
}



#/opt/MegaRAID/MegaCli/MegaCli64 -PdLocate {[-start] | -stop} -physdrv[E0:S0,E1:S1,...] -aN|-a0,1,2|-aALL
#/opt/MegaRAID/MegaCli/MegaCli64 -pdlocate -start -physdrv[32:6] -a0
sub lightControl {
    my ($devInfo, $action) = @_;

    Common::myDebugLog(CARD_NAME." : Light $action device:".Class::DevInfo::toJson($devInfo));
    my $cardType = Class::DevInfo::getCardType($devInfo);
    if (!isMega3416CardType($cardType)) {
        Common::myErrorLog(CARD_NAME." : Light $action failed. Device:".Class::DevInfo::toJson($devInfo)
            ."is not Mega3416 card");
        return 0;
    }

    my $controllerId = Class::DevInfo::getControllerId($devInfo);
    my $slotNumber = Class::DevInfo::getSlotNumber($devInfo);
    my $enclosureId = Class::DevInfo::getEnclosureId($devInfo);

    my $cmd = $megaToolPath." /c$controllerId/e$enclosureId/s$slotNumber $action locate";
    Common::myDebugLog(CARD_NAME." : Light $action device. Cmd:[$cmd]");

    my $cmdRetMsg = qx($cmd);
    my $cmdRetCode = $?;
    Common::myDebugLog(CARD_NAME." : Light $action device. Cmd:[$cmd] RetMsg:[$cmdRetMsg]");

    if ($cmdRetCode == 0) {
        Common::myDebugLog(CARD_NAME." : Light $action device success.");
        return 1;
    } else {
        Common::myDebugLog(CARD_NAME." : Light $action device failed.");
        return 0;
    }
}

## query devInfo by devName through wwn
sub queryDevInfoByDevNameThroughWwn {
   my ($devName) = @_;

   my $wwn = Common::getWwnByDevName($devName);
   if (!($wwn)) {
       Common::myErrorLog("[]Get WWN for $devName failed.");
       return Class::DevInfo::newEmpty();
   }
   Common::myDebugLog(CARD_NAME." : devname:$devName, wwn: $wwn, megaToolPath: $megaToolPath");
   #use wwn match the dev info's wwn, if match we get it, otherwise we'll use next method
   my $devInfo = queryDevInfoByWwnFromCard($wwn, $megaToolPath, CARD_TYPE_MEGA);
   if (Class::DevInfo::hasControllerId($devInfo)) {
       Class::DevInfo::setDevName($devInfo, $devName);
       return $devInfo;
   } else {
       # wwn: 5000039af86a25dd - Common::getWwnByDevName($devName)
       # wwn: 5000039AF86A25DC - /opt/MegaRAID/storcli/storcli64 -pdlist -aall
       my $short_wwn = substr($wwn, 0, length($wwn)-1);
       Common::myDebugLog(CARD_NAME." : try to match disk : $devName by short wwn: $short_wwn");
       $devInfo = queryDevInfoByWwnFromCard($short_wwn, $megaToolPath, CARD_TYPE_MEGA);
   }
   if (Class::DevInfo::hasControllerId($devInfo)) {
       Class::DevInfo::setDevName($devInfo, $devName);
       return $devInfo;
   }

   return Class::DevInfo::newEmpty();
}


sub queryDevInfoByWwnFromCard {
    # /opt/MegaRAID/storcli/storcli64 -pdlist --aall | grep -E "^-Adapter|^Enclosure Device|^Slot Number|^WWN|^Inquiry Data|^PD Type"
# -Adapter #0
# Enclosure Device ID: 69
# Slot Number: 0
# WWN: 55CD2E415355B02B
# PD Type: SATA
# Inquiry Data: PHYG122001AT960CGN  SSDSC2KG960G8L       01PE344D7A09692LEN XCV1LX41
# Enclosure Device ID: 69
# Slot Number: 1
# WWN: 55CD2E415325819E
# PD Type: SATA
# Inquiry Data: PHYG101002C1960CGN  SSDSC2KG960G8L       01PE344D7A09692LEN XCV1LX41
# Enclosure Device ID: 69
# Slot Number: 2
# WWN: 5000039AF86A25DC
# PD Type: SAS
# Inquiry Data: LENOVO  AL15SEB030N     TB5561X0A057TB55TB55TB55
# Enclosure Device ID: 69
# Slot Number: 3
# WWN: 5000039AB8D06BFC
# PD Type: SATA
# Inquiry Data:             TCWF2UZWMG06ACA600E          00YK041D7A01890LEN     TJ64

    (my $wwnQueryed, my $megaToolPath, my $cardType) = @_;
    my $cmd = $megaToolPath." -pdlist -aall | grep -E \"Adapter|^Enclosure Device|^Slot Number|^WWN|^Inquiry Data|^PD Type\"";
    Common::myDebugLog(CARD_NAME." : Get adapter info cmd:[$cmd]");
    my $cmdRetMsg = qx($cmd);

    if ($? != 0) {
        Common::myErrorLog(CARD_NAME." : Get adapter info failed. exec cmd:[$cmd] failed.");
        return Class::DevInfo::newEmpty();
    }

    Common::myDebugLog(CARD_NAME." : Exec cmd:[$cmd] success. RetMsg:$cmdRetMsg");

    my $value_controllerId = undef;
    my $value_slotNumber = undef;
    my $value_enclosureId = undef;
    my $value_serialNumber = undef;
    my $value_diskType = undef;

    my $flag_matched_wwn = "false";
    my @lines = split(/[\r\n]/, $cmdRetMsg);
    # get disk information which wwn matched
    for(my $index=0; $index<scalar(@lines); $index++){
        my $each_line = $lines[$index];
        chomp($each_line);
        $each_line=lc($each_line);
        Common::myDebugLog(CARD_NAME." : check line [$each_line] ");
        if ($each_line =~ /adapter\s*#(\d+)/ ) {
            $value_controllerId = $1;
            Common::myDebugLog(CARD_NAME." : controllerId [$value_controllerId]");
            next;
        } 
        if ($each_line =~ /enclosure\s*device\s*id:\s*(\d+)/) {
            $value_enclosureId = $1;
            Common::myDebugLog(CARD_NAME." : enclosureId [$value_enclosureId]");
            next;
        } 
        if ($each_line =~ /slot\s*number:\s*(\d+)/) {
            $value_slotNumber = $1;
            Common::myDebugLog(CARD_NAME." : slotNumber [$value_slotNumber]");
            next;
        } 
        if ($each_line =~ /wwn/ ) {
            my $tmp_value = (split /:/, $each_line)[-1];
            $tmp_value =~ s/\s//g;
            if ( $tmp_value =~ $wwnQueryed ) {
                Common::myDebugLog(CARD_NAME." : find wwn [$wwnQueryed]");
                $flag_matched_wwn = "true";
                $index++;
                $each_line = $lines[$index];
                chomp($each_line);
                $each_line=lc($each_line);
                if ( $each_line =~ /pd\s*type/ ) {
                    $value_diskType = (split /:/, $each_line)[-1];
                    $value_diskType =~ s/\s//g;
                    $value_diskType = uc($value_diskType);
                    Common::myDebugLog(CARD_NAME." : diskType [$value_diskType]");
                }
                $index++;
                $each_line = $lines[$index];
                chomp($each_line);
                $each_line=lc($each_line);
                if ( $each_line =~ /inquiry\s*data/ ) {
                    # Inquiry Data: PHYG122001AT960CGN  SSDSC2KG960G8L       01PE344D7A09692LEN XCV1LX41
                    if ($each_line =~ 'ssdsc') {
                        $value_diskType = "SSD";
                        Common::myDebugLog(CARD_NAME." :  diskType change to [$value_diskType]");
                    }
                    $value_serialNumber = $wwnQueryed;
                }
            }
        }
        if ($flag_matched_wwn eq "true") {
            last;
        }
    }

    #if all adapte has been checked, and not found wwn
    unless ($flag_matched_wwn eq "true") {
        Common::myErrorLog("Find adapter info for WWN:[$wwnQueryed] failed.");
        return Class::DevInfo::newEmpty();
    }

    Common::myDebugLog("Find adapter info success.WWN:$wwnQueryed Adapter:[$value_controllerId] Slot Number:[$value_slotNumber] Enclosure Device Id:[$value_enclosureId].");
    return Class::DevInfo::newByWwnAdapterSlotEnclosureCardType($wwnQueryed, $value_controllerId, $value_slotNumber,
        $value_enclosureId, $cardType, $value_serialNumber, $value_diskType);
}

1;
