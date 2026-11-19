import { readFile, writeFile, copyFile } from 'node:fs/promises';
import { load } from 'cheerio';
const source = load(await readFile('src/templates/MORE-DRAMA-story.html','utf8'));
const sizes=JSON.parse(await readFile('src/templates/image-sizes.json','utf8'));
const names=['keramistria-drama-ergastirio','keramiki-drama-trochos','ergastirio-keramikis-drama','keramika-rafi-drama'];
const seen=new Map();
async function asset(element) {
  const old=element.attr('src');
  if(seen.has(old))return seen.get(old);
  const name=names[seen.size]||'keramistria-portreto-drama';
  const path='/media/'+name+'.webp';
  await copyFile('public'+old,'public'+path);
  const [width,height]=sizes[old];
  const value={src:path,alt:element.attr('alt')||'',width,height,caption:element.parent().find('figcaption').text()};
  seen.set(old,value);sizes[path]=[width,height];return value;
}
const cover=await asset(source('.coverJ > img'));
const blocks=[];
for(const section of source('.opening,.contactSheet,.closing').toArray()) {
  const items=[];
  for(const el of source(section).find('h2,.answer,.hand,figure').toArray()) {
    const $el=source(el);
    if(el.tagName==='figure') items.push({type:'image',image:await asset($el.find('img'))});
    else items.push({type:el.tagName==='h2'?'heading':el.tagName==='blockquote'?'quote':'paragraph',text:$el.text()});
  }
  blocks.push({layout:source(section).attr('class'),items});
}
const data={
  slug:'i-poli-sta-cheria-tis',
  status:'draft',
  category:'people',
  title:source('h1').text(),
  intro:source('.leadJ').text(),
  cardIntro:'Πώς καταλαβαίνεις ότι ένα μπολ είναι έτοιμο; Η Κυριακή αφήνει για λίγο τον τροχό και μας δείχνει.',
  signature:source('.signature').text(),
  author:'Σύνταξη more Drama',
  displayDate:'Ενδεικτική συνέντευξη',
  cover,blocks,
  seo:{title:'Κεραμική στη Δράμα — Η πόλη στα χέρια της | more Drama',description:source('.leadJ').text(),keyword:'κεραμική στη Δράμα'},
  disclaimer:'Προσχέδιο · Το πρόσωπο και τα λόγια της συνέντευξης είναι επινοημένα. Οι φωτογραφίες δημιουργήθηκαν με AI.'
};
await writeFile('src/content/stories/kyriaki.json',JSON.stringify(data,null,2)+'\n');
await writeFile('src/templates/image-sizes.json',JSON.stringify(sizes));
