package MegaCommon;
use strict;
use warnings FATAL => 'all';
use FindBin '$RealBin';
use lib "$RealBin";
use Common;
use Class::DevInfo;

# query devInfo by devName through wwn
sub queryDevInfoByDevNameThroughWwn {
    my ($devName, $megaToolPath, $cardType) = @_;

    my $wwn = Common::getWwnByDevName($devName);
    if (!($wwn)) {
        Common::myErrorLog("Get WWN for $devName failed.");
        return Class::DevInfo::newEmpty();
    }

    #use wwn match the dev info's wwn, if match we get it, otherwise we'll use next method
    my $devInfo = queryDevInfoByWwnFromCard($wwn, $megaToolPath, $cardType);
    if (Class::DevInfo::hasControllerId($devInfo)) {
        Class::DevInfo::setDevName($devInfo, $devName);
        return $devInfo;
    }

    return Class::DevInfo::newEmpty();
}

sub queryDevInfoByWwnFromCard {
    # /opt/MegaRAID/MegaCli/MegaCli64 -pdlist -aall | grep -E "^Adapter|^Enclosure position|^Slot Number|^WWN|^Inquiry Data|^Media Type"
#    Adapter #0
#    Slot Number: 0
#    Enclosure position: 1
#    WWN: 5002538e4038e7d2
#    Inquiry Data: S3YLNX0K503322V     Samsung SSD 860 EVO 250GB               RVT01B6Q
#    Media Type: Solid State Device
#    Slot Number: 3
#    Enclosure position: 1
#    WWN: 5000cca25ece50bd
#    Inquiry Data: K5H0H7NA            HGST HUS726020ALE610                    APGNT907
#    Media Type: Hard Disk Device
#    Slot Number: 5
#    Enclosure position: 1
#    WWN: 5000cca25ece4261
#    Inquiry Data: K5H0BE2A            HGST HUS726020ALE610                    APGNT907
#    Media Type: Hard Disk Device
#    Slot Number: 6
#    Enclosure position: 1
#    WWN: 5000cca25ed72019
#    Inquiry Data: K5HMW1KD            HGST HUS726020ALE610                    APGNTD05
#    Media Type: Hard Disk Device
#    Slot Number: 7
#    Enclosure position: 1
#    WWN: 5000cca25ecd7a02
#    Inquiry Data: K5GYN1DA            HGST HUS726020ALE610                    APGNT907
#    Media Type: Hard Disk Device
#    Slot Number: 9
#    Enclosure position: 1
#    WWN: 5000cca25ece5a10
#    Inquiry Data: K5H0KRNA            HGST HUS726020ALE610                    APGNT907
#    Media Type: Hard Disk Device
#    Slot Number: 11
#    Enclosure position: 1
#    WWN: 5000cca25ece5b0f
#    Inquiry Data: K5H0KZWA            HGST HUS726020ALE610                    APGNT907
#    Media Type: Hard Disk Device
#
    (my $wwnQueryed, my $megaToolPath, my $cardType) = @_;
    Common::myDebugLog("Query device info by wwn:[$wwnQueryed] from card");

    my $cmd = $megaToolPath." -pdlist -aall | grep -E \"^Adapter|^Enclosure Device ID|^Slot Number|^WWN|^Inquiry Data|^Media Type\"";
    Common::myDebugLog("Get adapter info cmd:[$cmd]");
    my $cmdRetMsg = qx($cmd);

    if ($? != 0) {
        Common::myErrorLog("Get adapter info failed. exec cmd:[$cmd] failed.");
        return Class::DevInfo::newEmpty();
    }

    Common::myDebugLog("Exec cmd:[$cmd] success. RetMsg:$cmdRetMsg");

    ## we meet wwn got by udevadm is different from got by raid command.
    my @wwnAdapterList = Common::wwnAdapter($wwnQueryed);

    my @lines = split(/[\r\n]/, $cmdRetMsg);

    my $adapter = undef;
    my @slotNumber = ();
    my @enclosureId = ();
    my @serialNumber = ();
    my @diskType = ();
    my @raidWwn = ();

    my $diskIndex = 0;
    my $foundDiskIndex = undef;
    foreach my $line (@lines) {
        chomp($line);
        $line = lc($line);
        Common::myDebugLog("MegaCommon: check line [$line] ");
        if ($line =~ /adapter\s*#(\d+)/) {
            #check is got wwn in last adapter
            if (defined $foundDiskIndex) {
                Common::myDebugLog("Find adapter info success.WWN:[$raidWwn[$foundDiskIndex] Adapter:[$adapter] Slot Number:[$slotNumber[$foundDiskIndex]] Enclosure Device Id:[$enclosureId[$foundDiskIndex]].");

                return Class::DevInfo::newByWwnAdapterSlotEnclosureCardType($raidWwn[$foundDiskIndex], $adapter, $slotNumber[$foundDiskIndex],
                    $enclosureId[$foundDiskIndex], $cardType, $serialNumber[$foundDiskIndex], $diskType[$foundDiskIndex]);
            }

            #if not got wwn, we will found it from next adapter
            $adapter = $1;
            Common::myDebugLog("MegaCommon: adapter [$adapter] ");
            @slotNumber = ();
            @enclosureId = ();
            @serialNumber = ();
            @diskType = ();
            @raidWwn = ();
        } elsif ($line =~ /slot\s*number:\s*(\d+)/) {
            push(@slotNumber, $1);
            Common::myDebugLog("MegaCommon: slotNumber [@slotNumber] ");
        } elsif ($line =~ /enclosure\s*device\s*id:\s*(\d+)/){
            push(@enclosureId, $1);
            Common::myDebugLog("MegaCommon: enclosureId [@enclosureId] ");
        } elsif ($line =~ /media\s*type:\s*([a-zA-Z]*)/){
            if ($1 =~ /solid/i) {
                push(@diskType, "SSD");
                Common::myDebugLog("MegaCommon: diskType set to SSD ");
            } else {
                push(@diskType, "HDD");
                Common::myDebugLog("MegaCommon: diskType set to HDD ");
            }
        } elsif ($line =~ /wwn:\s*/i) {
            foreach my $element (@wwnAdapterList) {
                if ($line =~ /wwn:\s*$element/i){
                    push(@raidWwn, $element);
                    $foundDiskIndex = $diskIndex;
                    Common::myDebugLog("Find adapter info for WWN:[$wwnQueryed] success. new wwn number:$element");
                    last;
                }
            }
            $diskIndex = $diskIndex+1;
        } elsif ($line =~ /inquiry\s*data\s*:\s*(([0-9a-zA-Z]*)st|wd-([0-9a-zA-Z]*)wdc)|(b[0-9a-zA-Z]*n)|([0-9a-zA-Z]*)/) {
            if ($2) {
                push(@serialNumber, $2);
                Common::myDebugLog("MegaCommon: -02- serialNumber [@serialNumber] ");
            } elsif ($3) {
                push(@serialNumber, $3);
                Common::myDebugLog("MegaCommon: -03- serialNumber [@serialNumber] ");
            } elsif ($4) {
                push(@serialNumber, $4);
                Common::myDebugLog("MegaCommon: -04- serialNumber [@serialNumber] ");
            } elsif ($5) {
                push(@serialNumber, $5);
                Common::myDebugLog("MegaCommon: -05- serialNumber [@serialNumber] ");
            } else {
                push(@serialNumber, "0");
                Common::myDebugLog("MegaCommon: serialNumber [@serialNumber] ");
            }
        }
    }

    #if all adapte has been checked, and not found wwn
    if (!(defined $foundDiskIndex)) {
        Common::myErrorLog("Find adapter info for WWN:[$wwnQueryed] failed.");
        return Class::DevInfo::newEmpty();
    }

    Common::myDebugLog("Find adapter info success.WWN:[$raidWwn[$foundDiskIndex] Adapter:[$adapter] Slot Number:[$slotNumber[$foundDiskIndex]] Enclosure Device Id:[$enclosureId[$foundDiskIndex]].");
    return Class::DevInfo::newByWwnAdapterSlotEnclosureCardType($raidWwn[$foundDiskIndex], $adapter, $slotNumber[$foundDiskIndex],
        $enclosureId[$foundDiskIndex], $cardType, $serialNumber[$foundDiskIndex], $diskType[$foundDiskIndex]);
}

sub queryDevInfoByDevNameThroughPath {
    my ($devName, $megaToolPath, $cardType) = @_;

    Common::myDebugLog("Query Device info through pci path for device:[$devName]");
    my $pciPath = Common::getPciPathByDevName($devName);
    if (!($pciPath)) {
        return ();
    }

    # pci path pattern: pci-0000:{Bus Number}:{Device Number}:{Function Number}-scsi-0:[0,7]:{Target Id}:0
    # pci-0000:03:00.0-scsi-0:2:2:0
    if (!($pciPath =~ /pci-0000:(\d+):(\d+)\.(\d+)-scsi-\d+:\d+:(\d+):\d+/)) {
        Common::myErrorLog("Can't get targetId from Pci path:[$pciPath]");
        return ();
    }
    Common::myDebugLog("get targetId from Pci path:[busNum deviceNum functionNum targetId]=[$1 $2 $3 $4]");

    my $busNumFromPath = hex($1);
    my $deviceNumFromPath = hex($2);
    my $functionNumFromPath = hex($3);

    # we'll use this to match at last
    my $targetIdFromPath = $4;

    Common::myDebugLog("change targetId by hex:[busNum deviceNum functionNum targetId]=[$busNumFromPath $deviceNumFromPath $functionNumFromPath $targetIdFromPath]");

    #use the three para below to find ControllerId
    my $controllerId = getAdapterIdByBusDeviceFunctionNum($megaToolPath, $busNumFromPath, $deviceNumFromPath, $functionNumFromPath);
    if (!(defined $controllerId)) {
        Common::myErrorLog("Can't get controllerId by bus number:[$busNumFromPath]".
            "device number:[$deviceNumFromPath] function number:[$functionNumFromPath]");
        return ();
    }

    # one targetId may be has multi physical device
    #/opt/MegaRAID/MegaCli/MegaCli64 -ldpdinfo -a0 | grep -E "^Virtual Drive|^Enclosure Device ID|^Slot Number|^WWN"
    #>Virtual Drive: 0 (Target Id: 0)
    #>Enclosure Device ID: 32
    #>Slot Number: 0
    #>WWN: 55CD2E404B7ACE50
    #>Virtual Drive: 1 (Target Id: 1)
    #>Enclosure Device ID: 32
    #>Slot Number: 3
    #>WWN: 5000C500A2FD069B

    my $cmd = $megaToolPath." -ldpdinfo -a$controllerId | grep -E \"^Virtual Drive|^Enclosure Device ID|^Slot Number|^WWN|^Inquiry Data|^Media Type\"";
    Common::myDebugLog("exec cmd:[$cmd]");
    my $cmdRetMsg = qx($cmd);
    my $cmdRetCode = $?;
    Common::myDebugLog("exec cmd:[$cmd] retMsg:[$cmdRetMsg]");

    if ($cmdRetCode != 0) {
        Common::myErrorLog("exec cmd:[$cmd] failed. retCode:[$cmdRetCode]");
        return ();
    }

    my @lines = split(/[\r\n]/, $cmdRetMsg);
    my $targetId = undef;
    my @enclosureIds = ();
    my @slotNums = ();
    my @wwns = ();
    my @serialNums = ();
    my @diskTypes = ();

    foreach my $line (@lines) {
        chomp($line);

        if ($line =~ /Virtual\s*Drive:\s*\d+\s*\(Target\s*Id:\s*(\d+)\)/) {
            my $currentTargetId = $1;
            if (int($currentTargetId) == int($targetIdFromPath)) {
                $targetId = $currentTargetId;
                #get the info one by one
                @enclosureIds = ();
                @slotNums = ();
                @wwns = ();
                @serialNums = ();
                @diskTypes = ();
            } elsif (defined $targetId) {
                last;
            }
        } elsif ($line =~ /Enclosure\s*Device\s*ID:\s*(\d+)/) {
            push(@enclosureIds, $1);
        } elsif ($line =~ /Slot\s*Number:\s*(\d+)/) {
            push(@slotNums, $1);
        } elsif ($line =~ /WWN:\s*(\w+)/) {
            push(@wwns, $1);
        } elsif ($line =~ /Inquiry Data:\s*(([0-9a-zA-Z]*)ST|WD-([0-9a-zA-Z]*)WDC|(B[0-9a-zA-Z]*N)|([0-9a-zA-Z]?))/) {
            if ($2) {
                push(@serialNums, $2);
            } elsif ($3) {
                push(@serialNums, $3);
            } elsif ($4) {
                push(@serialNums, $4);
            } elsif ($5) {
                push(@serialNums, $5);
            }
        } elsif ($line =~ /Media\s*Type:\s*([a-zA-Z]*)/) {
            if ($1 =~ /Solid/i) {
                push(@diskTypes, "SSD");
            } else {
                push(@diskTypes, "HDD");
            }
        }
    }

    if (!(defined $targetId)
        || scalar @enclosureIds != scalar @slotNums
                || scalar @slotNums != scalar @wwns) {
        Common::myErrorLog("Can't get targetId info from cmdRetMsg.");
        return ();
    }

    my @devInfos = ();
    for (my $index = 0; $index < scalar @enclosureIds; $index++) {
        my $enclosureId = $enclosureIds[$index];
        my $slotNum = $slotNums[$index];
        my $wwn = $wwns[$index];
        my $serialNum = $serialNums[$index];
        my $diskType = $diskTypes[$index];
        my $devInfo = Class::DevInfo::newByWwnAdapterSlotEnclosureCardType(
            $wwn, $controllerId, $slotNum, $enclosureId, $cardType, $serialNum, $diskType
        );
        Class::DevInfo::setDevName($devInfo, $devName);
        Common::myDebugLog("Find device:".Class::DevInfo::toJson($devInfo));
        push(@devInfos, $devInfo);
    }

    return @devInfos;
}

sub getAdapterIdByBusDeviceFunctionNum {
    my ($megaToolPath, $busNumParam, $deviceNumParam, $functionNumParam) = @_;

    #/opt/MegaRAID/MegaCli/MegaCli64 -AdpGetPciInfo -aall | grep -E "^PCI|^Bus Number|^Device Number|^Function Number"
    #>PCI information for Controller 0
    #>Bus Number      : 3
    #>Device Number   : 0
    #>Function Number : 0

    Common::myDebugLog("Query adapter id by bus number[$busNumParam], device number[$deviceNumParam], function number[$functionNumParam]");
    my $cmd = $megaToolPath." -AdpGetPciInfo -aall | grep -E \"^PCI|^Bus Number|^Device Number|^Function Number\"";
    Common::myDebugLog("Exec cmd:[$cmd]");
    my $cmdRetMsg = qx($cmd);
    my $cmdRetCode = $?;
    Common::myDebugLog("Exec cmd:[$cmd] retMsg:[$cmdRetMsg]");

    if ($cmdRetCode != 0) {
        Common::myErrorLog("Exec cmd:[$cmd] failed.");
        return undef;
    }

    my @lines = split(/[\r\n]/, $cmdRetMsg);
    my $controllerId = undef;
    my $busNum = undef;
    my $deviceNum = undef;
    my $functionNum = undef;
    foreach my $line (@lines) {
        chomp($line);
        $line = lc($line);

        if ($line =~ /pci\s*information\s*for\s*controller\s*(\d+)/) {
            $controllerId = $1;
        }
        elsif ($line =~ /bus\s*number\s*:\s*(\d+)/) {
            $busNum = $1;
        }
        elsif ($line =~ /device\s*number\s*:\s*(\d+)/) {
            $deviceNum = $1;
        }
        elsif ($line =~ /function\s*number\s*:\s*(\d+)/) {
            $functionNum = $1;
        }
    }
    Common::myDebugLog("Query adapter id by bus number[$busNumParam], device number[$deviceNumParam], function number[$functionNumParam]");
    Common::myDebugLog("got bus number[$busNum], device number[$deviceNumParam], function number[$functionNumParam]");

    if (defined $controllerId && defined $busNum && defined $deviceNum && defined $functionNum) {
        if (equalIntOrHexWithIntStr($busNum, $busNumParam)
            && equalIntOrHexWithIntStr($deviceNum, $deviceNumParam)
            && equalIntOrHexWithIntStr($functionNum, $functionNumParam)) {
            Common::myDebugLog("Find ControllerId:[$controllerId] by Bus number:[$busNum] device number:[$deviceNum] function number:[$functionNumParam]");
            return $controllerId;
        } else {
            Common::myDebugLog("ControllerId:[$controllerId] Bus number:[$busNum] device number:[$deviceNum] "
                ."function number:[$functionNumParam] can't match continue.");
            $controllerId = undef;
            $busNum = undef;
            $deviceNum = undef;
            $functionNum = undef;
        }
    }

    return undef;
}

# compare param1 and param2, param1 maybe int or hex, param2 is hex
sub equalIntOrHexWithIntStr {
    my ($left, $right) = @_;

    if (int($left) == int($right)) {
        return 1;
    }

    if (hex($left) == int($right)) {
        return 1;
    }

    return 0;
}

1;
