import 'dart:convert';

String formatJson(String jsonStr) {
  try {
    final jsonObject = jsonDecode(jsonStr);

    const encoder = JsonEncoder.withIndent('  ');

    return encoder.convert(jsonObject);
  } catch (e) {
    // Falls es kein gültiges JSON ist
    return jsonStr;
  }
}
