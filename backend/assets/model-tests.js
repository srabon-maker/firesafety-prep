(() => {
'use strict';

function initModelTestPage() {
  const list = document.getElementById('questionList');
  const sidebar = document.getElementById('modelTestSidebar');
  const menuButton = document.getElementById('modelTestMenuToggle');
  const debug = document.getElementById('selectionDebugPanel');
  const countNode = document.getElementById('selectedQuestionCount');
  const selectAllButton = document.getElementById('selectVisibleQuestions');
  const clearButton = document.getElementById('clearVisibleQuestions');

  const report = (message, ok) => {
    if (!debug) return;
    debug.textContent = message;
    debug.style.borderColor = ok ? '#16845b' : '#b42335';
    debug.style.background = ok ? '#effaf4' : '#fff1f1';
    debug.style.color = ok ? '#116b47' : '#9d1c2c';
  };

  if (menuButton && sidebar && !menuButton.dataset.bound) {
    menuButton.dataset.bound = '1';
    menuButton.addEventListener('click', () => {
      const open = sidebar.classList.toggle('menu-open');
      menuButton.setAttribute('aria-expanded', String(open));
    });
  }

  if (!list) {
    report('ত্রুটি: #questionList পাওয়া যায়নি। পেজের HTML/Deploy path পরীক্ষা প্রয়োজন।', false);
    return;
  }
  if (list.dataset.controllerBound === 'debug-1') {
    report('নির্বাচন ব্যবস্থা ইতিমধ্যে চালু আছে।', true);
    return;
  }
  list.dataset.controllerBound = 'debug-1';

  const searchInput = document.getElementById('questionSearch');
  const categoryFilter = document.getElementById('questionCategoryFilter');
  const emptyState = document.getElementById('questionEmpty');
  const previewModal = document.getElementById('questionPreviewModal');
  const previewBody = document.getElementById('questionPreviewBody');
  const rows = () => Array.from(list.querySelectorAll('.question-box'));
  const inputs = () => Array.from(list.querySelectorAll('input[type="checkbox"][name="question_ids[]"]'));
  const checkboxFor = row => row.querySelector('input[type="checkbox"][name="question_ids[]"]');

  function sync() {
    const all = inputs();
    let selected = 0;
    all.forEach(input => {
      const checked = input.checked === true;
      if (checked) selected++;
      const row = input.closest('.question-box');
      if (row) {
        row.classList.toggle('is-selected', checked);
        row.setAttribute('aria-selected', checked ? 'true' : 'false');
      }
    });
    if (countNode) countNode.textContent = 'নির্বাচিত: ' + selected;
    return selected;
  }

  function setAll(checked) {
    const all = inputs();
    all.forEach(input => {
      input.checked = checked;
      input.dispatchEvent(new Event('change', { bubbles: true }));
    });
    const selected = sync();
    report((checked ? 'সব প্রশ্ন নির্বাচন সম্পন্ন। ' : 'সব নির্বাচন বাতিল। ') +
      'Checkbox: ' + all.length + 'টি · নির্বাচিত: ' + selected + 'টি', !!all.length);
  }

  if (selectAllButton) {
    selectAllButton.type = 'button';
    selectAllButton.addEventListener('click', event => {
      event.preventDefault();
      event.stopPropagation();
      setAll(true);
    });
  }
  if (clearButton) {
    clearButton.type = 'button';
    clearButton.addEventListener('click', event => {
      event.preventDefault();
      event.stopPropagation();
      setAll(false);
    });
  }

  list.addEventListener('change', event => {
    if (event.target && event.target.matches('input[type="checkbox"][name="question_ids[]"]')) {
      const selected = sync();
      report('Checkbox পরিবর্তন ধরা হয়েছে। মোট Checkbox: ' + inputs().length +
        'টি · নির্বাচিত: ' + selected + 'টি', true);
    }
  });

  list.addEventListener('click', event => {
    const target = event.target;
    const row = target && target.closest ? target.closest('.question-box') : null;
    if (!row) return;
    if (target.closest('.move-question-up')) {
      event.preventDefault();
      move(row, -1);
      return;
    }
    if (target.closest('.move-question-down')) {
      event.preventDefault();
      move(row, 1);
      return;
    }
    const preview = target.closest('.preview-question');
    if (preview) {
      event.preventDefault();
      openPreview(preview.dataset.id);
      return;
    }
    if (target.closest('.question-select-label') || target.matches('input[type="checkbox"]')) return;
    const input = checkboxFor(row);
    if (input) {
      input.checked = !input.checked;
      sync();
      report('প্রশ্নে ক্লিক ধরা হয়েছে। নির্বাচিত: ' + inputs().filter(item => item.checked).length + 'টি', true);
    }
  });

  function move(row, direction) {
    const selected = rows().filter(item => checkboxFor(item)?.checked);
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
  if (searchInput) searchInput.addEventListener('input', applyFilters);
  if (categoryFilter) categoryFilter.addEventListener('change', applyFilters);

  const manual = document.getElementById('manualQuestions');
  document.querySelectorAll('input[name="selection_mode"]').forEach(radio => {
    radio.addEventListener('change', () => {
      if (manual) manual.style.display = radio.checked && radio.value === 'manual' ? 'block' : 'none';
    });
  });
  const selectedMode = document.querySelector('input[name="selection_mode"]:checked');
  if (manual) manual.style.display = selectedMode?.value === 'manual' ? 'block' : 'none';

  function openPreview(id) {
    const row = rows().find(item => checkboxFor(item)?.value === String(id));
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
  const closeButton = document.getElementById('closeQuestionPreview');
  if (closeButton) closeButton.addEventListener('click', closePreview);
  if (previewModal) previewModal.addEventListener('click', event => {
    if (event.target === previewModal) closePreview();
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') closePreview();
  });

  applyFilters();
  const selected = sync();
  const missing = [];
  if (!countNode) missing.push('Counter');
  if (!selectAllButton) missing.push('Select All');
  if (!clearButton) missing.push('Clear All');
  report('JavaScript চালু। Question List: পাওয়া গেছে · Checkbox: ' + inputs().length +
    'টি · নির্বাচিত: ' + selected + 'টি' +
    (missing.length ? ' · অনুপস্থিত: ' + missing.join(', ') : ''), missing.length === 0);
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initModelTestPage, { once: true });
} else {
  initModelTestPage();
}
})();