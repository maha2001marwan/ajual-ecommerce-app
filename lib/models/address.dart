import 'package:cloud_firestore/cloud_firestore.dart';

/// A delivery address stored at `users/{uid}/addresses/{id}`.
class Address {
  const Address({
    required this.id,
    required this.country,
    required this.firstName,
    required this.lastName,
    required this.phoneCode,
    required this.phone,
    required this.line1,
    required this.state,
    required this.city,
    required this.postalCode,
    this.company = '',
    this.line2 = '',
    this.isDefault = false,
    this.updatedAt,
  });

  final String id;
  final String country;
  final String firstName;
  final String lastName;
  final String company;
  final String phoneCode;
  final String phone;
  final String line1;
  final String line2;
  final String state;
  final String city;
  final String postalCode;
  final bool isDefault;
  final DateTime? updatedAt;

  String get fullName => '$firstName $lastName'.trim();
  String get fullPhone => '$phoneCode $phone'.trim();

  String get singleLine => [
    line1,
    line2,
    city,
    state,
    postalCode,
  ].where((part) => part.trim().isNotEmpty).join(', ');

  Address copyWith({String? id, bool? isDefault}) => Address(
    id: id ?? this.id,
    country: country,
    firstName: firstName,
    lastName: lastName,
    company: company,
    phoneCode: phoneCode,
    phone: phone,
    line1: line1,
    line2: line2,
    state: state,
    city: city,
    postalCode: postalCode,
    isDefault: isDefault ?? this.isDefault,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'country': country,
    'firstName': firstName,
    'lastName': lastName,
    'company': company,
    'phoneCode': phoneCode,
    'phone': phone,
    'line1': line1,
    'line2': line2,
    'state': state,
    'city': city,
    'postalCode': postalCode,
    'isDefault': isDefault,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Snapshot embedded into an order so later edits don't change history.
  Map<String, dynamic> toOrderMap() => {
    ...toMap()..remove('updatedAt'),
    'id': id,
  };

  factory Address.fromMap(String id, Map<String, dynamic> map) {
    final updated = map['updatedAt'];
    return Address(
      id: id,
      country: map['country'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      company: map['company'] as String? ?? '',
      phoneCode: map['phoneCode'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      line1: map['line1'] as String? ?? '',
      line2: map['line2'] as String? ?? '',
      state: map['state'] as String? ?? '',
      city: map['city'] as String? ?? '',
      postalCode: map['postalCode'] as String? ?? '',
      isDefault: map['isDefault'] as bool? ?? false,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }
}

/// Demo region data for the address form dropdowns.
class Regions {
  Regions._();

  static const Map<String, String> phoneCodes = {
    'United Kingdom (UK)': 'UK +44',
    'United States (US)': 'US +1',
    'Palestine (PS)': 'PS +970',
    'Jordan (JO)': 'JO +962',
    'United Arab Emirates (AE)': 'AE +971',
  };

  static const Map<String, Map<String, List<String>>> states = {
    'United Kingdom (UK)': {
      'England': ['London', 'Manchester', 'Birmingham', 'Liverpool'],
      'Scotland': ['Edinburgh', 'Glasgow', 'Aberdeen'],
      'Wales': ['Cardiff', 'Swansea'],
      'Northern Ireland': ['Belfast', 'Derry'],
    },
    'United States (US)': {
      'California': ['Los Angeles', 'San Francisco', 'San Diego'],
      'New York': ['New York City', 'Buffalo', 'Albany'],
      'Texas': ['Houston', 'Austin', 'Dallas'],
    },
    'Palestine (PS)': {
      'West Bank': ['Ramallah', 'Nablus', 'Hebron', 'Bethlehem', 'Jenin'],
      'Gaza Strip': ['Gaza', 'Khan Yunis', 'Rafah', 'Deir al-Balah'],
      'Jerusalem': ['Jerusalem'],
    },
    'Jordan (JO)': {
      'Amman': ['Amman', 'Wadi as-Sir'],
      'Irbid': ['Irbid', 'Ramtha'],
      'Zarqa': ['Zarqa', 'Russeifa'],
    },
    'United Arab Emirates (AE)': {
      'Dubai': ['Dubai'],
      'Abu Dhabi': ['Abu Dhabi', 'Al Ain'],
      'Sharjah': ['Sharjah'],
    },
  };

  static List<String> get countries => states.keys.toList();

  static List<String> statesOf(String country) =>
      states[country]?.keys.toList() ?? const [];

  static List<String> citiesOf(String country, String state) =>
      states[country]?[state] ?? const [];
}
