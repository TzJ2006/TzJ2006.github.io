function saveState(id) {
  const checkbox = document.getElementById(id);
  localStorage.setItem(id, checkbox.checked);
}

function loadState(id) {
  const checkbox = document.getElementById(id);
  const checked = localStorage.getItem(id) === 'true';
  if (checkbox) checkbox.checked = checked;
}

document.addEventListener('DOMContentLoaded', function () {
  // Add the IDs of your checkboxes here
  const checkboxIds = ['task1', 'task2', 'task3'];
  checkboxIds.forEach(loadState);
});
