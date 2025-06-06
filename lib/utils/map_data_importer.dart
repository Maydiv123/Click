import '../models/map_location.dart';
import '../services/map_service.dart';

class MapDataImporter {
  final MapService _mapService = MapService();

  // Import a single map location
  Future<void> importMapLocation({
    required String zone,
    required String salesArea,
    required String coClDo,
    required String district,
    required String sapCode,
    required String customerName,
    required String location,
    required String addressLine1,
    required String addressLine2,
    required String addressLine3,
    required String addressLine4,
    required String pincode,
    required String dealerName,
    required String contactDetails,
    required double latitude,
    required double longitude,
  }) async {
    final mapLocation = MapLocation(
      zone: zone,
      salesArea: salesArea,
      coClDo: coClDo,
      district: district,
      sapCode: sapCode,
      customerName: customerName,
      location: location,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      addressLine3: addressLine3,
      addressLine4: addressLine4,
      pincode: pincode,
      dealerName: dealerName,
      contactDetails: contactDetails,
      latitude: latitude,
      longitude: longitude,
    );

    await _mapService.addMapLocation(mapLocation);
  }

  // Example of importing the sample data
  Future<void> importSampleData() async {
    await importMapLocation(
      zone: 'NORTH WEST FRONTIER ZONE',
      salesArea: 'UDAIPUR RETAIL SA',
      coClDo: 'CO',
      district: 'UDAIPUR',
      sapCode: '41049691',
      customerName: 'M/s.MODERN SERVICE STATION',
      location: 'UDAIPUR',
      addressLine1: 'HP PETROL PUMP',
      addressLine2: 'HOSPITAL ROAD',
      addressLine3: 'UDAIPUR',
      addressLine4: 'UDAIPUR',
      pincode: '313001',
      dealerName: 'Surendra Kumar Nahar',
      contactDetails: '8949495349',
      latitude: 24.589795,
      longitude: 73.695265,
    );
  }

  // Import data from a CSV string
  Future<void> importFromCSV(String csvData) async {
    final lines = csvData.split('\n');
    // Skip header row
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final values = line.split('\t'); // Assuming tab-separated values
      if (values.length < 16) continue; // Skip invalid lines

      try {
        await importMapLocation(
          zone: values[0],
          salesArea: values[1],
          coClDo: values[2],
          district: values[3],
          sapCode: values[4],
          customerName: values[5],
          location: values[6],
          addressLine1: values[7],
          addressLine2: values[8],
          addressLine3: values[9],
          addressLine4: values[10],
          pincode: values[11],
          dealerName: values[12],
          contactDetails: values[13],
          latitude: double.parse(values[14]),
          longitude: double.parse(values[15]),
        );
      } catch (e) {
        print('Error importing line $i: $e');
        continue;
      }
    }
  }
} 