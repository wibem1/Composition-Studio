#!/usr/bin/env node
'use strict';
// Local adapter to the shared Composition Engine. No music decisions are made here.
const fs=require('node:fs'),vm=require('node:vm');
const [enginePath,inputPath,outputPath]=process.argv.slice(2);
if(!enginePath||!inputPath||!outputPath){console.error('Usage: node engine-bridge.js ENGINE.js AI-ANSWER.txt OUTPUT.cs');process.exit(2)}
try {
 const sandbox={window:{},TextEncoder,TextDecoder,Uint8Array,ArrayBuffer,DataView,structuredClone,crypto:require('node:crypto').webcrypto};
 vm.createContext(sandbox);
 vm.runInContext(fs.readFileSync(enginePath,'utf8'),sandbox,{filename:enginePath,timeout:10000});
 const engine=sandbox.window.CompositionEngine;
 if(!engine||typeof engine.findScore!=='function'||typeof engine.extractJson!=='function')throw Error('Composition Engine: JSON API fehlt.');
 const score=engine.findScore(engine.extractJson(fs.readFileSync(inputPath,'utf8')));
 const ts=score.timeSignature||[4,4],bpm=Number(score.bpm),numer=Number(ts[0]),denom=Number(ts[1]);
 if(!Number.isFinite(bpm)||bpm<=0||!Number.isInteger(numer)||numer<1||!Number.isInteger(denom)||denom<1)throw Error('Ungültiges Tempo oder Taktmaß.');
 if(!Array.isArray(score.tracks)||!score.tracks.length)throw Error('Partitur ohne Spuren.');
 const out=['CSMETA|tempo|0|'+bpm,'CSMETA|timesig|0|'+numer+'|'+denom];
 let count=0;
 for(const [i,tr] of score.tracks.entries()){
  const name=String(tr.name||'Instrument '+(i+1)).replace(/[|\r\n]/g,' ').trim();
  const program=Number(tr.program??0),channel=Number(tr.channel??(i%16));
  if(!Number.isInteger(program)||program<0||program>127||!Number.isInteger(channel)||channel<0||channel>15)throw Error('Ungültiger MIDI-Program/Kanal in Spur '+(i+1));
  if(!Array.isArray(tr.notes))throw Error('Notenliste fehlt in Spur '+(i+1));
  const notes=[];
  for(const [j,n] of tr.notes.entries()){
   if(!Array.isArray(n)||n.length<4)throw Error('Ungültige Note in Spur '+(i+1)+', #'+(j+1));
   const [start,duration,pitch,velocity]=n.map(Number);
   if(![start,duration,pitch,velocity].every(Number.isFinite)||start<0||duration<=0||!Number.isInteger(pitch)||pitch<0||pitch>127||!Number.isInteger(velocity)||velocity<1||velocity>127)throw Error('Ungültige MIDI-Werte in Spur '+(i+1)+', #'+(j+1));
   notes.push([start,duration,pitch,velocity,channel].join(','));count++;
  }
  if(notes.length)out.push('CS|new|-|'+name+'|'+program+'|'+notes.join(';'));
 }
 if(!count)throw Error('Keine Noten erzeugt.');
 fs.writeFileSync(outputPath,out.join('\n')+'\n','utf8');
 console.log('Engine '+engine.version+': '+count+' MIDI notes');
} catch(e){console.error(e.stack||String(e));process.exit(1)}
