package Common;
use strict;
use warnings FATAL => 'all';
use FindBin '$RealBin';

use constant TRUE => "true";
use constant FALSE => "false";
use constant SUCCESS_RET_CODE => "0";
use constant FAILED_RET_CODE => "-1";
use constant QUERY_DISK_ALL => "all";
use constant FIELD_UNKNOWN => "unknown";
use constant SLOT_TOOL_CONFIG_FILEPATH => $RealBin."/../../config/slottool.properties";

my $isDebug = "";

my @lspciInfos = ();

sub isTrue {
    my ($param) = @_;

    if ($param eq TRUE) {
        return 1;
    } else {
        return 0;
    }
}

sub isFalse {
    my ($param) = @_;

    if ($param eq FALSE) {
        return 1;
    } else {
        return 0;
    }
}

sub enableDebugMode {
    $isDebug = "true";
}

sub myDebugLog {
    my ($line) = @_;

    if ($isDebug) {
        myLog("DEBUG:".$line)
    }
}

sub myErrorLog {
    my ($line) = @_;

    if ($isDebug) {
        myLog("ERROR:".$line)
    }
}

sub myLog {
    my ($line) = @_;
    print($line."\n");
}

sub hasCardAndCmdToolByLspciPattern {
    my ($cardName, $pattern, $toolPath) = @_;

    myDebugLog("Check if has [$cardName] Card, lspci pattern:[$pattern] toolPath:[$toolPath]");

    @lspciInfos = initLspciInfo() if scalar(@lspciInfos) == 0;

    my $hasRaidCard = 0;
    foreach my $line (@lspciInfos) {
        if ($line =~ /$pattern/i) {
            chomp($line);
            myDebugLog("lspci match:[$line]");
            $hasRaidCard = 1;
            last;
        }
    }

    if (!$hasRaidCard) {
        myDebugLog("Has no $cardName Card.");
        return 0;
    }

    myDebugLog("Has $cardName Card. Check if has tool[$toolPath] I need.");

    if (!(-e $toolPath)) {
        myErrorLog("Has $cardName Card. But tool[$toolPath] not exist.");
        return 0;
    }

    myDebugLog("Has $cardName Card. And has tool[$toolPath] I need.");
    return 1;
}

# param: devName like sda
# return: wwn like 6b8ca3a0e7334300
#         "" if failed
sub getWwnByDevName {
    my ($devName) = @_;
    #udevadm info /dev/sda | grep -i "id_wwn="
    #>E: ID_WWN=0x6b8ca3a0e7334300

    myDebugLog("Get WWN for [$devName].");
    my $devPath = "/dev/$devName";

    #detect if $devpath is existed, use -e for file, -d for dir
    if (!(-e $devPath)) {
        myErrorLog("Get WWN for [$devName] failed. $devPath not exist.");
        return "";
    }

    #udevadm info --query=all --name=/dev/sda
    #my $cmd = "udevadm info $devPath | grep -i \"id_wwn=\"";
    my $cmd = "udevadm info --query=all --name=$devPath | grep -i \"id_wwn=\"";
    my $cmdRetMsg = qx($cmd);

    #$? may be set to a non-0 value if the external program fails.
    if ($? != 0) {
        myErrorLog("execute cmd:[$cmd] failed. retMsg:[$cmdRetMsg].");
        return "";
    }

    chomp($cmdRetMsg);
    myDebugLog("cmd:[$cmd] result message:[$cmdRetMsg]");

    if (!($cmdRetMsg =~ /ID_WWN\s*=\s*0x(\w+)/)) {
        myErrorLog("Get WWN for [$devName] failed. Can't get ID_WWN from cmd result.");
        return "";
    }

    my $wwn = $1;

    myDebugLog("Get WWN for [$devName] success. WWN:[$wwn]");
    return $wwn;
}

# param: devName like sda
# return: path like pci-0000:03:00.0-scsi-0:2:2:0
sub getPciPathByDevName {
    my ($devName) = @_;

    #udevadm info /dev/sdc | grep -i "id_path="
    #E: ID_PATH=pci-0000:03:00.0-scsi-0:2:2:0

    myDebugLog("Get pci path for [$devName].");
    my $devPath = "/dev/$devName";
    if (!(-e $devPath)) {
        myErrorLog("Get pci path for [$devName] failed. $devPath not exist.");
        return "";
    }

    my $cmd = "udevadm info --query=all --name=$devPath | grep -i \"id_path=\"";
    my $cmdRetMsg = qx($cmd);

    if ($? != 0) {
        myErrorLog("execute cmd:[$cmd] failed. retMsg:[$cmdRetMsg].");
        return "";
    }

    chomp($cmdRetMsg);
    myDebugLog("execute cmd:[$cmd] success. retMsg:[$cmdRetMsg].");

    if (!($cmdRetMsg =~/ID_PATH\s*=\s*([\w\-:\.]+)/)) {
        myErrorLog("Get Pci path for [$devName] failed. Can't get ID_PATH from cmd result.");
        return "";
    }

    my $pciPath = $1;

    myDebugLog("Get pci path for [$devName] success. pci path:[$pciPath]");
    return $pciPath;
}

sub printJsonRetMsg {
    my ($retCode, $retMsg) = @_;
    print("
    {
        \"retCode\": \"$retCode\",
        \"retMessage\": \"$retMsg\"
    }
    ")
}

sub printJsonRetDevInfos {
    my (@devInfos) = @_;

    my $devStr = "";
    foreach my $devInfo (@devInfos) {
        $devStr .= Class::DevInfo::toJson($devInfo).",";
    }
    if ($devStr) {
        $devStr = substr($devStr, 0, -1);
    }

    print("
    {
        \"disks\": [$devStr]
    }
    ");
}

# return: devName array
sub getAllDevNamesInSystem {
    #lsblk -i -d -P -o name,type
    #>NAME="sda" TYPE="disk"
    #>NAME="sdb" TYPE="disk"

    myDebugLog("Query all device names in System.");
    my $cmd = "lsblk -i -d -P -o name,type";
    myDebugLog("Exec cmd:[$cmd]");
    my $cmdRetMsg = qx($cmd);
    my $cmdRetCode = $?;

    myDebugLog("Exec cmd:[$cmd] retCode:[$cmdRetCode] retMsg:[$cmdRetMsg]");
    if ($cmdRetCode != 0) {
        myDebugLog("Exec cmd:[$cmd] failed.");
        return ();
    }

    my @lines = split(/[\r\n]/, $cmdRetMsg);
    my @devNames = ();
    foreach my $line (@lines) {
        chomp($line);
        #>NAME="sdb" TYPE="disk"
        if ($line =~ /NAME\s*=\s*"(\w+)"/) {
            my $devName = $1;
            myDebugLog("Find device name:[$devName]");
            push(@devNames, $devName);
        }
    }

    return @devNames;
}

sub getConfigItem {
    my ($itemName) = @_;

    myDebugLog("Read config:[$itemName]");

    my $filepath = SLOT_TOOL_CONFIG_FILEPATH;
    if (!open(CONFIGFILE, "$filepath")){
        myErrorLog("Open config file:[$filepath] failed. No such file");
        return undef;
    }

    my $itemValue = undef;
    while(my $line = <CONFIGFILE>){
        if ($line =~ /^[^#]*$itemName\s*=\s*(.+)/) {
            $itemValue = $1;
            chomp($itemValue);
            last;
        }
    }

    close(CONFIGFILE);

    if (defined $itemValue) {
        myDebugLog("Read config:[$itemName] value:[$itemValue].");
    } else {
        myDebugLog("Read config:[$itemName] failed.");
    }

    return $itemValue;
}

sub getArrayConfigItemSeparateByComma {
    my ($itemName) = @_;

    my $itemValue = getConfigItem($itemName);
    if (!(defined $itemValue)) {
        return ();
    }

    my @itemArray = split(/,/, $itemValue);

    return @itemArray;
}

sub execCmd {
    my ($cmd) = @_;
    myDebugLog("Exec cmd:[$cmd]");
    my $retMsg = qx($cmd);
    my $retCode = $?;

    if ($? == 0) {
        myDebugLog("Exec cmd:[$cmd] success. retCode:[$retCode] retMsg:[$retMsg]");
    } else {
        myErrorLog("Exec cmd:[$cmd] failed . retCode:[$retCode] retMsg:[$retMsg]");
    }

    if (!(defined $retMsg)) {
        return $retCode, ();
    }

    my @lines = split(/[\r\n]/, $retMsg);
    return $retCode, @lines;
}

sub initLspciInfo {
    myDebugLog("Init lspci infos.");
    my $cmd = "lspci -nn";
    my ($retCode, @retLines) = execCmd($cmd);

    return @retLines;
}

##################################################
# In some system, disk wwn NO. got by command "udevadm" is different from got by raid.
# Maybe have conditions below:
#   1. maybe use command "udevadm" we got "50001234", but use raid command we got "12345000";
#   2. maybe use command "udevadm" we got "5000123a", but use raid command we got "5000123c";
# So we must adapter it.
##################################################

sub wwnAdapter {
    my ($wwnQueryed) = @_;
    myDebugLog("got base wwn number: $wwnQueryed");

    my @wwnAdapterArray = ($wwnQueryed);
    # 1.maybe use command "udevadm" we got "50001234", but use raid command we got "12345000";
    {
        my $tempWwnQueryed = $wwnQueryed;
        my @tempArry = $tempWwnQueryed =~ /\w{4}/g;
        @tempArry = reverse(@tempArry);
        my $putTogether = undef;
        foreach my $element (@tempArry) {
            $putTogether .= $element;
        }
        push(@wwnAdapterArray, $putTogether);
    }

    #   2. maybe use command "udevadm" we got "5000123a", but use raid command we got "5000123c";
    {
        my $wwnTemp = substr($wwnQueryed, 0, length($wwnQueryed)-1);
        push(@wwnAdapterArray, $wwnTemp);
    }

    myDebugLog("got all wwn adapter number: @wwnAdapterArray");

    return @wwnAdapterArray;
}

1;