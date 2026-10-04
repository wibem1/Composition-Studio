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
