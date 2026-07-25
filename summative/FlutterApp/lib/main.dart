import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const LifeExpectancyApp());
}

class LifeExpectancyApp extends StatelessWidget {
  const LifeExpectancyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life Expectancy Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  static const String apiUrl =
      'https://linear-regression-life-expectancy.onrender.com/predict';

  final _formKey = GlobalKey<FormState>();

  // Controllers for each numeric field
  final Map<String, TextEditingController> controllers = {
    'year': TextEditingController(text: '2015'),
    'infant_deaths': TextEditingController(),
    'under_five_deaths': TextEditingController(),
    'adult_mortality': TextEditingController(),
    'alcohol_consumption': TextEditingController(),
    'hepatitis_b': TextEditingController(),
    'measles': TextEditingController(),
    'bmi': TextEditingController(),
    'polio': TextEditingController(),
    'diphtheria': TextEditingController(),
    'incidents_hiv': TextEditingController(),
    'gdp_per_capita': TextEditingController(),
    'population_mln': TextEditingController(),
    'thinness_ten_nineteen_years': TextEditingController(),
    'thinness_five_nine_years': TextEditingController(),
    'schooling': TextEditingController(),
  };

  // Field metadata: label, min, max
  final List<Map<String, dynamic>> fields = [
    {'key': 'year', 'label': 'Year', 'min': 2000, 'max': 2030},
    {'key': 'infant_deaths', 'label': 'Infant deaths (per 1000)', 'min': 0, 'max': 150},
    {'key': 'under_five_deaths', 'label': 'Under-five deaths (per 1000)', 'min': 0, 'max': 230},
    {'key': 'adult_mortality', 'label': 'Adult mortality rate', 'min': 0, 'max': 750},
    {'key': 'alcohol_consumption', 'label': 'Alcohol consumption (L)', 'min': 0, 'max': 20},
    {'key': 'hepatitis_b', 'label': 'Hepatitis B immunization (%)', 'min': 0, 'max': 100},
    {'key': 'measles', 'label': 'Measles immunization (%)', 'min': 0, 'max': 100},
    {'key': 'bmi', 'label': 'Average BMI', 'min': 15, 'max': 35},
    {'key': 'polio', 'label': 'Polio immunization (%)', 'min': 0, 'max': 100},
    {'key': 'diphtheria', 'label': 'Diphtheria immunization (%)', 'min': 0, 'max': 100},
    {'key': 'incidents_hiv', 'label': 'HIV incidents (per 1000)', 'min': 0, 'max': 25},
    {'key': 'gdp_per_capita', 'label': 'GDP per capita (USD)', 'min': 0, 'max': 120000},
    {'key': 'population_mln', 'label': 'Population (millions)', 'min': 0, 'max': 1500},
    {'key': 'thinness_ten_nineteen_years', 'label': 'Thinness % (ages 10-19)', 'min': 0, 'max': 30},
    {'key': 'thinness_five_nine_years', 'label': 'Thinness % (ages 5-9)', 'min': 0, 'max': 30},
    {'key': 'schooling', 'label': 'Average years of schooling', 'min': 0, 'max': 16},
  ];

  final List<String> regions = const [
    'Africa',
    'Asia',
    'Central America and Caribbean',
    'European Union',
    'Middle East',
    'North America',
    'Oceania',
    'Rest of Europe',
    'South America',
  ];

  String? selectedRegion;
  int economyStatus = 0; // 0 = Developing, 1 = Developed

  bool isLoading = false;
  String resultText = '';
  bool isError = false;

  Future<void> predict() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (selectedRegion == null) {
      setState(() {
        isError = true;
        resultText = 'Please select a region before predicting.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      resultText = '';
      isError = false;
    });

    final Map<String, dynamic> body = {
      'year': int.parse(controllers['year']!.text),
      'infant_deaths': double.parse(controllers['infant_deaths']!.text),
      'under_five_deaths': double.parse(controllers['under_five_deaths']!.text),
      'adult_mortality': double.parse(controllers['adult_mortality']!.text),
      'alcohol_consumption': double.parse(controllers['alcohol_consumption']!.text),
      'hepatitis_b': double.parse(controllers['hepatitis_b']!.text),
      'measles': double.parse(controllers['measles']!.text),
      'bmi': double.parse(controllers['bmi']!.text),
      'polio': double.parse(controllers['polio']!.text),
      'diphtheria': double.parse(controllers['diphtheria']!.text),
      'incidents_hiv': double.parse(controllers['incidents_hiv']!.text),
      'gdp_per_capita': double.parse(controllers['gdp_per_capita']!.text),
      'population_mln': double.parse(controllers['population_mln']!.text),
      'thinness_ten_nineteen_years':
          double.parse(controllers['thinness_ten_nineteen_years']!.text),
      'thinness_five_nine_years':
          double.parse(controllers['thinness_five_nine_years']!.text),
      'schooling': double.parse(controllers['schooling']!.text),
      'economy_status_developed': economyStatus,
      'region': selectedRegion,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          isError = false;
          resultText =
              '${data['predicted_life_expectancy']} years';
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          isError = true;
          resultText = 'Error: ${data['detail'].toString()}';
        });
      }
    } catch (e) {
      setState(() {
        isError = true;
        resultText = 'Could not reach the server. Check your internet connection.';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Expectancy Predictor'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Enter health and economic indicators to predict life expectancy.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),

              // Region dropdown
              DropdownButtonFormField<String>(
                initialValue: selectedRegion,
                decoration: const InputDecoration(labelText: 'Region'),
                items: regions
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (value) => setState(() => selectedRegion = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Economy status dropdown
              DropdownButtonFormField<int>(
                initialValue: economyStatus,
                decoration: const InputDecoration(labelText: 'Economy status'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Developing')),
                  DropdownMenuItem(value: 1, child: Text('Developed')),
                ],
                onChanged: (value) => setState(() => economyStatus = value ?? 0),
              ),
              const SizedBox(height: 12),

              // Numeric fields
              ...fields.map((field) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: controllers[field['key']],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '${field['label']} (${field['min']}-${field['max']})',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final num? parsed = num.tryParse(value);
                      if (parsed == null) {
                        return 'Enter a valid number';
                      }
                      if (parsed < field['min'] || parsed > field['max']) {
                        return 'Must be between ${field['min']} and ${field['max']}';
                      }
                      return null;
                    },
                  ),
                );
              }),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : predict,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Predict', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),

              // Result display
              if (resultText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isError ? Colors.red.shade50 : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isError ? Colors.red.shade200 : Colors.teal.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isError ? 'Error' : 'Predicted Life Expectancy',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isError ? Colors.red.shade800 : Colors.teal.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        resultText,
                        style: TextStyle(
                          fontSize: isError ? 14 : 22,
                          color: isError ? Colors.red.shade800 : Colors.teal.shade900,
                          fontWeight: isError ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
