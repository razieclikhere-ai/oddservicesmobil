class Vehicle {
  final String id;
  final String name;
  final String brand;
  final String model;
  final int year;
  final String engineType;
  final String fuelType;
  final String transmissionType;
  final String? vin;
  final int currentMileage;
  final String? licensePlate;
  final String? color;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vehicle({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.year,
    required this.engineType,
    required this.fuelType,
    required this.transmissionType,
    this.vin,
    required this.currentMileage,
    this.licensePlate,
    this.color,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vehicle.defaultHonda() {
    return Vehicle(
      id: 'default-honda-ge8',
      name: 'My Jazz',
      brand: 'Honda',
      model: 'Jazz GE8',
      year: 2008,
      engineType: '1.5L L15A i-VTEC',
      fuelType: 'Petrol',
      transmissionType: 'Manual 5-Speed',
      vin: 'JHZGE8-SAMPLE-VIN',
      currentMileage: 150000,
      licensePlate: 'B 1234 ABC',
      color: 'Silver',
      notes: 'Default vehicle profile - Oil change every 10,000 km / 6 months',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  String get displayName => '$name ($brand $model $year)';
  String get fullSpec => '$year $brand $model - $engineType - $transmissionType';
}