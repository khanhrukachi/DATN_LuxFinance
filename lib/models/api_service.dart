import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class APIService {
  static Map<String, dynamic> parseExchangeRate(String responseBody) {
    var data = json.decode(responseBody) as Map<String, dynamic>;
    return data["rates"];
  }

  static Future<Map<String, dynamic>> getExchangeRate() async {
    try {
      // Sửa URL API tại đây
      var url = Uri.https('api.exchangerate-api.com', '/v4/latest/USD');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return compute(parseExchangeRate, response.body);
      } else {
        throw Exception('Failed to load exchange rate data');
      }
    } catch (e) {
      print("Error fetching exchange rates: $e");
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> parseCountry(String responseBody) async {
    var data = json.decode(responseBody) as Map<String, dynamic>;
    var listSymbol = await getSymbolCurrency();
    List<Map<String, dynamic>> list =
    (data["countries"]["country"] as List<dynamic>).map((e) {
      Map<String, dynamic> item = {};
      var symbol = listSymbol
          .where((element) => element["abbreviation"] == e["currencyCode"])
          .toList();
      item["countryName"] = e["countryName"];
      item["currencyCode"] = e["currencyCode"];
      item["symbol"] = symbol.isNotEmpty ? symbol[0]["symbol"] : "";
      if (item["symbol"] == null) item["symbol"] = "";
      return item;
    }).toList();
    return list;
  }

  static Future<List<Map<String, dynamic>>> getCountry() async {
    try {
      var url = Uri.https(
        'gist.githubusercontent.com',
        '/khanhrukachi/fb28e3b770ad5e70dafcac5a830fb94a/raw/600b7517c88241baf63b5d8381794b896ba3e366/countries.json',
        {'q': '{https}'},
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return compute(parseCountry, response.body);
      } else {
        throw Exception('Failed to load country data');
      }
    } catch (e) {
      print("Error fetching country data: $e");
      return [];
    }
  }

  static List<Map<String, dynamic>> parseSymbolCurrency(String responseBody) {
    var data = json.decode(responseBody) as List<dynamic>;
    List<Map<String, dynamic>> list =
    data.map((e) => e as Map<String, dynamic>).toList();
    return list;
  }

  static Future<List<Map<String, dynamic>>> getSymbolCurrency() async {
    try {
      var url = Uri.https(
        'gist.githubusercontent.com',
        '/khanhrukachi/fac7fb2d7986e6dc436845760b49e9f6/raw/b57fd2afdd192f046655afb4d9f0c57cf9dae655/currency-symbols.json',
        {'q': '{https}'},
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return compute(parseSymbolCurrency, response.body);
      } else {
        throw Exception('Failed to load symbol data');
      }
    } catch (e) {
      print("Error fetching symbol data: $e");
      return [];
    }
  }
}
