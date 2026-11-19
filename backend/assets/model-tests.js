const modeRadios=document.querySelectorAll('input[name="selection_mode"]:not(:disabled)');
const manual=document.getElementById('manualQuestions');
function updateMode(){
  const selected=document.querySelector('input[name="selection_mode"]:checked');
  if(manual) manual.style.display=selected?.value==='manual'?'block':'none';
  updateSelectionSummary();
}
modeRadios.forEach(x=>x.addEventListener('change',updateMode));
const questionList=document.getElementById('questionList');
const searchInput=document.getElementById('questionSearch');
const categoryFilter=document.getElementById('questionCategoryFilter');
const selectedCount=document.getElementById('selectedQuestionCount');
const emptyState=document.getElementById('questionEmpty');
function questionRows(){return questionList?[...questionList.querySelectorAll('.question-box')]:[];}
function updateSelectionSummary(){
  if(!selectedCount)return;
  questionRows().forEach(row=>{
    const checked=!!row.querySelector('input[type="checkbox"]')?.checked;
    row.classList.toggle('is-selected',checked);
    row.setAttribute('aria-selected',checked?'true':'false');
  });
  const selected=questionRows().filter(row=>row.querySelector('input[type="checkbox"]')?.checked).length;
  selectedCount.textContent='নির্বাচিত: '+selected;
  updateMoveButtons();
}
function applyQuestionFilters(){
  const query=(searchInput?.value||'').trim().toLocaleLowerCase();
  const category=categoryFilter?.value||'';
  let visible=0;
  questionRows().forEach(row=>{
    const matchesText=(row.dataset.search||'').includes(query);
    const matchesCategory=!category||(row.dataset.category||'')===category;
    const show=matchesText&&matchesCategory;
    row.hidden=!show;
    if(show)visible++;
  });
  if(emptyState)emptyState.style.display=visible?'none':'block';
}
function updateMoveButtons(){
  const selected=questionRows().filter(row=>row.querySelector('input[type="checkbox"]')?.checked);
  questionRows().forEach(row=>{
    const isSelected=row.querySelector('input[type="checkbox"]')?.checked;
    const up=row.querySelector('.move-question-up'),down=row.querySelector('.move-question-down');
    if(up)up.disabled=!isSelected||selected.indexOf(row)===0;
    if(down)down.disabled=!isSelected||selected.indexOf(row)===selected.length-1;
  });
}
function moveSelectedQuestion(row,direction){
  const selected=questionRows().filter(item=>item.querySelector('input[type="checkbox"]')?.checked);
  const index=selected.indexOf(row),target=selected[index+direction];
  if(index<0||!target)return;
  if(direction<0)questionList.insertBefore(row,target);
  else questionList.insertBefore(target,row);
  updateSelectionSummary();
}
questionList?.addEventListener('change',event=>{
  if(event.target.matches('input[type="checkbox"]'))updateSelectionSummary();
});
questionList?.addEventListener('click',event=>{
  const row=event.target.closest('.question-box');
  if(!row)return;
  if(event.target.closest('.move-question-up')){moveSelectedQuestion(row,-1);return;}
  if(event.target.closest('.move-question-down')){moveSelectedQuestion(row,1);return;}
  if(event.target.closest('.preview-question')){openQuestionPreview(event.target.closest('.preview-question').dataset.id);return;}
  // Let the browser handle a direct checkbox click. Clicking anywhere else
  // on the question card toggles that checkbox and synchronizes its visual state.
  if(event.target.closest('.question-select-label'))return;
  const checkbox=row.querySelector('input[type="checkbox"]');
  if(!checkbox)return;
  checkbox.checked=!checkbox.checked;
  checkbox.dispatchEvent(new Event('change',{bubbles:true}));
});
searchInput?.addEventListener('input',applyQuestionFilters);
categoryFilter?.addEventListener('change',applyQuestionFilters);
document.getElementById('selectVisibleQuestions')?.addEventListener('click',()=>{
  questionRows().forEach(row=>{const cb=row.querySelector('input[type="checkbox"]');if(cb)cb.checked=true;});
  updateSelectionSummary();
});
document.getElementById('clearVisibleQuestions')?.addEventListener('click',()=>{
  questionRows().forEach(row=>{const cb=row.querySelector('input[type="checkbox"]');if(cb)cb.checked=false;});
  updateSelectionSummary();
});
const previewModal=document.getElementById('questionPreviewModal');
const previewBody=document.getElementById('questionPreviewBody');
function openQuestionPreview(id){
  const row=questionRows().find(item=>item.querySelector('input[type="checkbox"]')?.value===String(id));
  if(!row||!previewModal||!previewBody)return;
  const title=row.querySelector('.question-content strong')?.textContent||('Question #'+id);
  previewBody.replaceChildren();
  const heading=document.createElement('p');heading.textContent=title+' — '+(row.dataset.question||'');previewBody.appendChild(heading);
  const options=document.createElement('div');options.className='preview-options';
  ['a','b','c','d'].forEach(letter=>{
    const value=row.dataset['option'+letter.toUpperCase()];
    if(value){const item=document.createElement('div');item.className='preview-option';item.textContent=letter.toUpperCase()+'. '+value;options.appendChild(item);}
  });
  previewBody.appendChild(options);
  previewModal.style.display='flex';
}
function closeQuestionPreview(){if(previewModal)previewModal.style.display='none';}
document.getElementById('closeQuestionPreview')?.addEventListener('click',closeQuestionPreview);
previewModal?.addEventListener('click',event=>{if(event.target===previewModal)closeQuestionPreview();});
document.addEventListener('keydown',event=>{if(event.key==='Escape')closeQuestionPreview();});
updateMode();
applyQuestionFilters();
