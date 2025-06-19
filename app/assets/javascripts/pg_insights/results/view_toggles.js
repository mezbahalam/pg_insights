function initViewToggles() {
  const toggleBtns = document.querySelectorAll('.toggle-btn');
  const views = {
    table: document.getElementById('table-view'),
    chart: document.getElementById('chart-view'),
    stats: document.getElementById('stats-view')
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
    });
  });
} 