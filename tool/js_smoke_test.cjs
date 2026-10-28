// Runs the actual JS templates embedded in lib/src/scripts.dart under Node.
// This verifies page-script behavior, not Flutter or WKWebView integration.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../lib/src/scripts.dart'), 'utf8');

function template(name) {
  const result = source.match(new RegExp(
    'static String ' + name + '\\([\\s\\S]*?=>\\s*\x27\x27\x27([\\s\\S]*?)\x27\x27\x27'));
  assert.ok(result, 'JS template exists: ' + name);
  return result[1];
}
function render(name, values) {
  let js = template(name);
  for (const [key, value] of Object.entries(values)) {
    js = js.replaceAll('${jsonEncode(' + key + ')}', JSON.stringify(value));
    js = js.replaceAll('$' + key, String(value));
  }
  return js;
}
const context = () => vm.createContext({window: {}});
const settle = () => new Promise(resolve => setImmediate(resolve));
function evaluate(expression, c = context()) {
  return JSON.parse(vm.runInContext(render('json', {expression}), c));
}

test('JSON expressions preserve objects, arrays and null', () => {
  for (const [expression, value] of [
    ['({x: [1, true, null], text: "hello"})', {x: [1, true, null], text: 'hello'}],
    ['undefined', null], ['null', null], ['42', 42], ['false', false],
    ['"hello"', 'hello'], ['NaN', null],
  ]) assert.deepEqual(evaluate(expression), {ok: true, value});
});

test('JS exceptions and non-serializable values return error envelopes', () => {
  for (const expression of ['(() => { throw new Error("boom"); })()',
    '1n', '(() => { const x = {}; x.self = x; return x; })()']) {
    const result = evaluate(expression);
    assert.equal(result.ok, false);
    assert.equal(typeof result.error, 'string');
  }
});

test('sync evaluator rejects a Promise explicitly', () => {
  assert.match(evaluate('Promise.resolve(42)').error, /evaluateAsyncJson/);
});

test('async evaluator resolves JSON-safe results', async () => {
  const c = context();
  vm.runInContext(render('startAsync', {key: 'test-key',
    expression: 'Promise.resolve({answer: 42})'}), c);
  assert.equal(c.window['test-key'].pending, true);
  await settle();
  assert.deepEqual(JSON.parse(c.window['test-key'].result),
    {ok: true, value: {answer: 42}});
});

test('async evaluator captures rejected promises and serialization failures', async () => {
  for (const expression of ['Promise.reject(new Error("boom"))',
    'Promise.resolve(1n)', '(() => { throw new Error("sync"); })()']) {
    const c = context();
    vm.runInContext(render('startAsync', {key: 'test', expression}), c);
    await settle();
    assert.equal(JSON.parse(c.window.test.result).ok, false);
  }
});

test('cleanup cannot be undone by late Promise settlement', async () => {
  const c = context();
  vm.runInContext(render('startAsync', {key: 'test',
    expression: 'new Promise(resolve => { window.finish = resolve; })'}), c);
  await settle();
  delete c.window.test;
  c.window.finish(42);
  await settle();
  assert.equal(Object.hasOwn(c.window, 'test'), false);
});

test('CSS insertion treats malicious-looking input as text and updates in place', () => {
  const elements = new Map();
  const head = {appendChild(element) { elements.set(element.id, element); }};
  const c = vm.createContext({window: {}, document: {
    head, getElementById: id => elements.get(id),
    createElement: tag => ({tagName: tag.toUpperCase()}),
  }});
  const id = 'style"; window.compromised = true; //';
  const css = 'body::before {content:"\n</style><script>bad()</script>";}';
  vm.runInContext(render('css', {id, css}), c);
  assert.equal(elements.get(id).textContent, css);
  assert.equal(c.window.compromised, undefined);
  vm.runInContext(render('css', {id, css: 'body { color: red; }'}), c);
  assert.equal(elements.size, 1);
  assert.equal(elements.get(id).textContent, 'body { color: red; }');
});

test('CSS insertion reports an ID collision', () => {
  const c = vm.createContext({document: {getElementById: () => ({tagName: 'DIV'})}});
  assert.throws(() => vm.runInContext(render('css', {id: 'x', css: 'x'}), c),
    /Style ID collision/);
});

test('search encodes the query and forwards direction and case options', () => {
  let args;
  const c = vm.createContext({window: {find(...values) { args = values; return true; }}});
  const query = '"); window.compromised=true; //';
  const result = vm.runInContext(render('find', {query,
    backwards: true, caseSensitive: false}), c);
  assert.equal(result, true);
  assert.deepEqual(args, [query, false, true, true, false, false, false]);
  assert.equal(c.window.compromised, undefined);
});

test('search reports an unsupported engine', () => {
  assert.throws(() => vm.runInContext(render('find', {
    query: 'hello', backwards: false, caseSensitive: false}), context()), /unsupported/);
});
