// Browser plugin not available. Existing project Playwright runtime; synthetic provider/editor only.
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const {spawn} = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = process.env.RCODEAGENT_QA_ROOT || path.resolve(__dirname, '../..');
const version = fs.readFileSync(path.join(root, 'DESCRIPTION'), 'utf8').match(/^Version:\s*([0-9]+(?:\.[0-9]+)+)\s*$/m)?.[1];
assert.ok(version, 'DESCRIPTION must provide a valid package version');
const attempt = process.argv[2] || 'normal-auto';
assert.match(attempt,/^[a-z0-9-]+$/);
const directory = path.join(root, `.local/viewer-recovery-${version}-${attempt}`);
fs.mkdirSync(path.join(root,'.local/runtime-temp'),{recursive:true});
fs.mkdirSync(directory,{recursive:true});
const visual=path.join(directory,'screenshots'); fs.mkdirSync(visual,{recursive:true});
fs.writeFileSync(path.join(directory,'reference.R'),'reference_value <- 1\n');
const runtime=spawn(process.env.RSCRIPT || 'Rscript',['--vanilla','tools/qa/preview-recovery.R'],{
  cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,LC_ALL:'English_United States.utf8',
    RCODEAGENT_RECOVERY_QA_DIR:directory,TEMP:path.join(root,'.local/runtime-temp'),TMP:path.join(root,'.local/runtime-temp')}});
runtime.stdout.pipe(fs.createWriteStream(path.join(directory,'stdout.log')));
runtime.stderr.pipe(fs.createWriteStream(path.join(directory,'stderr.log')));
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const read=name=>JSON.parse(fs.readFileSync(path.join(directory,name),'utf8'));
async function until(check,timeout=30000){const end=Date.now()+timeout;while(Date.now()<end){if(await check())return;await pause(100);}throw new Error('QA state timeout');}
(async()=>{
  let browser,page; const errors=[];
  try{
    await until(()=>fs.existsSync(path.join(directory,'launch.json')));
    const url=read('launch.json').url, table=read('table.json').url;
    browser=await chromium.launch({headless:true,...(process.env.CHROME_PATH?{executablePath:process.env.CHROME_PATH}:{})});
    page=await browser.newPage({viewport:{width:1280,height:800}});
    page.on('pageerror',error=>errors.push(error.message));
    page.on('console',message=>{if(['error','warning'].includes(message.type())&&!/\/favicon[.]ico$/.test(message.location().url))errors.push(message.text());});
    async function ready(){await page.locator('#model option[value="qa-recovery-b"]').waitFor({state:'attached'});}
    async function send(text){
      await until(async()=>await page.locator('#send').getAttribute('aria-label')==='Enviar mensaje');
      await page.locator('#request').fill(text);await page.locator('#send').click();
    }
    async function auto(on){if((await page.locator('#auto_toggle').getAttribute('aria-pressed')==='true')!==on)await page.locator('#auto_toggle').click();await until(async()=>await page.locator('#auto_toggle').getAttribute('aria-pressed')===String(on));}
    async function away(suffix=''){await page.goto(table+suffix);await page.getByRole('heading',{name:'Tabla sintética en Viewer',exact:true}).waitFor();await until(()=>read('state.json').status==='suspended',10000);assert.equal(runtime.exitCode,null);}
    async function back(){await page.goto(url);await ready();await until(async()=>await page.evaluate(()=>!!Shiny.shinyapp.$inputValues.viewer_restored));}
    await page.goto(url);await ready();
    assert.equal(await page.locator('#ui_language').inputValue(),'en');
    await until(async()=>await page.locator('#capture_document').innerText()==='Active file');
    await page.locator('#ui_language').selectOption('es');
    await until(async()=>await page.locator('#capture_document').innerText()==='Archivo activo');
    assert.equal(await page.title(),'rcodeagent');
    assert.equal(await page.locator('.rg-brand-row h1').innerText(),'rcodeagent');
    assert.deepEqual(await page.locator('#mode input').evaluateAll(inputs=>inputs.map(input=>input.value)),['normal','auto']);
    assert.equal(await page.locator('#mode_label').innerText(),'Normal');
    await page.locator('#mode_menu summary').click();
    await page.screenshot({path:path.join(visual,'modes-1280-es.png')});
    await page.locator('#mode_menu summary').click();
    await send('Explica el código');
    await page.getByText('Respuesta sintética sin edición.',{exact:true}).waitFor();
    assert.equal(read('editor.json').writes,0);
    assert.equal(await page.locator('#apply').count(),0);
    await page.locator('#capture_document').click();await auto(true);
    const autoNotice=page.locator('#shiny-notification-rcodeagent-auto-notice');
    await autoNotice.waitFor();
    await pause(300); // Allow the menu's reflected input event to reach the server.
    assert.equal(await page.locator('.shiny-notification').filter({hasText:'RStudio puede dejar el código en cola.'}).count(),1);
    await autoNotice.waitFor({state:'detached',timeout:7000});
    await send('Escribe el primer código');await until(()=>read('editor.json').writes===1);
    await send('ejecuta la línea 1');await until(()=>read('editor.json').executions.length===1);
    assert.equal(read('editor.json').executions[0],'qa_value <- 2');
    assert.equal(read('editor.json').writes,1);
    await send('Carga la librería lavaan');await until(()=>read('editor.json').executions.length===2);
    assert.equal(read('editor.json').writes,2);
    assert.equal(read('editor.json').value,'qa_value <- 2\nlibrary(lavaan)');
    await send('Carga la librería lavaan');await until(()=>read('editor.json').executions.length===3);
    assert.equal(read('editor.json').writes,2);
    await send('Instala el paquete lavaan');await until(()=>read('editor.json').executions.length===4);
    assert.equal(read('editor.json').executions[3],'install.packages("lavaan")');
    assert.equal(read('editor.json').writes,2);
    await send('Genera y ejecuta un ejemplo');
    await until(()=>read('editor.json').executions.length===5);
    await page.getByText('qa_run <- 7',{exact:true}).first().waitFor();
    assert.equal(await page.locator('[data-execute-id]').count(),0);
    await page.screenshot({path:path.join(visual,'execution-auto-1280-es.png')});
    await page.locator('#refresh').click();
    assert.equal(await page.locator('#auto_toggle').getAttribute('aria-pressed'),'true');
    await page.locator('#project_context').click();
    assert.equal(await page.locator('#auto_toggle').getAttribute('aria-pressed'),'true');
    await page.locator('#capture_document').click();
    assert.equal(await page.locator('#auto_toggle').getAttribute('aria-pressed'),'true');
    await send('Ejecuta una operación administrativa sintética');
    await page.locator('[data-execute-id]').waitFor();
    assert.equal(read('editor.json').executions.length,5);
    const adminNonce=await page.locator('[data-execute-id]').getAttribute('data-execute-id');
    await page.screenshot({path:path.join(visual,'administrative-review-1280-es.png')});
    await page.locator('[data-execute-id]').click();await until(()=>read('editor.json').executions.length===6);
    await page.locator('#request').fill('Borrador de continuación');await pause(600);
    await away();await back();
    assert.equal(await page.locator('#auto_toggle').getAttribute('aria-pressed'),'true');
    assert.equal(await page.locator('#request').inputValue(),'Borrador de continuación');
    assert.equal(await page.locator('[data-execute-id]').count(),0);
    await page.evaluate(()=>Shiny.setInputValue('confirm_execution','obsolete-confirmation',{priority:'event'}));await pause(500);
    assert.equal(read('editor.json').executions.length,6);
    await auto(false);await away();await back();
    assert.equal(await page.locator('#mode_label').innerText(),'Normal');
    await auto(true);await away('/change');await back();
    assert.equal(await page.locator('#auto_toggle').getAttribute('aria-pressed'),'false');
    await page.locator('#capture_document').click();await auto(true);
    await send('Respuesta lenta');await page.getByRole('button',{name:'Detener consulta',exact:true}).waitFor();
    await away();await back();
    assert.equal(await page.locator('#request').inputValue(),'Respuesta lenta');
    assert.equal(read('editor.json').executions.length,6);
    await page.locator('#ui_language').selectOption('en');
    await until(async()=>await page.locator('#capture_document').innerText()==='Active file');
    await page.locator('#about').click();await page.locator('.modal').waitFor();
    assert.match(await page.locator('.modal').innerText(),/Normal works in chat only/);
    await page.locator('.modal button').filter({hasText:'Close'}).click();
    await page.setViewportSize({width:560,height:800});
    await page.locator('#mode_menu summary').click();
    await page.screenshot({path:path.join(visual,'modes-560-en.png')});
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
    await page.locator('#mode_menu summary').click();
    await page.locator('#done').click();await until(()=>runtime.exitCode!==null,15000);
    assert.equal(runtime.exitCode,0);assert.deepEqual(errors,[]);
    const result={passed:true,version,auto_notice_single:true,auto_notice_auto_dismiss_5s:true,normal_chat_only:true,auto_edit:true,explicit_line_execution:true,
      library_no_duplicate:true,package_install_without_confirmation:true,explicit_execution_without_confirmation:true,administrative_one_use_confirmation:true,context_preserves_auto:true,viewer_no_execution_replay:true,viewer_auto_restored:true,
      normal_restored:true,conflict_revokes_auto:true,pending_worker_cancelled:true,es_en:true,
      viewports:[1280,560],console_errors:errors,native_rstudio:false,real_provider:false};
    fs.writeFileSync(path.join(directory,'result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
  }finally{if(browser)await browser.close();if(runtime.exitCode===null)runtime.kill();}
})().catch(error=>{console.error(error);process.exitCode=1;});
