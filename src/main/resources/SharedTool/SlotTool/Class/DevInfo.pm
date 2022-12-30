package Class::DevInfo;
use strict;
use warnings FATAL => 'all';
use FindBin '$RealBin';
use lib "$RealBin/..";
use Common;

sub newWithAllField {
    my ($devName, $wwn, $controllerId, $slotNumber, $enclosureId, $cardType, $serialNumber, $diskType) = @_;

    my $devInfo = {
        devName => $devName,
        wwn => $wwn,
        controllerId => $controllerId,
        slotNumber => $slotNumber,
        enclosureId => $enclosureId,
        cardType => $cardType,
        serialNumber => $serialNumber,
        diskType => $diskType,
    };

    return bless $devInfo;
}

sub newByWwnAdapterSlotEnclosureCardType {
    my ($wwn, $controllerId, $slotNumber, $enclosureId, $cardType, $serialNumber, $diskType) = @_;

    return newWithAllField(undef, $wwn, $controllerId, $slotNumber, $enclosureId, $cardType, $serialNumber, $diskType);
}

sub newEmpty {
    return newWithAllField(undef, undef, undef, undef, undef, undef, undef, undef);
}

sub toJson {
    my ($self) = @_;
    my $devName = defined getDevName($self) ? getDevName($self) : Common->FIELD_UNKNOWN;
    my $wwn = defined getWwn($self) ? getWwn($self) : Common->FIELD_UNKNOWN;
    my $controllerId = defined getControllerId($self) ? getControllerId($self) : Common->FIELD_UNKNOWN;
    my $slotNumber = defined getSlotNumber($self) ? getSlotNumber($self) : Common->FIELD_UNKNOWN;
    my $enclosureId = defined getEnclosureId($self) ? getEnclosureId($self) : Common->FIELD_UNKNOWN;
    my $cardType = defined getCardType($self) ? getCardType($self) : Common->FIELD_UNKNOWN;
    my $serialNumber = defined getSerialNumber($self) ? getSerialNumber($self) : Common->FIELD_UNKNOWN;
    my $diskType = defined getDiskType($self) ? getDiskType($self) : Common->FIELD_UNKNOWN;

    return
        "
        {
            \"devName\": \"$devName\",
            \"wwn\": \"$wwn\",
            \"controllerId\": \"$controllerId\",
            \"slotNumber\": \"$slotNumber\",
            \"enclosureId\": \"$enclosureId\",
            \"cardType\": \"$cardType\",
            \"serialNumber\": \"$serialNumber\",
            \"diskType\": \"$diskType\"
        }
        ";
}

sub getDevName {
    my ($self) = @_;
    return $self->{devName};
}

sub setDevName {
    my ($self, $devName) = @_;
    $self->{devName} = $devName;
}

sub getWwn {
    my ($self) = @_;
    return $self->{wwn};
}

sub getControllerId {
    my ($self) = @_;
    return $self->{controllerId};
}

sub hasControllerId {
    my ($self) = @_;
    return defined ($self->{controllerId});
}

sub getSlotNumber {
    my ($self) = @_;
    return $self->{slotNumber};
}

sub getEnclosureId {
    my ($self) = @_;
    return $self->{enclosureId};
}

sub getCardType {
    my ($self) = @_;
    return $self->{cardType};
}

sub getSerialNumber {
    my ($self) = @_;
    return $self->{serialNumber};
}

sub getDiskType {
    my ($self) = @_;
    return $self->{diskType};
}

1;