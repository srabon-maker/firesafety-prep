(() => {
'use strict';

function initModelTestQuestionPicker() {
  const questionList = document.getElementById('questionList');
  if (!questionList || questionList.dataset.selectionEventsReady === '1') return;
  questionList.dataset.selectionEventsReady = '1';

  const manual = document.getElementById('manualQuestions');
  const selectedCount = document.getElementById('selectedQuestionCount');
  const searchInput = document.getElementById('questionSearch');
  const categoryFilter = document.getElementById('questionCategoryFilter');
  const emptyState = document.getElementById('questionEmpty');
  const previewModal = document.getElementById('questionPreviewModal');
  const previewBody = document.getElementById('questionPreviewBody');

  const rows = () => Array.from(questionList.querySelectorAll('.question-box'));
  const checkboxFor = row => row.querySelector('input[type="checkbox"][name="question_ids[]"]');

  function updateMoveButtons() {
    const selected = rows().filter(row => checkboxFor(row)?.checked);
    rows().forEach(row => {
      const isSelected = !!checkboxFor(row)?.checked;
      const up = row.querySelector('.move-question-up');
      const down = row.querySelector('.move-question-down');
      if (up) up.disabled = !isSelected || selected.indexOf(row) === 0;
      if (down) down.disabled = !isSelected || selected.indexOf(row) === selected.length - 1;
    });
  }

  function syncSelection() {
    const allRows = rows();
    let count = 0;
    allRows.forEach(row => {
      const checked = !!checkboxFor(row)?.checked;
      row.classList.toggle('is-selected', checked);
      row.setAttribute('aria-selected', checked ? 'true' : 'false');
      if (checked) count++;
    });
    if (selectedCount) selectedCount.textContent = 'নির্বাচিত: ' + count;
    updateMoveButtons();
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

  function updateMode() {
    const selected = document.querySelector('input[name="selection_mode"]:checked');
    if (manual) manual.style.display = selected?.value === 'manual' ? 'block' : 'none';
    syncSelection();
  }

  function moveSelectedQuestion(row, direction) {
    const selected = rows().filter(item => checkboxFor(item)?.checked);
    const index = selected.indexOf(row);
    const target = selected[index + direction];
    if (index < 0 || !target) return;
    if (direction < 0) questionList.insertBefore(row, target);
    else questionList.insertBefore(target, row);
    syncSelection();
  }

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

  // Delegated listeners survive question-list redraws and do not depend on
  // individual buttons being bound before/after the picker is rendered.
  document.addEventListener('change', event => {
    if (event.target.matches('#questionList input[type="checkbox"][name="question_ids[]"]')) syncSelection();
    if (event.target.matches('input[name="selection_mode"]')) updateMode();
    if (event.target.matches('#questionCategoryFilter')) applyFilters();
  });

  document.addEventListener('input', event => {
    if (event.target.matches('#questionSearch')) applyFilters();
  });

  document.addEventListener('click', event => {
    const selectAll = event.target.closest('#selectVisibleQuestions');
    if (selectAll) {
      event.preventDefault();
      rows().forEach(row => { const cb = checkboxFor(row); if (cb) cb.checked = true; });
      syncSelection();
      return;
    }

    const clearAll = event.target.closest('#clearVisibleQuestions');
    if (clearAll) {
      event.preventDefault();
      rows().forEach(row => { const cb = checkboxFor(row); if (cb) cb.checked = false; });
      syncSelection();
      return;
    }

    if (event.target.closest('#closeQuestionPreview')) { closePreview(); return; }
    if (previewModal && event.target === previewModal) { closePreview(); return; }

    const row = event.target.closest('#questionList .question-box');
    if (!row) return;
    if (event.target.closest('.move-question-up')) { event.preventDefault(); moveSelectedQuestion(row, -1); return; }
    if (event.target.closest('.move-question-down')) { event.preventDefault(); moveSelectedQuestion(row, 1); return; }
    const preview = event.target.closest('.preview-question');
    if (preview) { event.preventDefault(); openPreview(preview.dataset.id); return; }

    // Checkbox label clicks use the browser's native label activation.
    if (event.target.closest('.question-select-label') || event.target.matches('input[type="checkbox"]')) return;
    const checkbox = checkboxFor(row);
    if (!checkbox) return;
    checkbox.checked = !checkbox.checked;
    checkbox.dispatchEvent(new Event('change', { bubbles: true }));
  });

  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') closePreview();
  });

  syncSelection();
  applyFilters();
  updateMode();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initModelTestQuestionPicker, { once: true });
} else {
  initModelTestQuestionPicker();
}
})();
