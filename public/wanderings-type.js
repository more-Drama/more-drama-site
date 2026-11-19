(() => {
  const heading = document.getElementById('wanderings');
  if (!heading || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  heading.setAttribute('aria-label', heading.textContent.replace('Νέες', 'Νέες '));
  const walker = document.createTreeWalker(heading, NodeFilter.SHOW_TEXT);
  const nodes = [];
  while (walker.nextNode()) nodes.push(walker.currentNode);
  const letters = [];
  for (const node of nodes) {
    const fragment = document.createDocumentFragment();
    for (const char of node.textContent) {
      const span = document.createElement('span');
      span.className = 'typeLetter'; span.textContent = char;
      span.setAttribute('aria-hidden', 'true');
      letters.push(span); fragment.append(span);
    }
    node.replaceWith(fragment);
  }
  const observer = new IntersectionObserver(entries => {
    if (!entries.some(entry => entry.isIntersecting)) return;
    observer.disconnect();
    letters.forEach((letter, index) => setTimeout(() => letter.classList.add('visible'), index * 85));
  }, { threshold: .5 });
  observer.observe(heading);
})();
