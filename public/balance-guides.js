(() => {
  const grid = document.querySelector('#guides43 .grid44');
  if (!grid) return;
  let frame;
  function balance() {
    const columns = [...grid.children];
    const images = [...grid.querySelectorAll('.story44 img')];
    for (const image of images) image.style.removeProperty('height');
    if (grid.classList.contains('filtered') || matchMedia('(max-width: 720px)').matches) return;
    const measurements = columns.map(column => ({
      height: [...column.children].reduce((total, card) => total + card.getBoundingClientRect().height, 0)
        + parseFloat(getComputedStyle(column).rowGap) * (column.children.length - 1),
      images: [...column.querySelectorAll('.story44 img')],
    }));
    const target = Math.max(...measurements.map(column => column.height));
    for (const column of measurements) {
      const extra = (target - column.height) / column.images.length;
      for (const image of column.images) {
        image.style.height = (image.getBoundingClientRect().height + extra) + 'px';
      }
    }
  }
  function schedule() {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(balance);
  }
  let width = 0;
  new ResizeObserver(entries => {
    const next = entries[0].contentRect.width;
    if (next !== width) { width = next; schedule(); }
  }).observe(grid);
  new MutationObserver(schedule).observe(grid, { attributes: true, attributeFilter: ['class'] });
  document.fonts.ready.then(schedule);
  window.addEventListener('load', schedule);
  schedule();
})();
