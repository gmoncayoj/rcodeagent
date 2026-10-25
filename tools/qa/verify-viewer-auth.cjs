// Browser plugin unavailable; isolate every probe from real accounts/documents.
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const {spawn}=require('node:child_process');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const attempt=process.argv[2] || 'final';assert.match(attempt,/^[a-z0-9-]+$/);
const directory=path.join(root,`.local/viewer-auth-${attempt}`);fs.mkdirSync(directory,{recursive:true});
const runtime=spawn(process.env.RSCRIPT || 'Rscript',['--vanilla','tools/qa/preview-recovery.R'],{
 cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,
 LC_ALL:'English_United States.utf8',RCODEAGENT_RECOVERY_QA_DIR:directory,TEMP:directory,TMP:directory}});
let output='';runtime.stdout.on('data',x=>output+=x);runtime.stderr.on('data',x=>output+=x);
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const read=file=>JSON.parse(fs.readFileSync(path.join(directory,file),'utf8'));
async function until(f){for(let i=0;i<300;i++){if(await f())return;await sleep(100)}throw Error('Synthetic QA timeout');}
(async()=>{let browser;try{
 await until(()=>fs.existsSync(path.join(directory,'launch.json')));
 const url=new URL(read('launch.json').url);
 browser=await chromium.launch({headless:true,...(process.env.CHROME_PATH ? {executablePath:process.env.CHROME_PATH} : {})});
 const page=await browser.newPage();await page.goto(url.href);
 await page.locator('#model option[value="qa-recovery-b"]').waitFor({state:'attached'});
 await page.locator('#capture_document').click();
 await page.getByRole('button',{name:'Activar Auto mode',exact:true}).click();
 await until(async()=>await page.locator('#auto_toggle').getAttribute('aria-pressed')==='true');
 await page.getByRole('textbox',{name:'Mensaje',exact:true}).fill('AUDIT_SYNTHETIC_DRAFT');
 await sleep(600);await page.close();await until(()=>read('state.json').status==='suspended');
 const ctx=await browser.newContext();
 await ctx.grantPermissions(['local-network-access'],{origin:'https://untrusted.example'});
 const attacker=await ctx.newPage();
 await attacker.route('https://untrusted.example/**',r=>r.fulfill({status:200,contentType:'text/html',body:'<!doctype html><title>Synthetic foreign origin</title>'}));
 await attacker.goto('https://untrusted.example/');
 const attacks=[];
 for (const hash of ['',url.hash]) {
   const result=await attacker.evaluate(({wsurl,hash})=>new Promise(resolve=>{
     const result={opened:false,restore_received:false,draft_exposed:false,auto_exposed:false,closed:false};
     const socket=new WebSocket(wsurl);
     const timer=setTimeout(()=>{socket.close();resolve(result)},3500);
     socket.onopen=()=>{result.opened=true;socket.send(JSON.stringify({method:'init',data:{'.clientdata_url_hash_initial':hash}}));};
     socket.onclose=()=>{result.closed=true;clearTimeout(timer);resolve(result)};
     socket.onmessage=e=>{result.draft_exposed ||= e.data.includes('AUDIT_SYNTHETIC_DRAFT');
       try {const x=JSON.parse(e.data);if(x.custom?.['rg-viewer-restore'])result.restore_received=true;
         if(x.custom?.['rg-session-state']?.auto)result.auto_exposed=true;}catch{}};
   }),{wsurl:url.origin.replace(/^http/,'ws')+'/websocket/',hash});
   assert.equal(result.opened,true);assert.equal(result.restore_received,false);
   assert.equal(result.draft_exposed,false);assert.equal(result.auto_exposed,false);
   attacks.push({private_fragment_supplied:!!hash,...result});
   assert.equal(read('state.json').status,'suspended');
 }
 const invalid=[];
 for (const hash of ['', '#rcodeagent='+'b'.repeat(64)]) {
   const rejected=await browser.newPage();await rejected.goto(url.origin+'/'+hash);
   await rejected.locator('#shiny-disconnected-overlay').waitFor({state:'attached'});
   assert.equal((await rejected.locator('body').innerText()).includes('AUDIT_SYNTHETIC_DRAFT'),false);
   invalid.push({wrong_fragment:!!hash,rejected:true});await rejected.close();
 }
 assert.equal(read('state.json').status,'suspended');
 const resumed=await browser.newPage();await resumed.goto(url.href);
 await resumed.locator('#model option[value="qa-recovery-b"]').waitFor({state:'attached'});
 await until(async()=>await resumed.evaluate(()=>!!Shiny.shinyapp.$inputValues.viewer_restored));
 assert.equal(await resumed.getByRole('textbox',{name:'Mensaje',exact:true}).inputValue(),'AUDIT_SYNTHETIC_DRAFT');
 assert.equal(await resumed.locator('#auto_toggle').getAttribute('aria-pressed'),'true');
 assert.equal(read('editor.json').writes,0);
 await resumed.locator('#done').click();await until(()=>runtime.exitCode!==null);
 assert.equal(runtime.exitCode,0);
 const result={passed:true,synthetic_only:true,real_credentials_used:false,native_rstudio:false,
 browser:browser.version(),permission:'local-network-access granted only in isolated context',
 foreign_https:attacks,missing_or_wrong_fragment:invalid,checkpoint_preserved:true,legitimate_resume:true,no_writes:true};
 fs.writeFileSync(path.join(directory,'result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
 }finally{if(browser)await browser.close();if(runtime.exitCode===null)runtime.kill();
 fs.writeFileSync(path.join(directory,'runtime.log'),output);}})().catch(e=>{console.error(e);process.exitCode=1});
