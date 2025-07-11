
document.addEventListener('DOMContentLoaded', function() {
  if (!document.querySelector('.results-section')) return;

  initViewToggles();
  initChartRendering();
  initTableManager();
});

function initTableManager() {
  var tableManager = new TableManager();
} 