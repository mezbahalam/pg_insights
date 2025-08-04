function initViewToggles() {
  const toggleBtns = document.querySelectorAll('.toggle-btn[data-view]:not(#compare-tab)');
  const views = {
    table: document.getElementById('table-view'),
    chart: document.getElementById('chart-view'),
    stats: document.getElementById('stats-view'),
    plan: document.getElementById('plan-view'),
    perf: document.getElementById('perf-view'),
    visual: document.getElementById('visual-view'),
    'empty-state': document.getElementById('empty-state')
  };

  toggleBtns.forEach(function(btn) {
    btn.addEventListener('click', function() {
      const targetView = this.dataset.view;

      // Skip if button is disabled
      if (this.classList.contains('disabled')) return;

      // Update active button
      document.querySelectorAll('.toggle-btn').forEach(function(b) { b.classList.remove('active'); });
      this.classList.add('active');

      // Show/hide views
      Object.keys(views).forEach(function(viewName) {
        const view = views[viewName];
        if (view) {
          view.style.display = viewName === targetView ? 'block' : 'none';
        }
      });
      
      // Hide compare view when switching to other views
      const compareView = document.getElementById('compare-view');
      if (compareView && targetView !== 'compare') {
        compareView.style.display = 'none';
      }
      
      // Initialize components based on target view
      if (targetView === 'table' && typeof window.tableManager !== 'undefined') {
        window.tableManager.init();
      } else if (targetView === 'visual' && typeof window.initPEV2 !== 'undefined') {
        setTimeout(() => window.initPEV2(), 100);
      }
    });
  });
} 