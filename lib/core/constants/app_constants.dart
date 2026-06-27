class AppConstants {
  static const String appName = 'Smart OBD Service Assistant';
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  static const int scanTimeoutSeconds = 30;
  static const int defaultScanIntervalMileage = 10000; // km
  static const int defaultScanIntervalMonths = 6;

  static const Map<String, String> standardPids = {
    '0100': 'PIDs Supported [01-20]',
    '0101': 'Monitor Status Since DTCs Cleared',
    '0102': 'Freeze Frame DTC',
    '0103': 'Fuel System Status',
    '0104': 'Calculated Engine Load',
    '0105': 'Engine Coolant Temperature',
    '0106': 'Short Term Fuel Trim - Bank 1',
    '0107': 'Long Term Fuel Trim - Bank 1',
    '010C': 'Engine RPM',
    '010D': 'Vehicle Speed',
    '010E': 'Timing Advance',
    '010F': 'Intake Air Temperature',
    '0111': 'Throttle Position',
    '011F': 'Run Time Since Engine Start',
    '012F': 'Fuel Level Input',
    '0133': 'Absolute Barometric Pressure',
    '0142': 'Control Module Voltage',
  };

  static const Map<String, String> dtcPrefixes = {
    'P': 'Powertrain (Engine/Transmission)',
    'B': 'Body (Airbags/Comfort)',
    'C': 'Chassis (ABS/Suspension)',
    'U': 'Network (Communication)',
  };
}