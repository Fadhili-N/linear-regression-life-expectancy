import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Life Expectancy Predictor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
        home: const PredictPage(),
      );
}

const apiUrl = 'https://linear-regression-life-expectancy.onrender.com/predict';

const fields = [
  ['year', 'Year', 2000, 2030],
  ['infant_deaths', 'Infant deaths', 0, 150],
  ['under_five_deaths', 'Under-five deaths', 0, 230],
  ['adult_mortality', 'Adult mortality', 0, 750],
  ['alcohol_consumption', 'Alcohol consumption', 0, 20],
  ['hepatitis_b', 'Hepatitis B %', 0, 100],
  ['measles', 'Measles %', 0, 100],
  ['bmi', 'BMI', 15, 35],
  ['polio', 'Polio %', 0, 100],
  ['diphtheria', 'Diphtheria %', 0, 100],
  ['incidents_hiv', 'HIV incidents', 0, 25],
  ['gdp_per_capita', 'GDP per capita', 0, 120000],
  ['population_mln', 'Population (millions)', 0, 1500],
  ['thinness_ten_nineteen_years', 'Thinness 10-19 yrs %', 0, 30],
  ['thinness_five_nine_years', 'Thinness 5-9 yrs %', 0, 30],
  ['schooling', 'Schooling (years)', 0, 16],
];

const regions = [
  'Africa', 'Asia', 'Central America and Caribbean', 'European Union',
  'Middle East', 'North America', 'Oceania', 'Rest of Europe', 'South America'
];

class PredictPage extends StatefulWidget {
  const PredictPage({super.key});
  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  final _formKey = GlobalKey<FormState>();
  static const defaults = {
    'year': '2015',
    'infant_deaths': '11.1',
    'under_five_deaths': '13',
    'adult_mortality': '105.8',
    'alcohol_consumption': '1.32',
    'hepatitis_b': '97',
    'measles': '65',
    'bmi': '27.8',
    'polio': '97',
    'diphtheria': '97',
    'incidents_hiv': '0.08',
    'gdp_per_capita': '11006',
    'population_mln': '78.53',
    'thinness_ten_nineteen_years': '4.9',
    'thinness_five_nine_years': '4.8',
    'schooling': '7.8',
  };
  final controllers = {
    for (var f in fields)
      f[0] as String: TextEditingController(text: defaults[f[0] as String] ?? '')
  };
  String? region;
  int economyDeveloped = 0;
  String result = '';
  bool loading = false;
  bool error = false;

  Future<void> predict() async {
    if (!_formKey.currentState!.validate() || region == null) {
      setState(() {
        error = true;
        result = region == null ? 'Please select a region.' : '';
      });
      return;
    }
    setState(() { loading = true; result = ''; });

    final body = {
      for (var f in fields)
        f[0]: f[0] == 'year' ? int.parse(controllers[f[0]]!.text) : double.parse(controllers[f[0]]!.text),
      'economy_status_developed': economyDeveloped,
      'region': region,
    };

    try {
      final res = await http.post(Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      final data = jsonDecode(res.body);
      setState(() {
        error = res.statusCode != 200;
        result = error ? 'Error: ${data['detail']}' : '${data['predicted_life_expectancy']} years';
      });
    } catch (_) {
      setState(() { error = true; result = 'Could not reach the server.'; });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Life Expectancy Predictor'), backgroundColor: Colors.teal, foregroundColor: Colors.white),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: region,
                decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder()),
                items: regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => region = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: economyDeveloped,
                decoration: const InputDecoration(labelText: 'Economy status', border: OutlineInputBorder()),
                items: const [DropdownMenuItem(value: 0, child: Text('Developing')), DropdownMenuItem(value: 1, child: Text('Developed'))],
                onChanged: (v) => setState(() => economyDeveloped = v ?? 0),
              ),
              const SizedBox(height: 12),
              ...fields.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: controllers[f[0]],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: '${f[1]} (${f[2]}-${f[3]})', border: const OutlineInputBorder()),
                      validator: (v) {
                        final n = num.tryParse(v ?? '');
                        if (n == null) return 'Required';
                        if (n < (f[2] as num) || n > (f[3] as num)) return 'Must be ${f[2]}-${f[3]}';
                        return null;
                      },
                    ),
                  )),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : predict,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Predict'),
                ),
              ),
              const SizedBox(height: 16),
              if (result.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: error ? Colors.red.shade50 : Colors.teal.shade50,
                  child: Text(result, style: TextStyle(fontSize: 18, color: error ? Colors.red.shade800 : Colors.teal.shade900)),
                ),
            ],
          ),
        ),
      );
}
