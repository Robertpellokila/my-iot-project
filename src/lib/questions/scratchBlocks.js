// Blockly JSON definitions shared by admin, player and spectator. No code evaluation.
export const SCRATCH_CATEGORIES = [
 ['motion','Motion','#4c97ff'],['looks','Looks','#9966ff'],['sound','Sound','#cf63cf'],
 ['events','Events','#ffbf00'],['control','Control','#ffab19'],['sensing','Sensing','#5cb1d6'],
 ['operators','Operators','#59c059'],['variables','Variables','#ff8c1a'],['myblocks','My Blocks','#ff6680'],
].map(([id,name,colour])=>({id,name,colour}));
const num=(name,value=10)=>({type:'field_number',name,value});
const txt=(name,text='hello')=>({type:'field_input',name,text});
const menu=(name,options)=>({type:'field_dropdown',name,options:options.map(v=>[v,v])});
const input=(name,check)=>({type:'input_value',name,...(check?{check}:{})});
const body=(name='DO')=>({type:'input_statement',name});
const specs=[];
const add=(category,key,message,args=[],shape='stack',capability='quiz')=>{
 specs.push({category,capability,definition:{type:`tbc_${key}`,message0:message,args0:args,colour:SCRATCH_CATEGORIES.find(c=>c.id===category).colour,
 tooltip:capability==='runtime'?'Susun & nilai struktur; menjalankan blok ini membutuhkan runtime sprite/suara.':'Blok quiz: diperiksa sebagai struktur program.',
 ...(shape==='stack'?{previousStatement:null,nextStatement:null}:shape==='hat'?{nextStatement:null,hat:'cap'}:shape==='cap'?{previousStatement:null}: {output:shape}),inputsInline:true}});
};
add('motion','move','move %1 steps',[input('STEPS','Number')],'stack','runtime');
add('motion','turn','turn %1 %2 degrees',[menu('DIR',['↻','↺']),input('DEGREES','Number')],'stack','runtime');
add('motion','goto','go to x: %1 y: %2',[input('X','Number'),input('Y','Number')],'stack','runtime');
add('motion','glide','glide %1 secs to x: %2 y: %3',[input('SECONDS','Number'),input('X','Number'),input('Y','Number')],'stack','runtime');
add('motion','bounce','if on edge, bounce',[],'stack','runtime');
add('motion','position','%1 position',[menu('AXIS',['x','y'])],'Number','runtime');
add('looks','say','say %1 for %2 seconds',[input('TEXT'),input('SECONDS','Number')],'stack','runtime');
add('looks','costume','switch costume to %1',[txt('COSTUME','costume1')],'stack','runtime');
add('looks','backdrop','switch backdrop to %1',[txt('BACKDROP','backdrop1')],'stack','runtime');
add('looks','visible','%1',[menu('ACTION',['show','hide'])],'stack','runtime');
add('sound','play_sound','%1 sound %2',[menu('MODE',['start','play until done']),txt('SOUND','pop')],'stack','runtime');
add('sound','volume','set volume to %1 %',[input('VOLUME','Number')],'stack','runtime');
add('sound','stop_sound','stop all sounds',[],'stack','runtime');
add('events','flag','when ⚑ clicked',[],'hat');
add('events','key','when %1 key pressed',[menu('KEY',['space','up arrow','down arrow','left arrow','right arrow','a','b','c'])],'hat');
add('events','clicked','when this sprite clicked',[],'hat','runtime');
add('events','backdrop_event','when backdrop switches to %1',[txt('BACKDROP','backdrop1')],'hat','runtime');
add('events','loudness_event','when loudness > %1',[input('VALUE','Number')],'hat','runtime');
add('events','receive','when I receive %1',[txt('MESSAGE','message1')],'hat');
add('events','broadcast','broadcast %1 %2',[txt('MESSAGE','message1'),menu('WAIT',['','and wait'])]);
add('control','wait','wait %1 seconds',[input('SECONDS','Number')]);
add('control','repeat','repeat %1 %2',[input('TIMES','Number'),body()]);
add('control','forever','forever %1',[body()],'cap');
add('control','if','if %1 then %2',[input('IF','Boolean'),body()]);
add('control','if_else','if %1 then %2 else %3',[input('IF','Boolean'),body(),body('ELSE')]);
add('control','until','repeat until %1 %2',[input('IF','Boolean'),body()]);
add('control','wait_until','wait until %1',[input('IF','Boolean')]);
add('control','stop','stop %1',[menu('SCOPE',['all','this script'])],'cap');
add('sensing','touching','touching %1 ?',[menu('OBJECT',['mouse-pointer','edge','Sprite1'])],'Boolean','runtime');
add('sensing','key_pressed','key %1 pressed?',[menu('KEY',['space','up arrow','down arrow','left arrow','right arrow','a'])],'Boolean','runtime');
add('sensing','ask','ask %1 and wait',[input('TEXT')],'stack','runtime');
add('sensing','answer','answer',[],'String','runtime');
add('sensing','timer','timer',[],'Number','runtime');
add('operators','number','%1',[num('NUM')],'Number');
add('operators','text','%1',[txt('TEXT')],'String');
add('operators','math','%1 %2 %3',[input('A','Number'),menu('OP',['+','−','×','÷','mod']),input('B','Number')],'Number');
add('operators','compare','%1 %2 %3',[input('A'),menu('OP',['=','<','>']),input('B')],'Boolean');
add('operators','boolean','%1 %2 %3',[input('A','Boolean'),menu('OP',['and','or']),input('B','Boolean')],'Boolean');
add('operators','not','not %1',[input('A','Boolean')],'Boolean');
add('operators','join','join %1 %2',[input('A'),input('B')],'String');
add('operators','random','pick random %1 to %2',[input('A','Number'),input('B','Number')],'Number');
add('variables','set','set %1 to %2',[txt('VAR','score'),input('VALUE')]);
add('variables','change','change %1 by %2',[txt('VAR','score'),input('VALUE','Number')]);
add('variables','value','%1',[txt('VAR','score')],'Number');
add('myblocks','define','define %1',[txt('NAME','my block')],'hat');
add('myblocks','call','%1',[txt('NAME','my block')]);
export const BLOCK_SPECS=specs;
export const BLOCK_TYPES=specs.map(s=>s.definition.type);
export const EMPTY_WORKSPACE={blocks:{languageVersion:0,blocks:[]}};
export const DEFAULT_BLOCK_CONFIG={version:1,categories:SCRATCH_CATEGORIES.map(c=>c.id),allowed_types:BLOCK_TYPES,initial:EMPTY_WORKSPACE};
export const DEFAULT_GRADING={check_values:true,strict_order:true,allow_extra:false,numeric_tolerance:0,partial_credit:false,weight:1};
export function toolboxFor(config=DEFAULT_BLOCK_CONFIG){
 return {kind:'categoryToolbox',contents:SCRATCH_CATEGORIES.filter(c=>(config.categories??DEFAULT_BLOCK_CONFIG.categories).includes(c.id)).map(c=>({kind:'category',name:c.name,colour:c.colour,contents:specs.filter(s=>s.category===c.id && (config.allowed_types??BLOCK_TYPES).includes(s.definition.type)).map(s=>({kind:'block',type:s.definition.type,inputs:Object.fromEntries(s.definition.args0.filter(a=>a.type==='input_value'&&a.check!=='Boolean').map(a=>[a.name,{shadow:{type:a.check==='Number'?'tbc_number':'tbc_text',fields:a.check==='Number'?{NUM:10}:{TEXT:'hello'}}}]))}))})).filter(c=>c.contents.length)};
}
