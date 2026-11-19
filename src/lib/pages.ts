import { load } from 'cheerio';
import type { CollectionEntry } from 'astro:content';
import refinements from '../styles/preview-refinements.css?raw';
import imageSizes from '../templates/image-sizes.json';
import eventsData from '../data/events.json';

const templates = import.meta.glob('../templates/*.html', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;
type Story = CollectionEntry<'stories'>['data'];

type EventItem = { id: string; date: string; time?: string; title: string; place: string; price: string; organizer?: string; desc: string; source?: string; verify?: string };
const DOW = ['Κυριακή', 'Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο'];
const MONTHS = ['Ιανουαρίου', 'Φεβρουαρίου', 'Μαρτίου', 'Απριλίου', 'Μαΐου', 'Ιουνίου', 'Ιουλίου', 'Αυγούστου', 'Σεπτεμβρίου', 'Οκτωβρίου', 'Νοεμβρίου', 'Δεκεμβρίου'];
const allEvents = (eventsData as EventItem[]).slice().sort((a, b) => (a.date + (a.time || '')).localeCompare(b.date + (b.time || '')));
function eventParts(e: EventItem) {
  const [y, m, d] = e.date.split('-').map(Number);
  const dow = DOW[new Date(Date.UTC(y, m - 1, d, 12)).getUTCDay()];
  return { day: String(d), month: String(m).padStart(2, '0'), dow, long: `${dow} ${d} ${MONTHS[m - 1]}` };
}
const athensToday = () => new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Athens' });
const eventSearch = allEvents.map(e => JSON.stringify([e.title, `/preview/events/?view=month&anchor=${e.date}#event-${e.id}`])).join(', ');
const jsSafe = (value: unknown) => JSON.stringify(value).replace(/</g, '\\u003c');
const escape = (text: string) => text.replace(/[&<>"']/g, char =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]!));

function imageHtml(image: Story['cover'], lazy = true) {
  const focus = image.focus ? ` style="object-position:${escape(image.focus)}"` : '';
  return `<img src="${escape(image.src)}" alt="${escape(image.alt)}" width="${image.width}" height="${image.height}"${focus} ${lazy ? 'loading="lazy"' : 'fetchpriority="high"'}>`;
}
function blocksHtml(story: Story) {
  return story.blocks.map(block => {
    const text: string[] = [];
    const pictures: string[] = [];
    for (const item of block.items) {
      if (item.type === 'list') {
        const tag = item.ordered ? 'ol' : 'ul';
        text.push(`<${tag} class="answer">${item.items.map(entry => `<li>${escape(entry)}</li>`).join('')}</${tag}>`);
      } else if (item.type === 'link') {
        text.push(`<p class="answer"><a href="${escape(item.href)}">${escape(item.text)} ↗</a></p>`);
      } else if (item.type === 'image') {
        pictures.push(`<figure>${imageHtml(item.image)}<figcaption>${escape(item.image.caption)}</figcaption>${item.image.text ? `<p class="imageStory">${escape(item.image.text)}</p>` : ''}</figure>`);
      } else {
        const tag = item.type === 'heading' ? 'h2' : item.type === 'quote' ? 'blockquote' : 'p';
        const className = item.type === 'quote' ? 'hand' : item.type === 'paragraph' ? 'answer' : '';
        text.push(`<${tag} class="${className}">${escape(item.text)}</${tag}>`);
      }
    }
    const copy = text.length ? `<div>${text.join('')}</div>` : '';
    const content = block.layout === 'closing' ? pictures.join('') + copy : copy + pictures.join('');
    return `<div class="${block.layout}">${content}</div>`;
  }).join('');
}

export async function preparePage(key: string, story: Story) {
  const html = templates[`../templates/MORE-DRAMA-${key}.html`];
  const $ = load(html);
  const isPeople = story.category === 'people';
  const href = isPeople ? `/people/${story.slug}/` : '/people/i-poli-sta-cheria-tis/';
  if (key === 'guides') {
    $('.gmheading h2').text('Τι να κάνεις στη Δράμα;');
    $('.clear44').removeAttr('hidden').text('Κάνε κλικ εδώ για να δεις όλες τις επιλογές της πόλης')
      .wrap('<p class="guideInstructions"></p>')
      .after(' ή επάνω στο σχετικό κουτάκι για να δεις ανά κατηγορία.');
    $('script').each((_, el) => {
      const script = $(el);
      script.html((script.html() || '').replace("r.querySelector('.clear44').hidden=!selected", "r.querySelector('.clear44').hidden=false"));
    });
    const upcoming = allEvents.filter(e => e.date >= athensToday()).slice(0, 4)
      .map(e => { const p = eventParts(e); return [e.date, `${p.day.padStart(2, '0')}/${p.month}`, e.title]; });
    $('#guides43 .gindex > .gwrap').append(`<section class="guideAgenda" aria-labelledby="guideAgendaTitle"><div class="guideAgendaHead"><h2 id="guideAgendaTitle"><em>more</em> Events</h2><a href="/preview/events/">Δες την ατζέντα ↗</a></div><ol>${upcoming.map(([date, label, title]) => `<li><time datetime="${date}">${label}</time><span>${escape(title)}</span></li>`).join('')}</ol></section>`);
  }
  if (key === 'worlds') {
    const destinations: Record<string, string> = {
      people: '/people/', finds: '/preview/more-finds/',
      lifestyle: '/preview/more-lifestyle/', culture: '/preview/more-culture/',
      connection: '/preview/more-connection/',
    };
    $('#worldIssue .overview > nav a').each((_, el) => {
      const destination = destinations[($(el).attr('href') || '').slice(1)];
      if (destination) $(el).attr('href', destination);
    });
    $('#issuePitch').wrap('<details class="worldContact"></details>');
    $('.worldContact').prepend('<summary>Επικοινώνησε μαζί μας ↗</summary>');
  }
  // Every page: the search index lists the real events from src/data/events.json.
  $('script').each((_, el) => {
    const code = $(el).html() || '';
    if (!code.includes('for(const [label,href] of [')) return;
    $(el).html(code
      .replace(/\["[^"]*", "\/preview\/events\/\?view=month#event-\d+"\], /g, '')
      .replace('for(const [label,href] of [', `for(const [label,href] of [${eventSearch ? eventSearch + ', ' : ''}`));
  });
  if (key === 'events') {
    const pane = $('.listPane');
    pane.find('details.event').remove();
    pane.append(allEvents.map(e => {
      const p = eventParts(e);
      const meta = [e.time, e.place].filter(Boolean).join(' · ');
      return `<details class="event" id="event-${escape(e.id)}" data-date="${e.date}"><summary><time datetime="${e.date}"><b>${p.day}</b><i>/${p.month}</i><small>${p.dow}</small></time><span><strong>${escape(e.title)}</strong><small>${escape(meta)}</small></span></summary><p>${escape(e.desc)}</p><p><a class="eventLink" data-event="${escape(e.id)}" href="/preview/event/?id=${escape(e.id)}">Δες την εκδήλωση ↗</a></p></details>`;
    }).join(''));
    $('script').each((_, el) => {
      const code = $(el).html() || '';
      if (!code.includes('const demoToday=')) return;
      $(el).html(code
        .replace('const demoToday=new Date(2026,10,16,12)', 'const demoToday=(()=>{const n=new Date();return new Date(n.getFullYear(),n.getMonth(),n.getDate(),12)})()')
        .replace('/^2026-11-([012][0-9]|30)$/', String.raw`/^\d{4}-\d{2}-\d{2}$/`));
    });
  }
  if (key === 'event') {
    const map = Object.fromEntries(allEvents.map(e => {
      const p = eventParts(e);
      return [e.id, { id: e.id, day: p.day, date: e.date, dow: p.dow, long: p.long, title: e.title, hour: e.time || 'Υπό επιβεβαίωση', place: e.place, price: e.price, desc: e.desc, organizer: e.organizer || '' }];
    }));
    $('.detailMeta').text('');
    $('script').each((_, el) => {
      const code = $(el).html() || '';
      if (!code.includes('const events={')) return;
      $(el).html(code
        .replace(/const events=\{[\s\S]*?\};const qs/, () => `const events=${jsSafe(map)};const qs`)
        .replace("id=qs.get('id')||'21'", "id=qs.get('id')||''")
        .replace("anchor:qs.get('anchor')||'2026-11-16'", "anchor:qs.get('anchor')||e?.date||''")
        .replace("'#event-'+(e?.day||'')", "'#event-'+(e?.id||'')")
        .replace("n.dataset.field==='date'?e.dow+' '+e.day+' Νοεμβρίου':e[n.dataset.field]", "n.dataset.field==='date'?e.long:e[n.dataset.field]")
        .replace("document.querySelector('.intro').textContent=e.desc", "document.querySelector('.intro').textContent=e.desc;document.querySelector('.detailMeta').textContent=e.organizer?'Διοργάνωση: '+e.organizer:''"));
    });
  }
  $('a[href="/people/i-poli-sta-cheria-tis/"]').attr('href', href);
  let title = $('title').text();
  let description = 'Άνθρωποι, ιστορίες και διαδρομές στη Δράμα από το more Drama.';
  if (key === 'story') {
    $('.journal').addClass(isPeople ? 'peopleStory' : 'cultureStory').attr('data-journal', story.category);
    $('.coverInner > small').html(isPeople ? '<em>more</em> People' : '<em>more</em> Culture');
    if (!isPeople) {
      $('.storyPitch').remove();
      $('.discoverMore').attr('href', '/preview/more-culture/');
      $('.discoverMore small').html('<em>more</em> Culture');
      $('.discoverMore strong').text('Ανακάλυψε κι άλλες ιστορίες της πόλης ↗');
    }
    $('.discoverMore > img').remove();
    title = story.seo.title;
    description = story.seo.description;
    $('.journal h1').text(story.title);
    $('.signature').text(story.signature);
    $('.leadJ').text(story.intro);
    $('.folioJ span').text(story.displayDate);
    $('.coverJ > img').replaceWith(imageHtml(story.cover, false));
    $('.opening,.contactSheet,.closing').remove();
    $('.noteJ').before(blocksHtml(story));
    if (story.credit) $('.leadJ').after(`<p class="creditJ">${escape(story.credit)}</p>`);
    if (story.disclaimer) $('.noteJ').text(story.disclaimer); else $('.noteJ').remove();
  }
  if (key === 'more-people') {
    description = 'Γνώρισε τους ανθρώπους της Δράμας μέσα από συνεντεύξεις, πορτρέτα και ιστορίες του more People.';
    $('.splitcopy h2').text(story.title);
    $('.splitcopy p').text(story.cardIntro);
    $('.split36 figure > img').replaceWith(imageHtml(story.cover));
  }
  if (key === 'home') {
    $('.hero .cta').text('Αυτό το Σαββατοκύριακο ↓');
    $('.cutwater').replaceWith('<figure class="cutwaterStory"><div class="waterCrop"><img src="/media/a53f6a79b1e8596c.webp" alt="Η αυλή του Ύδραμα δίπλα στο νερό" loading="lazy"></div><figcaption><small>Καφές και βόλτα</small><h3>Η αυλή του Ύδραμα</h3><p>Μια στάση δίπλα στο νερό, στην αυλή της Αγίας Βαρβάρας.</p></figcaption></figure>');
    $('body').append('<script src="/wanderings-type.js"></script><script src="/home-type.js"></script>');
    const tip = $('#community form.tip');
    tip.children('label:not(.checkrow), textarea, input').wrapAll('<div class="tipFields"></div>');
    tip.children('details, .checkrow, button, small, output').wrapAll('<div class="tipActions"></div>');
    const intro = $('#community .communitygrid > div').first().addClass('tipIntro');
    tip.prepend(intro);
    const moods = ['kids', 'wine', 'coffee', 'shops', 'rain', 'free'];
    $('#mood-list .mood').each((i, el) => {
      const item = $(el);
      const label = item.clone().children().remove().end().text().trim();
      item.replaceWith(`<a class="mood" href="/preview/guides/#${moods[i]}">${item.children('span').toString()}<b class="moodLabel">${escape(label)} ↗</b></a>`);
    });
    $('script').each((_, el) => {
      const code = $(el).html() || '';
      $(el).html(code.replace(/for\(const mood of document\.querySelectorAll\('\.mood'\)\).*?;\n/, ''));
    });
    $('#stories > .wrap > h2 > a').attr('aria-label', 'more People, more Stories.');
    $('#stories > .wrap > h2 em').text('People, more Stories.');
    description = 'Το more Drama συγκεντρώνει ιστορίες ανθρώπων, οδηγούς πόλης και εκδηλώσεις στη Δράμα.';
    $('#stories .feature h3').text(story.title);
    $('#stories .feature p').text(story.cardIntro);
    $('#stories .feature small').text(story.displayDate);
    $('.readCard[data-story="0"] strong,.storyText[data-id="0"] h3').text(story.title);
    // These source previews use CSS photographs in the home feature and carousel.
    $('head').append(`<style>.picture.artisan{background-image:url("${escape(story.cover.src)}")!important}</style>`);
    $('.picture.artisan[role="img"]').attr('aria-label', story.cover.alt);
  }
  $('img').each((_, el) => {
    const img = $(el);
    const dimensions = (imageSizes as Record<string, number[]>)[img.attr('src') || ''];
    if (dimensions) img.attr({ width: dimensions[0], height: dimensions[1] });
    img.attr('decoding', 'async');
  });
  // Keep the approved navigation identical across the three migrated entry points.
  if (['home', 'story', 'more-people'].includes(key)) {
    const shared = load(templates['../templates/MORE-DRAMA-more-people.html']);
    $('header').first().replaceWith(shared('header').first().toString());
  }
  $('.mast .deskdrop').each((_, el) => {
    const dropdown = $(el);
    dropdown.before('<a class="desk worlds-link" href="/preview/worlds/">5 κόσμοι</a>');
    dropdown.children('summary').text('⌄').attr('aria-label', 'Άνοιγμα των πέντε κόσμων');
  });
  $('.mast a[href="/preview/events/"]').text('Events');
  $('.mast .fly a[href="/preview/worlds/"]').text('5 κόσμοι');
  $('.mast > nav > .findOpen').before('<a class="desk contact-link" href="/preview/partners/">Contact Us</a>');
  $('.mast .mobdrop .findOpen').before('<a href="/preview/partners/">Contact Us</a>');
  if (key === 'partners') {
    // Until a form backend exists, the form opens the visitor's email app with the message ready.
    const mailHandler = "f.onsubmit=e=>{e.preventDefault();const lines=[];for(const [k,v] of new FormData(f)){if(typeof v!=='string'||!v||v==='on')continue;const label=(f.elements[k]?.closest('label')?.firstChild?.textContent||k).trim();lines.push(label+': '+v)}location.href='mailto:moredrama.gr@gmail.com?subject='+encodeURIComponent('Συνεργασία με το more Drama')+'&body='+encodeURIComponent(lines.join('\\n'));f.querySelector('output').textContent='Ανοίγει το email σου με το μήνυμα έτοιμο. Πάτα «Αποστολή» για να φτάσει σε εμάς.'}";
    $('script').each((_, el) => {
      const code = $(el).html() || '';
      if (!code.includes("f.onsubmit=e=>{e.preventDefault();f.querySelector('output').textContent='Η δοκιμή ολοκληρώθηκε χωρίς αποστολή.'}")) return;
      $(el).html(code.replace("f.onsubmit=e=>{e.preventDefault();f.querySelector('output').textContent='Η δοκιμή ολοκληρώθηκε χωρίς αποστολή.'}", mailHandler));
    });
    $('.partnerContact form').first().after('<p class="partnerMail">Ή γράψε μας απευθείας στο <a href="mailto:moredrama.gr@gmail.com">moredrama.gr@gmail.com</a></p>');
    $('.mast [aria-current="page"]').removeAttr('aria-current');
    $('.mast a[href="/preview/partners/"]').attr('aria-current', 'page');
  }
  $('.mast .brand').html('<img src="/media/more-drama-logo-white-color.png" width="300" height="50" alt="more Drama" />').attr('aria-label', 'more Drama, αρχική');
  $('head').append('<style>' + refinements + '</style>');
  if (key === 'guides') $('body').append('<script src="/balance-guides.js"></script>');
  $('head').append('<style>.journal .opening img,.journal .closing img,.journal .contactSheet img,.journal .discoverMore img,.peopleEd .split36 img{height:auto}.peopleEd .split36 figure{display:flex;align-items:center}</style>');
  $('a,button,summary').find('*').addBack().contents().each((_, node) => {
    if (node.type === 'text' && node.data.includes('↗')) {
      $(node).replaceWith(escape(node.data).replaceAll('↗', '<span class="linkArrow" aria-hidden="true">↗</span>'));
    }
  });
  const styles = $('style').map((_, el) => $(el).html()).get().join('\n');
  $('style,title,meta,link[rel="canonical"]').remove();
  return { title, description, styles, body: $('body').html() || '' };
}
