#!/usr/bin/perl -w
#    Copyright 2012 Merijntje Tak
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, version 3 of the License.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
##############################################################################
#
#    getSubwayEntrances.pl - Use a CSV file provided by NYC MTA to generate a 
#                             list of subway entrances which can be used in 
#                             the cityTripPlanner.pl script
#
# To use this script:
#  - Download the subway entrances CSV file from NYC OpenData (http://nycopendata.socrata.com)
#  - Enable the useExtScript function the the cityTripPlanner.pl script
#
# Example CSV:
# 1,"(40.68672833100004, -73.9902719989999)",Smith St & Bergen St At Ne Corner (To Manhattan And Queens Only),http://www.mta.info/nyct/service/,F-G
# 2,"(40.69372533200004, -73.99067800099994)",Court St & Montague St At Sw Corner,http://www.mta.info/nyct/service/,2-3-4-5-N-R
# 3,"(40.693642331000035, -73.99059199899995)",Court St & Montague St At Sw Corner,http://www.mta.info/nyct/service/,2-3-4-5-N-R
# 4,"(40.694393120000086, -73.9925373559999)",Clinton St & Montague St At Nw Corner,http://www.mta.info/nyct/service/,2-3-4-5-N-R
# 5,"(40.66272735800004, -73.96224891499992)",Flatbush Ave & Empire Blvd At Sw Corner,http://www.mta.info/nyct/service/,B-Q-S
# 6,"(40.67716435300008, -73.98339416899995)",4th Ave & Union St At Sw Corner (To Bay Ridge And Coney Island Only),http://www.mta.info/nyct/service/,D-N-R
# 7,"(40.677051636000044, -73.98308231199991)",4th Ave & Union St At Se Corner (To Manhattan Only),http://www.mta.info/nyct/service/,D-N-R
# 8,"(40.677195091000044, -73.98298999699995)",4th Ave & Union St At Se Corner (To Manhattan Only),http://www.mta.info/nyct/service/,D-N-R
# 9,"(40.680699332000074, -73.97520899999995)",Flatbush Ave & Bergen St At Sw Corner (To New Lots And Flatbush Only),http://www.mta.info/nyct/service/,2-3-4
# 10,"(40.692044114000055, -73.98621464299993)",Lawrence St & Willoughby St At Ne Corner,http://www.mta.info/nyct/service/,N-R
#

use strict;

my $csvFile = 'subwayEntrances.csv';
my %data;

open(SRCCSV, "<", $csvFile);

while (<SRCCSV>) {
  my $line = $_;

  my @fields = split(/,/, $line);

  if ( $fields[1] =~ m/([0-9]+)\.([0-9]+)/o ) {
    $data{$fields[3]}{'lat'} = $1 . '.' . $2;
  }
  if ( $fields[2] =~ m/([0-9]+)\.([0-9]+)/o ) {
    $data{$fields[3]}{'lng'} = '-' . $1 . '.' . $2 ;  # Negative because NYC is on the western hemisphere
  }

  chomp($fields[5]);
  $data{$fields[3]}{'lines'} = $fields[5];

}

close(SRCCSV);

foreach my $address ( keys(%data) ) {
  
  print $data{$address}{'lat'} . ';' . $data{$address}{'lng'} . ';' . $address . ';' . $data{$address}{'lines'} . "\n";

}
