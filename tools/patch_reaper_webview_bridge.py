#!/usr/bin/env python3
from pathlib import Path

p=Path("reaper_webview/src/platform/macos/webview_darwin.mm")
s=p.read_text()

needle='''  if ([message.name isEqualToString:@"frzEdit"]) {'''
insert=r'''  if ([message.name isEqualToString:@"csBridge"]) {
    WebViewInstanceRecord* rec = FindInstanceForWebView(message.webView);
    NSString* payload = nil;
    if ([message.body isKindOfClass:[NSString class]]) payload = (NSString*)message.body;
    else if (message.body) payload = [message.body description];
    if (payload) {
      static unsigned long long csSeq = 0;
      ++csSeq;
      const char* utf8 = [payload UTF8String];
      char seqBuf[64];
      snprintf(seqBuf, sizeof(seqBuf), "%llu", csSeq);
      SetExtState("CompositionStudio", "ScoreBridgeMessage", utf8 ? utf8 : "", false);
      SetExtState("CompositionStudio", "ScoreBridgeSeq", seqBuf, false);
      LogF("[CompositionStudioBridge][mac] id='%s' seq=%s payload='%s'",
           rec ? rec->id.c_str() : "", seqBuf, utf8 ? utf8 : "");
    }
    return;
  }
'''
if needle not in s:
    raise SystemExit("message handler anchor not found")
s=s.replace(needle,insert+needle,1)

needle2='''  [ucc addScriptMessageHandler:g_delegate name:@"frzCtx"];
  [ucc addScriptMessageHandler:g_delegate name:@"frzEdit"];'''
repl2='''  [ucc addScriptMessageHandler:g_delegate name:@"frzCtx"];
  [ucc addScriptMessageHandler:g_delegate name:@"frzEdit"];
  [ucc addScriptMessageHandler:g_delegate name:@"csBridge"];'''
if needle2 not in s:
    raise SystemExit("handler registration anchor not found")
s=s.replace(needle2,repl2,1)

needle3='''    "reportEdit();"
  // Suppress the page's native context menu'''
repl3='''    "reportEdit();"
    "window.compositionStudioBridge={postMessage:function(x){"
      "try{window.webkit.messageHandlers.csBridge.postMessage(typeof x==='string'?x:JSON.stringify(x));return true;}catch(_){return false;}"
    "}};"
  // Suppress the page's native context menu'''
if needle3 not in s:
    raise SystemExit("injected JS anchor not found")
s=s.replace(needle3,repl3,1)

p.write_text(s)
print("Composition Studio bridge patch applied")


# Add WEBVIEW_Eval(instance, javascript) so Composition Studio can update
# an already open score without navigating/reloading the WebView.
p=Path("reaper_webview/src/api.mm")
s=p.read_text()

s=s.replace(
'''#else
#import <AppKit/AppKit.h>
#endif''',
'''#else
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#endif''',
1)

s=s.replace(
'''static void* Vararg_WEBVIEW_Navigate(void** arglist, int numparms);''',
'''static void* Vararg_WEBVIEW_Navigate(void** arglist, int numparms);
static void* Vararg_WEBVIEW_Eval(void** arglist, int numparms);''',
1)

anchor='''// ----- Example placeholder for future API -----'''
impl=r'''
void API_WEBVIEW_Eval(const char* instance, const char* javascript)
{
#ifdef __APPLE__
  if (!javascript || !*javascript) return;
  std::string raw = (instance && *instance) ? instance : "wv_default";
  std::string normalized = NormalizeInstanceId(raw, nullptr);
  WebViewInstanceRecord* rec = GetInstanceById(normalized);
  if (!rec || !rec->webView) return;
  @autoreleasepool {
    NSString* script = [NSString stringWithUTF8String:javascript];
    if (!script) return;
    [rec->webView evaluateJavaScript:script completionHandler:nil];
  }
#else
  (void)instance; (void)javascript;
#endif
}

'''
if anchor not in s:
    raise SystemExit("api implementation anchor not found")
s=s.replace(anchor,impl+anchor,1)

anchor2='''// -------------------- API list definition --------------------'''
wrapper=r'''
static void* Vararg_WEBVIEW_Eval(void** arglist, int numparms)
{
  const char* instance = (numparms > 0 && arglist[0]) ? (const char*)arglist[0] : nullptr;
  const char* javascript = (numparms > 1 && arglist[1]) ? (const char*)arglist[1] : nullptr;
  API_WEBVIEW_Eval(instance, javascript);
  return nullptr;
}

'''
if anchor2 not in s:
    raise SystemExit("api wrapper anchor not found")
s=s.replace(anchor2,wrapper+anchor2,1)

help_anchor='''static ApiRegistrationInfo g_api_list[] = {'''
help_eval=r'''
#define HELP_EVAL \
"WEBVIEW_Eval(instance, javascript)\n" \
"  Execute JavaScript in an existing WebView instance without navigation.\n" \
"  instance: instance id such as 'wv_composition_studio_notation'.\n" \
"  javascript: source code to evaluate in the page.\n"

'''
if help_anchor not in s:
    raise SystemExit("api list anchor not found")
s=s.replace(help_anchor,help_eval+help_anchor,1)

s=s.replace(
'''  { "WEBVIEW_Navigate", "void", "const char*,const char*", "url,opts", HELP_NAV, &API_WEBVIEW_Navigate, &Vararg_WEBVIEW_Navigate, nullptr },
  // Add new API entries here''',
'''  { "WEBVIEW_Navigate", "void", "const char*,const char*", "url,opts", HELP_NAV, &API_WEBVIEW_Navigate, &Vararg_WEBVIEW_Navigate, nullptr },
  { "WEBVIEW_Eval", "void", "const char*,const char*", "instance,javascript", HELP_EVAL, &API_WEBVIEW_Eval, &Vararg_WEBVIEW_Eval, nullptr },
  // Add new API entries here''',
1)

p.write_text(s)
print("Composition Studio WEBVIEW_Eval API patch applied")
