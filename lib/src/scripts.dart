import 'dart:convert';

abstract final class PageScripts {
  static String json(String expression) =>
      '''
(() => {
  try {
    const value = ($expression);
    if (value && typeof value.then === 'function') {
      throw new Error('Use evaluateAsyncJson for a Promise');
    }
    return JSON.stringify({ok: true, value: value === undefined ? null : value});
  } catch (error) {
    return JSON.stringify({ok: false, error: String(error)});
  }
})()
''';

  static String startAsync(String key, String expression) =>
      '''
(() => {
  const key = ${jsonEncode(key)};
  window[key] = {pending: true};
  Promise.resolve().then(() => ($expression)).then(value => {
    if (!Object.prototype.hasOwnProperty.call(window, key)) return;
    window[key] = {result: JSON.stringify({ok: true,
      value: value === undefined ? null : value})};
  }).catch(error => {
    if (!Object.prototype.hasOwnProperty.call(window, key)) return;
    window[key] = {result: JSON.stringify({ok: false, error: String(error)})};
  });
})()
''';

  static String poll(String key) =>
      'JSON.stringify(window[${jsonEncode(key)}] || {missing: true})';
  static String remove(String key) => 'delete window[${jsonEncode(key)}];';

  static String css(String css, String id) =>
      '''
(() => {
  let style = document.getElementById(${jsonEncode(id)});
  if (style && style.tagName !== 'STYLE') throw new Error('Style ID collision');
  if (!style) {
    style = document.createElement('style');
    style.id = ${jsonEncode(id)};
    (document.head || document.documentElement).appendChild(style);
  }
  style.textContent = ${jsonEncode(css)};
})()
''';

  static String find(
    String query, {
    required bool backwards,
    required bool caseSensitive,
  }) =>
      '''
(() => {
  if (typeof window.find !== 'function') {
    throw new Error('Text search is unsupported by this WebView');
  }
  return window.find(${jsonEncode(query)}, $caseSensitive, $backwards,
      true, false, false, false);
})()
''';

  static const metadata = '''
({
  title: document.title,
  url: location.href,
  description: document.querySelector('meta[name="description"]')?.content || '',
  language: document.documentElement.lang,
  scrollHeight: document.documentElement.scrollHeight,
  scrollY: window.scrollY
})
''';
}
