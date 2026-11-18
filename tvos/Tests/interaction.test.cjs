const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(require('node:path').join(__dirname, '../App/Interaction.js'), 'utf8');
function fixture(element, child = false) {
  const calls = [], handlers = {};
  const window = {open: () => 'popup', addEventListener: (k, fn) => handlers[k] = fn,
    scrollBy: (...args) => calls.push(['scroll', ...args]),
    webkit: {messageHandlers: {tv: {postMessage: x => calls.push(x)}}}};
  const originalOpen = window.open;
  const parent = child ? {} : window;
  vm.runInNewContext(source, {window, parent, top: parent, innerWidth: 1000, innerHeight: 500,
    document: {elementFromPoint: (x,y) => {calls.push(['hit',x,y]); return element;}, querySelector: () => null},
    MouseEvent: class {constructor(type) {this.type = type;}}, getComputedStyle: () => ({overflowY:'auto'})});
  return {window, calls, handlers, parent, originalOpen};
}
test('player window.open is preserved and normalized cursor clicks the element', () => {
  const events = [];
  const f = fixture({focus(){},dispatchEvent:e=>events.push(e.type), click:()=>events.push('click')});
  assert.equal(f.window.open, f.originalOpen);
  f.window.__tvAct({kind:'click', x:.25, y:.5});
  assert.deepEqual(f.calls[0], ['hit',250,250]);
  assert.deepEqual(events, ['mousedown','mouseup','click']);
});
test('iframe hit is translated into child coordinates', () => {
  let sent;
  const f = fixture({tagName:'IFRAME', clientLeft:0,clientTop:0,clientWidth:500,clientHeight:250,
    getBoundingClientRect:()=>({left:100,top:50}), contentWindow:{postMessage:x=>sent=x}});
  f.window.__tvAct({kind:'click',x:.35,y:.35});
  assert.equal(sent.x,.5); assert.equal(sent.y,.5);
});
test('child frame rejects unrelated window messages', () => {
  let clicked = 0;
  const f = fixture({click:()=>clicked++,dispatchEvent(){}}, true);
  const data = {channel:'__CHANNEL__',kind:'click',x:.5,y:.5};
  f.handlers.message({source:{},data});
  assert.equal(clicked,0);
  f.handlers.message({source:f.parent,data});
  assert.equal(clicked,1);
});
test('scroll uses nested scrollable element', () => {
  let delta;
  const f = fixture({scrollHeight:1000,clientHeight:100,scrollBy:(...a)=>delta=a});
  f.window.__tvAct({kind:'scroll',x:.5,y:.5,dx:0,dy:200});
  assert.deepEqual(delta,[0,200]);
});
test('native video handoff rejects blob URLs', () => {
  const f = fixture({closest:()=>({currentSrc:'blob:https://example.com/id'})});
  f.window.__tvAct({kind:'video',x:.5,y:.5});
  assert.equal(f.calls.at(-1).kind,'notice');
});
test('direct media handoff pauses inline video', () => {
  let paused = false;
  const f = fixture({closest:()=>({currentSrc:'https://media.example/live.m3u8',pause:()=>paused=true})});
  f.window.__tvAct({kind:'video',x:.5,y:.5});
  assert.equal(paused,true); assert.equal(f.calls.at(-1).kind,'video');
});
test('ad host rules block listed hosts without blocking unrelated media', () => {
  const rules = JSON.parse(fs.readFileSync(require('node:path').join(__dirname, '../App/AdRules.json'), 'utf8'));
  const blocked = url => rules.some(r => new RegExp(r.trigger['url-filter']).test(url));
  assert.equal(blocked('https://ads.doubleclick.net/ad.js'),true);
  assert.equal(blocked('https://popads.net/ad.js'),true);
  assert.equal(blocked('https://media.example/live.m3u8'),false);
  assert.equal(blocked('https://embedse.com/m/abc'),false);
  assert.equal(blocked('https://doubleclick.net.example/video.m3u8'),false);
});

test('child player frame keeps its original window.open', () => {
  const f = fixture({}, true);
  assert.equal(f.window.open, f.originalOpen);
});

test('player wrapper has no sandbox attribute and native popup rejection remains', () => {
  const native = fs.readFileSync(require('node:path').join(__dirname, '../App/main.m'), 'utf8');
  const iframe = native.match(/<iframe\b[^>]*>/);
  assert.ok(iframe);
  assert.doesNotMatch(iframe[0], /\bsandbox\b/i);
  assert.match(native, /createWebViewWithConfiguration:[^\n]+return nil;/);
});