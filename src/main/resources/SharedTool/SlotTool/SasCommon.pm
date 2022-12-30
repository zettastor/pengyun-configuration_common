package SasCommon;
use strict;
use warnings FATAL => 'all';
use FindBin '$RealBin';
use lib "$RealBin";
use Common;
use Class::DevInfo;

sub getAllControllerIds {
    my ($sas2ircuToolPath) = @_;
    #/root/sas2ircu list | sed "1,/Index/d" | grep -E '^\s*[0-9]+' | awk '{print $1}'
    #>0
    #>1

    Common::myDebugLog("Get all controller ids");
    my $cmd = $sas2ircuToolPath." list | sed \"1,/Index/d\" | grep -E '^\\s*[0-9]+' | awk '{print \$1}'";
    Common::myDebugLog("Get controller id. cmd:[$cmd]");

    my $cmdRetMsg = qx($cmd);
    if ($? != 0) {
        Common::myErrorLog("Exec cmd:[$cmd] failed. RetMsg :[$cmdRetMsg]");
        return ();
    }

    my @controllers = ();
    my @lines = split(/[\r\n]/, $cmdRetMsg);
    foreach my $line (@lines) {
        chomp($line);
        if ($line =~ /(\d+)/) {
            my $controllerId = $1;
            Common::myDebugLog("Find controllerId:[$controllerId]");
            push(@controllers, $controllerId);
        }
    }

    return @controllers;
}

sub queryDevInfoByWwnFromCard {
#   /root/sas2ircu 0 display | sed -n "/^Physical device information/,/^Enclosure information/p" | grep -v "Enclosure information" | grep -E "^\s*Enclosure|^\s*Slot|^\s*GUID|^\s*Serial No|^\s*Drive\s*Type|^$"
#
#    Enclosure #                             : 1
#    Slot #                                  : 9
#    Serial No                               :
#    GUID                                    : N/A
#    Drive Type                              : SAS_HDD
#
#    Enclosure #                             : 2
#    Slot #                                  : 0
#    Serial No                               : S3YLNX0K503591M
#    GUID                                    : 5002538e4038e8df
#    Drive Type                              : SATA_SSD
#
#    Enclosure #                             : 2
#    Slot #                                  : 1
#    Serial No                               : WDWMC1P0E96NHV
#    GUID                                    : 50014ee0aea876cf
#    Drive Type                              : SATA_HDD
#
#    Enclosure #                             : 2
#    Slot #                                  : 2
#    Serial No                               : CVLT735503J5240CGN
#    GUID                                    : 55cd2e414e8eef58
#    Drive Type                              : SATA_SSD
#
#    Enclosure #                             : 2
#    Slot #                                  : 3
#    Serial No                               : CVLT733202G3240CGN
#    GUID                                    : 55cd2e414e8c67bf
#    Drive Type                              : SATA_SSD
#
#    Enclosure #                             : 2
#    Slot #                                  : 5
#    Serial No                               : CVLT735500S7240CGN
#    GUID                                    : 55cd2e414e8ed064
#    Drive Type                              : SATA_SSD
#
#    Enclosure #                             : 2
#    Slot #                                  : 24
#    Serial No                               : x360107
#    GUID                                    : N/A
#    Drive Type                              : SAS_HDD

    (my $wwnQueryed, my $sas2ircuToolPath, my $cardType) = @_;
    Common::myDebugLog("Query device info by wwn:[$wwnQueryed] from card");

    my @controllerIds = getAllControllerIds($sas2ircuToolPath);
    if (scalar @controllerIds <= 0) {
        Common::myDebugLog("Controller number is 0.");
        return Class::DevInfo::newEmpty();
    }

    Common::myDebugLog("ControllerId count:[".(scalar @controllerIds)."]");
    foreach my $controllerId (@controllerIds) {
        Common::myDebugLog("ControllerId [$controllerId]");
        my $cmd = $sas2ircuToolPath." $controllerId display | sed -n \"/^Physical device information/,/^Enclosure information/p\" | grep -v \"Enclosure information\" | grep -E \"^\\s*Enclosure|^\\s*Slot|^\\s*GUID|^\\s*Serial No|^\\s*Drive\\s*Type|^\$\" ";

        my $cmdRetMsg = qx($cmd);
        if ($? != 0) {
            Common::myErrorLog("Exec cmd:[$cmd] failed. RetMsg:[$cmdRetMsg]");
            next;
        }

        Common::myDebugLog("Exec cmd:[$cmd] success. RetMsg:[$cmdRetMsg]");

        my @lines = split(/[\r\n]/, $cmdRetMsg);

        my @diskLines;
        my $diskIndex = 0;
        foreach my $line (@lines) {
            chomp($line);
            $line = lc($line);

            if (!$line) {
                $diskIndex = $diskIndex + 1;
                next;
            }

            push (@{$diskLines[$diskIndex]}, $line);
        }

        ## we meet wwn got by udevadm is different from got by raid command.
        my @wwnAdapterList = Common::wwnAdapter($wwnQueryed);

        #
        for my $i (0 .. $#diskLines){
            my $enclosureId = undef;
            my $slotNumber = undef;
            my $serialNumber = undef;
            my $diskType = undef;
            my $raidWwn = undef;

            for my $j (0 .. $#{$diskLines[$i]}){
                my $line = $diskLines[$i][$j];

                if ($line =~ /\s*enclosure\s*#\s*:\s*(\d+)/) {
                    $enclosureId = $1;
                } elsif ($line =~ /\s*slot\s*#\s*:\s*(\d+)/) {
                    $slotNumber = $1;
                } elsif ($line =~ /\s*serial no\s*:\s*([0-9a-zA-Z]*)/) {
                    $serialNumber = $1;
                } elsif ($line =~ /\s*drive\s*type\s*:\s*([_a-zA-Z]*)/) {
                    if ($1 =~ /ssd/i) {
                        $diskType = "SSD";
                    } else {
                        $diskType = "HDD";
                    }
                } elsif ($line =~ /\s*guid\s*:\s*/i) {
                    foreach my $element (@wwnAdapterList) {
                        if ($line =~ /\s*guid\s*:\s*$element/i){
                            $raidWwn = $element;
                            Common::myDebugLog("Find adapter info for WWN:[$wwnQueryed] success. new wwn number:$raidWwn");
                            last;
                        }
                    }
                }
            }

            #if got wwn
            if (defined $controllerId && defined $slotNumber && defined $enclosureId && defined $raidWwn) {
                Common::myDebugLog("Find adapter info success.WWN:[$raidWwn] Adapter:[$controllerId] Slot Number:[$slotNumber] Enclosure Device Id:[$enclosureId].");
                if(! (defined $serialNumber )) {
                    $serialNumber = "0";
                }

                if(! (defined $diskType )) {
                    $diskType = "HDD";
                }

                return Class::DevInfo::newByWwnAdapterSlotEnclosureCardType($raidWwn, $controllerId, $slotNumber,
                    $enclosureId, $cardType, $serialNumber, $diskType);
            }   #for my $j (0 .. $#{$diskLines[$i]}){
        }   #for my $i (0 .. $#diskLines){
    }   #foreach my $controllerId (@controllerIds) {

    Common::myErrorLog("Find adapter info for WWN:[$wwnQueryed] failed.");
    return Class::DevInfo::newEmpty();
}

1;
