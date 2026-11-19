import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { load } from 'cheerio';

const path='src/content/stories/kyriaki.json';
const original=await readFile(path,'utf8');
const story=JSON.parse(original);
const targets=['dist/index.html','dist/people/index.html',`dist/people/${story.slug}/index.html`];
function build(){execFileSync('npm',['run','build'],{env:{...process.env,ASTRO_TELEMETRY_DISABLED:'1'},stdio:'pipe'});}
try {
  const changed={...story,title:'Δοκιμή κοινής καταχώρισης',cover:story.blocks[0].items.find(i=>i.type==='image').image};
  await writeFile(path,JSON.stringify(changed));
  build();
  for(const target of targets){
    const html=await readFile(target,'utf8');
    assert(html.includes(changed.title),`Shared title missing in ${target}`);
    const $=load(html);
    assert.equal($('meta[name=robots]').attr('content'),'noindex,nofollow');
    assert($('meta[name=description]').attr('content'));
    if(target==='dist/index.html')assert(html.includes(`.picture.artisan{background-image:url("${changed.cover.src}")`));
    else assert.equal($(target.includes('i-poli')?'.coverJ > img':'.split36 figure > img').attr('src'),changed.cover.src);
  }
  console.log('Verified one content change updates all three pages.');
} finally {
  await writeFile(path,original);
  build();
}
