//= require_tree ./results

document.addEventListener('DOMContentLoaded', function() {
  if (!document.querySelector('.results-section')) return;

  // Initialize results functionality
  initViewToggles();
  initChartRendering();
  initTableManager();
});

function initTableManager() {
  var tableManager = new TableManager();
} 