const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
if (!reduceMotion && 'IntersectionObserver' in window) {
 document.documentElement.classList.add('motion-ready');
 const observer = new IntersectionObserver(entries => {
  for (const entry of entries) if (entry.isIntersecting) {
   entry.target.classList.add('visible');
   observer.unobserve(entry.target);
  }
 }, { threshold: 0.08 });
 document.querySelectorAll('.reveal').forEach(element => observer.observe(element));
}
const tabs = [...document.querySelectorAll('[role="tab"]')];
function activate(tab, focus = false) {
 for (const item of tabs) {
  const selected = item === tab;
  item.setAttribute('aria-selected', String(selected));
  item.tabIndex = selected ? 0 : -1;
  const panel = document.getElementById(item.getAttribute('aria-controls'));
  if (panel) {
   panel.hidden = !selected;
   if (selected) panel.querySelectorAll('.reveal').forEach(element => element.classList.add('visible'));
  }
 }
 if (focus) tab.focus();
}
for (const tab of tabs) {
 tab.addEventListener('click', () => { activate(tab); history.replaceState(null, '', '#' + tab.getAttribute('aria-controls')); });
 tab.addEventListener('keydown', event => {
  let index = tabs.indexOf(tab);
  if (event.key === 'ArrowRight') index = (index + 1) % tabs.length;
  else if (event.key === 'ArrowLeft') index = (index + tabs.length - 1) % tabs.length;
  else if (event.key === 'Home') index = 0;
  else if (event.key === 'End') index = tabs.length - 1;
  else return;
  event.preventDefault(); activate(tabs[index], true);
 });
}
function activateHash() {
 const target = tabs.find(tab => '#' + tab.getAttribute('aria-controls') === location.hash);
 if (target) activate(target);
}
activateHash();
addEventListener('hashchange', activateHash);
