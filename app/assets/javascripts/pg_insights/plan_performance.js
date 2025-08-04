// Enhanced Plan and Performance Views JavaScript - Simplified
document.addEventListener('DOMContentLoaded', function() {
  const PlanPerformanceEnhancer = {
    init() {
      // Apply score-based CSS classes to any remaining elements
      this.applyScoreClasses();
    },

    applyScoreClasses() {
      // Find elements that contain score text and apply appropriate classes
      const scoreElements = document.querySelectorAll('.stat-value, .metric-score, .kpi-value');
      
      scoreElements.forEach(element => {
        const text = element.textContent.toLowerCase().trim();
        let cssClass = '';
        
        switch(text) {
          case 'excellent':
            cssClass = 'score-excellent';
            break;
          case 'good':
            cssClass = 'score-good';
            break;
          case 'fair':
            cssClass = 'score-fair';
            break;
          case 'poor':
            cssClass = 'score-poor';
            break;
          case 'none':
            cssClass = 'score-none';
            break;
        }
        
        if (cssClass) {
          element.classList.add(cssClass);
        }
      });
    }
  };

  // Initialize enhanced views
  PlanPerformanceEnhancer.init();

  // Re-initialize when views are switched
  document.addEventListener('click', function(e) {
    if (e.target.matches('.toggle-btn[data-view="plan"]')) {
      setTimeout(() => PlanPerformanceEnhancer.applyScoreClasses(), 100);
    } else if (e.target.matches('.toggle-btn[data-view="perf"]')) {
      setTimeout(() => PlanPerformanceEnhancer.applyScoreClasses(), 100);
    }
  });
}); 