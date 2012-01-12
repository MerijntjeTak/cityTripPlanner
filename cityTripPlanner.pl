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
#    cityTripPlanner.pl - Convert a list of addresses to a bunch of Google Maps markers
#
#    For full information, please view the README file

use strict;
use LWP::Simple;
use HTML::Entities;
use JSON;

my $xmlName = 'cityTripPlanner';                   # Name shown in Google maps
my $xmlDesc = '';                                  # Optional description
my $addressListTxt = 'addressList.txt';            # Input address list
my $outputXml = '/path/to/webroot/output.kml';     # Output XML file
my $acceptColons = 1;                   # use colons ":" as well as semicolons ";" as delimiter in the addressList?

# You can define categories here (which you can use in the address list file), and associate an icon with them
my %categoryIcons;
$categoryIcons{"Architecture"} = 'http://maps.google.com/mapfiles/kml/pushpin/blue-pushpin.png';
$categoryIcons{"Sightseeing"}  = 'http://maps.google.com/mapfiles/kml/pushpin/red-pushpin.png';
$categoryIcons{"Food"}         = 'http://maps.google.com/mapfiles/kml/pushpin/grn-pushpin.png';
$categoryIcons{"Shopping"}     = 'http://maps.google.com/mapfiles/kml/pushpin/pink-pushpin.png';
$categoryIcons{"Subway"}       = 'http://maps.google.com/mapfiles/kml/pushpin/ylw-pushpin.png';
#categoryIcons{"category"}     = 'http://maps.google.com/mapfiles/kml/pushpin/purple-pushpin.png';
#categoryIcons{"category"}     = 'http://maps.google.com/mapfiles/kml/pushpin/ltblu-pushpin.png';
#categoryIcons{"category"}     = 'http://maps.google.com/mapfiles/kml/pushpin/wht-pushpin.png';


####################################################################################################

#
# main - Main routine for the program
#
sub main {
  my(@poiCat,%data);
  my $poiCat_ref = \@poiCat;
  my $data_ref = \%data;
  
  readConfig($data_ref, $addressListTxt);
  createCategoryList($data_ref, $poiCat_ref);
  
  foreach my $poiName ( keys(%$data_ref) ) {
  
    my $poi_ref = $$data_ref{$poiName};
  
    fetchGeocodingJSON($poi_ref);
  
    getGeocodingResult($poi_ref);
  
  }
  
  outputXml($data_ref, $poiCat_ref);

}

#
# readConfig - Read address list file
#
# Output: reference to a hash that contains the data in the address list file
sub readConfig {
  my $data_ref = shift;
  my $addressList = shift;

  open(LIST, "<", $addressList) or die "Error: Could not open \$addressListTxt: $addressListTxt $!";
  while (<LIST>) {
    my $line = $_;
    chomp($line);

    if ( $line =~ m/^#/o ) { next; }
    if ( $line =~ m/^$/o ) { next; }

    my $delimiter;
    if ( $acceptColons == 1 ) {
      $delimiter = '[:;]';
    } else {
      $delimiter = '[;]';
    }
    
    if ( $line =~ m/.*${delimiter}.*${delimiter}.*/o ) {

      my @fields = split(/${delimiter}/, $line);

      $$data_ref{$fields[0]}{'adr'} = $fields[1]; # Address
      $$data_ref{$fields[0]}{'cat'} = $fields[2]; # Category

    }

  }
  close(LIST);

}

#
# fetchGeocodingJSON - Get geocoding JSON result from Google api
#
# Output:
#  - Multiline string containing the result XML for a geocode request
#
sub fetchGeocodingJSON {
  my $poi_ref = shift;

  # Replace spaces in address
  $$poi_ref{'apiAdr'} = $$poi_ref{'adr'};
  $$poi_ref{'apiAdr'} =~ s/ /\+/g;

  # First wait for 0.25s, otherwise we hit Google's query limit
  select(undef, undef, undef, 0.25);

  my $url = 'http://maps.googleapis.com/maps/api/geocode/json?address='.$$poi_ref{'apiAdr'}.'&sensor=false';
  if ( my $content = get($url) ) {

    if ( $content =~ m/ZERO_RESULTS/ ) {

      print "Error: No results found for address $$poi_ref{'adr'}\n";
      exit(1);

    } elsif ( $content =~ m/OVER_QUERY_LIMIT/ ) {

      print "Error: You have reached the Google maps API query limit\n";
      exit(1);

    } else {

      $$poi_ref{'geocodeJSON'} = $content;
      return(0);

    }

  } else {

    $$poi_ref{'geocodeJSON'} = "Error: Unable to get geocoding JSON\n";
    exit(1);

  }

}

#
# getGeocodingResult - Get the relevant data from the geocodeJSON function
#
# Input: 
#  - Output of the fetchGeocodingJSON function
#
# Output:
#  - Latitude
#  - Longitude
#  - Proper address as provided by Google
#
sub getGeocodingResult {
  my $poi_ref = shift;

  my $jsonRawResult = decode_json($$poi_ref{'geocodeJSON'});

  my @jsonResults;

  # Some magic taken from Google::GeoCoder::Smart to handle the JSON data
  foreach my $result ( $jsonRawResult->{results}[0] ) {

    my @pushArray = ($result);
    push(@jsonResults, @pushArray);

  }

  $$poi_ref{'lat'} = $jsonResults[0]{'geometry'}{'location'}{'lat'};
  $$poi_ref{'lng'} = $jsonResults[0]{'geometry'}{'location'}{'lng'};
  $$poi_ref{'address'} = $jsonResults[0]{'formatted_address'};
  
}

#
# outputXml - Output all data to a KML formatted file
#
# Input:
#  - Output of the getGeocodingResult function (lat, lng, address)
#  - List of poi categories (poiCat_ref)
#
# Output:
#  - XML output of the data, to the file $outputXml
#
sub outputXml {
  my $data_ref = shift;
  my $poiCat_ref = shift;

  sub printLine {
    my $line = shift;
    print OUTPUT $line . "\n";
  }

  open(OUTPUT, ">", $outputXml) or die "Error: Could not open \$outputXml $outputXml $!";
  
  printLine '<?xml version="1.0" encoding="UTF-8"?>';
  printLine '<kml xmlns="http://www.opengis.net/kml/2.2">';
  printLine '<Document>';
  printLine ' <name>' . encode_entities($xmlName) . '</name>';
  printLine ' <description>' . encode_entities($xmlDesc) . '</description>';

  # Create the styles for the different color icons
  foreach my $style ( keys(%categoryIcons) ) {
    printLine '  <Style id="' . encode_entities($style) . '">';
    printLine '   <IconStyle>';
    printLine '    <Icon>';
    printLine '     <href>' . encode_entities($categoryIcons{$style}) . '</href>';
    printLine '    </Icon>';
    printLine '   </IconStyle>';
    printLine '  </Style>';
  }

  foreach my $category (@$poiCat_ref) {

    printLine '  <Folder>';
    printLine '   <name>' . encode_entities($category) . '</name>';
    printLine '   <description></description>';

    foreach my $poiName ( keys(%$data_ref) ) {
      my $poi_ref = $$data_ref{$poiName};

      # Skip to next poi if category doesn't match the current category
      if ( $$poi_ref{'cat'} ne $category ) {
       next;
      }

      printLine '  <Placemark>';
      printLine '   <name>' . encode_entities($poiName) . '</name>';
      printLine '   <description>' . encode_entities($$poi_ref{'address'}) . '</description>';
      printLine '   <styleUrl>#' . encode_entities($$poi_ref{'cat'}) . '</styleUrl>';
      printLine '   <Point>';
      printLine '    <coordinates>' . $$poi_ref{'lng'} . ',' . $$poi_ref{'lat'} . ',0</coordinates>';
      printLine '   </Point>';
      printLine '  </Placemark>';

    }

    printLine '  </Folder>';

  }

  printLine '</Document>';
  printLine '</kml>';

  close(OUTPUT);

}

#
# createCategoryList - Create a list of categories out of all addresslist entries
#
# Input:
#  - All addresslist entries
#
# Output:
#  - Array containing unique categories
#
sub createCategoryList {
  my $data_ref = shift;
  my $poiCat_ref = shift;

  my %tmpdata;

  foreach my $poiName ( keys(%$data_ref) ) {
    $tmpdata{$$data_ref{$poiName}{'cat'}} = 1;
  }

  foreach my $category ( keys(%tmpdata) ) {
    push(@$poiCat_ref, $category);
  }

}

# Run the main routine
main;


