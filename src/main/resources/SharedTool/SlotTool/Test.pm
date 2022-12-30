package Test;
use strict;
use warnings FATAL => 'all';
use Common;
use Class::DevInfo;


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

    my $cmd = "/opt/MegaRAID/MegaCli/MegaCli64 -pdlist -aall | grep -E \"^Adapter|^Enclosure Device ID|^Slot Number|^WWN|^Inquiry Data|^Media Type\"";
    Common::myDebugLog("Get adapter info cmd:[$cmd]");
    my $cmdRetMsg = "Adapter #0

Enclosure Device ID: 65
Slot Number: 0

WWN: 500117310146e4d4
Inquiry Data:             A037DF83SDLF1DAR480G-1HHS                       ZR09RP41
Media Type: Solid State Device

Enclosure Device ID: 65
Slot Number: 1

WWN: 500117310150fad0
Inquiry Data:             A03AAECASDLF1DAR480G-1HHS                       ZR09RP41
Media Type: Solid State Device

Enclosure Device ID: 65
Slot Number: 2

WWN: 5000c500b2ea8277
Inquiry Data:             ZA1D39SVST8000NM0055-1RM112                     SN03
Media Type: Hard Disk Device

Enclosure Device ID: 65
Slot Number: 3

WWN: 5000c500b2f03ba7
Inquiry Data:             ZA1DD5H1ST8000NM0055-1RM112                     SN03
Media Type: Hard Disk Device

Enclosure Device ID: 65
Slot Number: 4

WWN: 5000c500b2e5efd2
Inquiry Data:             ZA1DD0JEST8000NM0055-1RM112                     SN03
Media Type: Hard Disk Device

Enclosure Device ID: 65
Slot Number: 5
WWN: 5000c500b2f0281f
Inquiry Data:             ZA1DD51EST8000NM0055-1RM112                     SN03
Media Type: Hard Disk Device
Enclosure Device ID: 65
Slot Number: 6
WWN: 5000c500b2d93f4f
Inquiry Data:             ZA1DD32RST8000NM0055-1RM112                     SN03
Media Type: Hard Disk Device
Enclosure Device ID: 65
Slot Number: 7
WWN: 5000c500b2d61611
Inquiry Data:             ZA1DDLKSST8000NM0055-1RM112                     SN03
Media Type: Hard Disk Device
Enclosure Device ID: 65
Slot Number: 8
WWN: 5000c500b2d62655
Inquiry Data:             ZA1DDPX8ST8000NM0055-1RM112                     SN03
Media Type: Hard Disk Device
Enclosure Device ID: 65
Slot Number: 9
WWN: 5000c500b2f02bb3
Inquiry Data:             ZA1DD58TST8000NM0055-1RM112                     SN03
Media Type: Hard Disk Device
Enclosure Device ID: 65
Slot Number: 10
WWN: 5000c500b2e9f976
Inquiry Data:             ZA1DDLZ0ST8000NM0055-1RM112                     SN03
Media Type: Hard Disk Device
Enclosure Device ID: 65
Slot Number: 11
WWN: 5000c500b2d96419
Inquiry Data:             ZA1DD2ZJST8000NM0055-1RM112                     SN03
Media Type: Hard Disk Device

Enclosure Device ID: 65
Slot Number: 12

WWN: 500a07511edbebd7
Inquiry Data:         18371EDBEBD7MTFDDAK960TDC-1AT1ZABYY                  D1MU004
Media Type: Solid State Device

Enclosure Device ID: 65
Slot Number: 13

WWN: 500a07511edbec6a
Inquiry Data:         18371EDBEC6AMTFDDAK960TDC-1AT1ZABYY                  D1MU004
Media Type: Solid State Device";

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

        if ($line =~ /adapter\s*#(\d+)/) {
            #check is got wwn in this adapter
            if (defined $foundDiskIndex) {
                Common::myDebugLog("Find adapter info success.WWN:[$raidWwn[$foundDiskIndex] Adapter:[$adapter] Slot Number:[$slotNumber[$foundDiskIndex]] Enclosure Device Id:[$enclosureId[$foundDiskIndex]].");

                return Class::DevInfo::newByWwnAdapterSlotEnclosureCardType($raidWwn[$foundDiskIndex], $adapter, $slotNumber[$foundDiskIndex],
                    $enclosureId[$foundDiskIndex], $cardType, $serialNumber[$foundDiskIndex], $diskType[$foundDiskIndex]);
            }

            #if not got wwn, we will found it from next adapter
            $adapter = $1;
            @slotNumber = ();
            @enclosureId = ();
            @serialNumber = ();
            @diskType = ();
            @raidWwn = ();
        } elsif ($line =~ /slot\s*number:\s*(\d+)/) {
            push(@slotNumber, $1);
        } elsif ($line =~ /enclosure\s*device\s*id:\s*(\d+)/){
            push(@enclosureId, $1);
        } elsif ($line =~ /media\s*type:\s*([a-zA-Z]*)/){
            if ($1 =~ /solid/i) {
                push(@diskType, "SSD");
            } else {
                push(@diskType, "HDD");
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
            } elsif ($3) {
                push(@serialNumber, $3);
            } elsif ($4) {
                push(@serialNumber, $4);
            } elsif ($5) {
                push(@serialNumber, $5);
            } else {
                push(@serialNumber, "0");
            }
        }
    }

    if (!(defined $foundDiskIndex)) {
        Common::myErrorLog("Find adapter info for WWN:[$wwnQueryed] failed.");
        return Class::DevInfo::newEmpty();
    }

    Common::myDebugLog("Find adapter info success.WWN:[$raidWwn[$foundDiskIndex] Adapter:[$adapter] Slot Number:[$slotNumber[$foundDiskIndex]] Enclosure Device Id:[$enclosureId[$foundDiskIndex]].");
    return Class::DevInfo::newByWwnAdapterSlotEnclosureCardType($raidWwn[$foundDiskIndex], $adapter, $slotNumber[$foundDiskIndex],
        $enclosureId[$foundDiskIndex], $cardType, $serialNumber[$foundDiskIndex], $diskType[$foundDiskIndex]);
}

sub TestWwnAdapter {
    Common::enableDebugMode();
    my $wwnNo = "50014EE003FD27D1";
    queryDevInfoByWwnFromCard($wwnNo);
}

sub print_AoA {
    my @AoA = @_;
    for (@AoA) {
        print "@{$_}\n";
    }
    print "\n";
}

sub TestArray {
    my @AoA;

    push @{$AoA[0]}, "wilma", "betty";
    push @{$AoA[1]}, "wilma", "betty";

    my @tmp = (1, 2, 3, 4);
    push (@AoA, [@tmp]);
    @tmp = ("a", "b", "c", "d");
    push (@AoA, [@tmp]);

    print_AoA(@AoA);

    print($AoA[0]."\n");
    push @{$AoA[0]}, "wilma", "betty";
    push @{$AoA[1]}, 9, 0;
    print_AoA(@AoA);

    for my $i (0 .. $#AoA){
        for my $j (0 .. $#{$AoA[$i]}){
            print "elt $i, $j is $AoA[$i][$j]\n";
        }
        print "\n";
    }

}

#TestArray();
Common->enableDebugMode();
queryDevInfoByWwnFromCard("500117310146e4d4", "/opt/MegaRAID/MegaCli/MegaCli64", "2208");
1;