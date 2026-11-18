/* Shared mobile navigation for Fire Safety BD secondary admin pages.
   Presentation only: no form, API, authentication or database changes. */
document.addEventListener('DOMContentLoaded', () => {
  const shell = document.querySelector('.layout, .shell, .fs-admin-shell');
  if (!shell) return;
  const sidebar = shell.querySelector(':scope > aside');
  const content = shell.querySelector(':scope > main, :scope > .fs-admin-content');
  if (!sidebar || !content) return;

  const toggle = document.createElement('button');
  toggle.type = 'button';
  toggle.className = 'fs-admin-menu-toggle';
  toggle.textContent = '☰ মেনু';
  toggle.setAttribute('aria-expanded', 'false');
  toggle.setAttribute('aria-label', 'অ্যাডমিন মেনু খুলুন');
  sidebar.id ||= 'fs-admin-shared-sidebar';
  toggle.setAttribute('aria-controls', sidebar.id);
  content.insertBefore(toggle, content.firstChild);

  toggle.addEventListener('click', () => {
    const open = sidebar.classList.toggle('fs-admin-expanded');
    toggle.setAttribute('aria-expanded', String(open));
    toggle.setAttribute('aria-label', open ? 'অ্যাডমিন মেনু বন্ধ করুন' : 'অ্যাডমিন মেনু খুলুন');
  });
});
