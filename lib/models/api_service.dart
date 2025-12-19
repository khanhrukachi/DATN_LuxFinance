import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class APIService {
  /// =====================
  /// EXCHANGE RATE
  /// =====================
  static Map<String, dynamic> parseExchangeRate(String responseBody) {
    final data = json.decode(responseBody) as Map<String, dynamic>;
    return data["rates"] != null
        ? Map<String, dynamic>.from(data["rates"])
        : {};
  }

  static Future<Map<String, dynamic>> getExchangeRate() async {
    try {
      final url = Uri.https('api.exchangerate-api.com', '/v4/latest/USD');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return await compute(parseExchangeRate, response.body);
      } else {
        throw Exception('Failed to load exchange rate data');
      }
    } catch (e) {
      print("Error fetching exchange rates: $e");
      return {};
    }
  }

  /// =====================
  /// COUNTRY DATA
  /// =====================
  static List<Map<String, dynamic>> parseCountrySync(String responseBody, String symbolBody) {
    final data = json.decode(responseBody) as Map<String, dynamic>;
    final listSymbol = json.decode(symbolBody) as List<dynamic>;

    final listSymbolMap = listSymbol.map((e) => e as Map<String, dynamic>).toList();

    final countries = data["countries"]["country"] as List<dynamic>;
    return countries.map((e) {
      final symbol = listSymbolMap
          .where((element) => element["abbreviation"] == e["currencyCode"])
          .toList();
      return {
        "countryName": e["countryName"],
        "currencyCode": e["currencyCode"],
        "symbol": symbol.isNotEmpty ? symbol[0]["symbol"] : "",
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getCountry() async {
    try {
      // get country data
      final urlCountry = Uri.https(
        'gist.githubusercontent.com',
        '/khanhrukachi/fb28e3b770ad5e70dafcac5a830fb94a/raw/600b7517c88241baf63b5d8381794b896ba3e366/countries.json',
      );
      final responseCountry = await http.get(urlCountry);

      // get symbol data
      final urlSymbol = Uri.https(
        'gist.githubusercontent.com',
        '/khanhrukachi/fac7fb2d7986e6dc436845760b49e9f6/raw/b57fd2afdd192f046655afb4d9f0c57cf9dae655/currency-symbols.json',
      );
      final responseSymbol = await http.get(urlSymbol);

      if (responseCountry.statusCode == 200 && responseSymbol.statusCode == 200) {
        // combine body để parse trong compute
        return await compute(_parseCountryWrapper, {
          "countryBody": responseCountry.body,
          "symbolBody": responseSymbol.body,
        });
      } else {
        throw Exception('Failed to load country or symbol data');
      }
    } catch (e) {
      print("Error fetching country data: $e");
      return [];
    }
  }

  // wrapper để compute chỉ nhận 1 argument
  static List<Map<String, dynamic>> _parseCountryWrapper(Map<String, String> bodies) {
    return parseCountrySync(bodies["countryBody"]!, bodies["symbolBody"]!);
  }

  /// =====================
  /// SYMBOL DATA
  /// =====================
  static List<Map<String, dynamic>> parseSymbolCurrency(String responseBody) {
    final data = json.decode(responseBody) as List<dynamic>;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<List<Map<String, dynamic>>> getSymbolCurrency() async {
    try {
      final url = Uri.https(
        'gist.githubusercontent.com',
        '/khanhrukachi/fac7fb2d7986e6dc436845760b49e9f6/raw/b57fd2afdd192f046655afb4d9f0c57cf9dae655/currency-symbols.json',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return await compute(parseSymbolCurrency, response.body);
      } else {
        throw Exception('Failed to load symbol data');
      }
    } catch (e) {
      print("Error fetching symbol data: $e");
      return [];
    }
  }
}
