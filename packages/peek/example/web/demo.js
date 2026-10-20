// On a narrow screen the phones sit in a row that scrolls sideways; the
// switch above them picks one, and follows when the row is swiped.
(() => {
  const row = document.querySelector('.phones');
  const tabs = [...document.querySelectorAll('.switch [role="tab"]')];
  if (!row || tabs.length === 0) return;

  const select = (id) => {
    for (const tab of tabs) {
      tab.setAttribute('aria-selected', String(tab.getAttribute('aria-controls') === id));
    }
  };

  for (const tab of tabs) {
    tab.addEventListener('click', () => {
      const phone = document.getElementById(tab.getAttribute('aria-controls'));
      const left = phone.offsetLeft - (row.clientWidth - phone.offsetWidth) / 2;
      row.scrollTo({ left, behavior: 'smooth' });
      select(phone.id);
    });
  }

  const watcher = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) select(entry.target.id);
      }
    },
    { root: row, threshold: 0.6 },
  );
  for (const phone of row.querySelectorAll('.device')) watcher.observe(phone);
})();
