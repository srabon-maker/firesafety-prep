(() => {
'use strict';

function initModelTestPage() {
  const list = document.getElementById('questionList');
  const sidebar = document.getElementById('modelTestSidebar');
  const menuButton = document.getElementById('modelTestMenuToggle');

  if (menuButton && sidebar && !menuButton.dataset.bound) {
    menuButton.dataset.bound = '1';
    menuButton.addEventListener('click', () => {
      const open = sidebar.classList.toggle('menu-open');
      menuButton.setAttribute('aria-expanded', String(open));
    });
  }
  if (!list || list.dataset.controllerBound === '1') return;
  list.dataset.controllerBound = '1';

  const countNode = document.getElementById('selectedQuestionCount');
  const selectAllButton = document.getElementById('selectVisibleQuestions');
  const clearButton = document.getElementById('clearVisibleQuestions');
  const searchInput = document.getElementById('questionSearch');
  const categoryFilter = document.getElementById('questionCategoryFilter');
  const emptyState = document.getElementById('questionEmpty');
  const previewModal = document.getElementById('questionPreviewModal');
  const previewBody = document.getElementById('questionPreviewBody');

  const rows = () => Array.from(list.querySelectorAll('.question-box'));
  const checkbox = row => row.querySelector('input[name="question_ids[]"][type="checkbox"]');
  const inputs = () => Array.from(list.querySelectorAll('input[name="question_ids[]"][type="checkbox"]'));

  function sync() {
    const all = inputs();
    let selected = 0;
    all.forEach(input => {
      const checked = input.checked;
      if (checked) selected++;
      const row = input.closest('.question-box');
      if (row) {
        row.classList.toggle('is-selected', checked);
        row.setAttribute('aria-selected', checked ? 'true' : 'false');
      }
    });
    if (countNode) countNode.textContent = 'নির্বাচিত: ' + selected;
    const selectedRows = rows().filter(row => checkbox(row)?.checked);
    rows().forEach(row => {
      const up = row.querySelector('.move-question-up');
      const down = row.querySelector('.move-question-down');
      const index = selectedRows.indexOf(row);
      if (up) up.disabled = index <= 0;
      if (down) down.disabled = index < 0 || index === selectedRows.length - 1;
    });
    return selected;
  }

  function setAll(checked) {
    inputs().forEach(input => { input.checked = checked; });
    sync();
  }

  // Bind directly to the real controls. No duplicate inline controller or
  // document-level click interception is used for selection state.
  if (selectAllButton) {
    selectAllButton.type = 'button';
    selectAllButton.addEventListener('click', event => {
      event.preventDefault();
      setAll(true);
    });
  }
  if (clearButton) {
    clearButton.type = 'button';
    clearButton.addEventListener('click', event => {
      event.preventDefault();
      setAll(false);
    });
  }
  list.addEventListener('change', event => {
    if (event.target.matches('input[name="question_ids[]"][type="checkbox"]')) sync();
  });
  list.addEventListener('click', event => {
    const row = event.target.closest('.question-box');
    if (!row) return;
    if (event.target.closest('.move-question-up')) {
      event.preventDefault();
      move(row, -1);
      return;
    }
    if (event.target.closest('.move-question-down')) {
      event.preventDefault();
      move(row, 1);
      return;
    }
    const preview = event.target.closest('.preview-question');
    if (preview) {
      event.preventDefault();
      openPreview(preview.dataset.id);
      return;
    }
    if (event.target.closest('.question-select-label') || event.target.matches('input[type="checkbox"]')) return;
    const input = checkbox(row);
    if (input) {
      input.checked = !input.checked;
      sync();
    }
  });

  function move(row, direction) {
    const selected = rows().filter(item => checkbox(item)?.checked);
    const index = selected.indexOf(row);
    const target = selected[index + direction];
    if (index < 0 || !target) return;
    if (direction < 0) list.insertBefore(row, target);
    else list.insertBefore(target, row);
    sync();
  }

  function applyFilters() {
    const query = (searchInput?.value || '').trim().toLocaleLowerCase();
    const category = categoryFilter?.value || '';
    let visible = 0;
    rows().forEach(row => {
      const show = (row.dataset.search || '').includes(query) &&
        (!category || (row.dataset.category || '') === category);
      row.hidden = !show;
      if (show) visible++;
    });
    if (emptyState) emptyState.style.display = visible ? 'none' : 'block';
  }
  searchInput?.addEventListener('input', applyFilters);
  categoryFilter?.addEventListener('change', applyFilters);

  const manual = document.getElementById('manualQuestions');
  document.querySelectorAll('input[name="selection_mode"]').forEach(radio => {
    radio.addEventListener('change', () => {
      if (manual) manual.style.display = radio.checked && radio.value === 'manual' ? 'block' : 'none';
    });
  });
  const selectedMode = document.querySelector('input[name="selection_mode"]:checked');
  if (manual) manual.style.display = selectedMode?.value === 'manual' ? 'block' : 'none';

  function openPreview(id) {
    const row = rows().find(item => checkbox(item)?.value === String(id));
    if (!row || !previewModal || !previewBody) return;
    previewBody.replaceChildren();
    const heading = document.createElement('p');
    heading.textContent = (row.querySelector('.question-content strong')?.textContent || ('Question #' + id)) +
      ' — ' + (row.dataset.question || '');
    previewBody.appendChild(heading);
    const options = document.createElement('div');
    options.className = 'preview-options';
    ['a', 'b', 'c', 'd'].forEach(letter => {
      const value = row.dataset['option' + letter.toUpperCase()];
      if (value) {
        const item = document.createElement('div');
        item.className = 'preview-option';
        item.textContent = letter.toUpperCase() + '. ' + value;
        options.appendChild(item);
      }
    });
    previewBody.appendChild(options);
    previewModal.style.display = 'flex';
  }
  function closePreview() {
    if (previewModal) previewModal.style.display = 'none';
  }
  document.getElementById('closeQuestionPreview')?.addEventListener('click', closePreview);
  previewModal?.addEventListener('click', event => {
    if (event.target === previewModal) closePreview();
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') closePreview();
  });

  sync();
  applyFilters();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initModelTestPage, { once: true });
} else {
  initModelTestPage();
}
})();