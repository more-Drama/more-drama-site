(() => {
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const people = document.querySelector('#stories > .wrap > h2 em');
  if (people && !reduced.matches) {
    const text = people.textContent;
    people.setAttribute('aria-hidden', 'true');
    people.replaceChildren(...Array.from(text, char => {
      const span = document.createElement('span'); span.textContent = char; span.className = 'typeLetter'; return span;
    }));
    const observer = new IntersectionObserver(entries => {
      if (!entries.some(e => e.isIntersecting)) return;
      observer.disconnect();
      [...people.children].forEach((span, i) => setTimeout(() => span.classList.add('visible'), i * 95));
    }, {threshold: .5});
    observer.observe(people);
  }
  const target = document.querySelector('.shelfhead h2 em');
  if (!target || reduced.matches) return;
  const words = ['Explore', 'Eat', 'Experience', 'Learn', 'Drink'];
  target.classList.add('typeCycle');
  target.innerHTML = '<span class="typeSizer" aria-hidden="true">Experience.</span><span class="typeCurrent" aria-hidden="true">Explore.</span>';
  target.setAttribute('aria-label', words.join(', '));
  const pause = document.createElement('button');
  pause.className = 'typePause'; pause.textContent = 'Ⅱ'; pause.setAttribute('aria-label','Παύση εναλλαγής λέξεων'); pause.setAttribute('aria-pressed','false');
  target.after(pause);
  let index = 0, position = words[0].length, deleting = true, visible = false, paused = false, timer;
  const current = target.querySelector('.typeCurrent');
  function tick() {
    if (!visible || paused || reduced.matches) return;
    if (deleting) position--; else position++;
    current.textContent = words[index].slice(0, Math.max(0, position)) + '.';
    let delay = deleting ? 75 : 130;
    if (position <= 0) { index = (index + 1) % words.length; deleting = false; delay = 250; }
    if (position === words[index].length && !deleting) { deleting = true; delay = 1900; }
    timer = setTimeout(tick, delay);
  }
  new IntersectionObserver(entries => {
    visible = entries[0].isIntersecting; clearTimeout(timer);
    if (visible && !paused) timer = setTimeout(tick, 1900);
  }).observe(target);
  pause.onclick = () => { paused = !paused; pause.textContent = paused ? '▶' : 'Ⅱ'; pause.setAttribute('aria-pressed', String(paused)); pause.setAttribute('aria-label', paused ? 'Συνέχιση εναλλαγής λέξεων' : 'Παύση εναλλαγής λέξεων'); clearTimeout(timer); if (!paused) tick(); };
})();
