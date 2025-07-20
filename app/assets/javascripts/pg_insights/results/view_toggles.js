function initViewToggles() {
  const toggleBtns = document.querySelectorAll('.toggle-btn');
  const views = {
    table: document.getElementById('table-view'),
    chart: document.getElementById('chart-view'),
    stats: document.getElementById('stats-view'),
    plan: document.getElementById('plan-view'),
    perf: document.getElementById('perf-view'),
    visual: document.getElementById('visual-view'),
    compare: document.getElementById('compare-view')
  };

  toggleBtns.forEach(function(btn) {
    btn.addEventListener('click', function() {
      const targetView = this.dataset.view;

      // Update active button
      toggleBtns.forEach(function(b) { b.classList.remove('active'); });
      this.classList.add('active');

      // Show/hide views
      Object.keys(views).forEach(function(viewName) {
        if (views[viewName]) {
          views[viewName].style.display = viewName === targetView ? 'block' : 'none';
        }
      });
      
      // Initialize table manager if switching to table view
      if (targetView === 'table' && typeof window.tableManager !== 'undefined') {
        window.tableManager.init();
      }
      
      // Initialize PEV2 if switching to visual view
      if (targetView === 'visual' && typeof window.initPEV2 !== 'undefined') {
        // Small delay to ensure the view is visible before initializing Vue
        setTimeout(function() {
          window.initPEV2();
        }, 100);
      }
    });
  });
} 