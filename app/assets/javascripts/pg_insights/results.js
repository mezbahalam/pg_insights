
document.addEventListener('DOMContentLoaded', function() {
  if (!document.querySelector('.results-section')) return;

  initViewToggles();
  initChartRendering();
  initTableManager();
});

function initTableManager() {
  var tableManager = new TableManager();
}

// Initialize performance view enhancements
function initializePerformanceView() {
  // Apply threshold coloring
  applyThresholdColoring();
  
  // Initialize interactive elements
  initializeInteractiveElements();
  
  // Apply performance score coloring
  applyPerformanceScores();
}

// Apply threshold indicator coloring
function applyThresholdColoring() {
  const thresholds = document.querySelectorAll('.metric-threshold');
  
  thresholds.forEach(threshold => {
    const text = threshold.textContent.trim();
    
    if (text.includes('✓')) {
      threshold.style.background = '#dcfce7';
      threshold.style.color = '#166534';
    } else if (text.includes('⚠')) {
      threshold.style.background = '#fef3c7';
      threshold.style.color = '#92400e';
    }
  });
}

// Initialize interactive elements
function initializeInteractiveElements() {
  // Add click handlers for recommendation cards
  const recCards = document.querySelectorAll('.recommendation-card');
  
  recCards.forEach(card => {
    card.addEventListener('click', function() {
      // Toggle expanded state or copy hint to clipboard
      const hint = this.querySelector('.rec-hint');
      if (hint) {
        navigator.clipboard.writeText(hint.textContent);
        showNotification('SQL hint copied to clipboard');
      }
    });
  });
  
  // Add tooltips for performance badges
  const badges = document.querySelectorAll('.analysis-score, .perf-badge');
  
  badges.forEach(badge => {
    badge.addEventListener('mouseenter', function() {
      showTooltip(this, getPerformanceExplanation(this.textContent));
    });
    
    badge.addEventListener('mouseleave', function() {
      hideTooltip();
    });
  });
}

// Apply performance score coloring with JavaScript
function applyPerformanceScores() {
  const scores = document.querySelectorAll('.analysis-score');
  
  scores.forEach(score => {
    const text = score.textContent.toLowerCase();
    const classes = ['score-excellent', 'score-good', 'score-fair', 'score-poor', 'score-none'];
    
    // Remove existing score classes
    score.classList.remove(...classes);
    
    // Apply appropriate class based on content
    if (text === 'excellent') {
      score.classList.add('score-excellent');
    } else if (text === 'good') {
      score.classList.add('score-good');
    } else if (text === 'fair') {
      score.classList.add('score-fair');
    } else if (text === 'poor') {
      score.classList.add('score-poor');
    } else {
      score.classList.add('score-none');
    }
  });
}

// Show notification
function showNotification(message) {
  const notification = document.createElement('div');
  notification.className = 'perf-notification';
  notification.textContent = message;
  notification.style.cssText = `
    position: fixed;
    top: 20px;
    right: 20px;
    background: linear-gradient(135deg, #10b981, #059669);
    color: white;
    padding: 12px 16px;
    border-radius: 8px;
    font-size: 12px;
    font-weight: 600;
    z-index: 10000;
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
    opacity: 0;
    transform: translateX(100%);
    transition: all 0.3s ease;
  `;
  
  document.body.appendChild(notification);
  
  // Animate in
  setTimeout(() => {
    notification.style.opacity = '1';
    notification.style.transform = 'translateX(0)';
  }, 10);
  
  // Remove after delay
  setTimeout(() => {
    notification.style.opacity = '0';
    notification.style.transform = 'translateX(100%)';
    setTimeout(() => notification.remove(), 300);
  }, 2000);
}

// Show tooltip
function showTooltip(element, text) {
  hideTooltip(); // Remove any existing tooltip
  
  const tooltip = document.createElement('div');
  tooltip.className = 'perf-tooltip';
  tooltip.textContent = text;
  tooltip.style.cssText = `
    position: absolute;
    background: #1e293b;
    color: white;
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 11px;
    font-weight: 500;
    white-space: nowrap;
    z-index: 10000;
    pointer-events: none;
    opacity: 0;
    transform: translateY(-5px);
    transition: all 0.2s ease;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  `;
  
  document.body.appendChild(tooltip);
  
  // Position tooltip
  const rect = element.getBoundingClientRect();
  const tooltipRect = tooltip.getBoundingClientRect();
  
  tooltip.style.left = `${rect.left + (rect.width - tooltipRect.width) / 2}px`;
  tooltip.style.top = `${rect.top - tooltipRect.height - 8}px`;
  
  // Show tooltip
  setTimeout(() => {
    tooltip.style.opacity = '1';
    tooltip.style.transform = 'translateY(0)';
  }, 10);
}

// Hide tooltip
function hideTooltip() {
  const existingTooltip = document.querySelector('.perf-tooltip');
  if (existingTooltip) {
    existingTooltip.remove();
  }
}

// Get performance explanation
function getPerformanceExplanation(scoreText) {
  const explanations = {
    'excellent': 'Optimal performance with efficient resource usage',
    'good': 'Good performance with room for minor optimizations',  
    'fair': 'Acceptable performance but optimization recommended',
    'poor': 'Performance issues detected, optimization needed',
    'fast execution': 'Query executes within optimal time bounds',
    'efficient resource usage': 'Memory and CPU usage is well optimized',
    'good query plan': 'PostgreSQL chose an efficient execution plan'
  };
  
  return explanations[scoreText.toLowerCase()] || 'Performance metric indicator';
}

// Enhance timing bars with better animations
function enhanceTimingBars() {
  const timingBars = document.querySelectorAll('.timing-bar');
  
  timingBars.forEach((bar, index) => {
    // Add staggered animation delay
    bar.style.animationDelay = `${index * 0.1}s`;
    
    // Add hover effects
    bar.addEventListener('mouseenter', function() {
      this.style.filter = 'brightness(1.1) saturate(1.2)';
      this.style.transform = 'scaleY(1.1)';
    });
    
    bar.addEventListener('mouseleave', function() {
      this.style.filter = 'none';
      this.style.transform = 'scaleY(1)';
    });
  });
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  // Initialize performance view if it exists
  if (document.getElementById('perf-view')) {
    setTimeout(() => {
      initializePerformanceView();
      enhanceTimingBars();
    }, 100);
  }
});

// Re-initialize when perf tab is clicked
document.addEventListener('click', function(e) {
  if (e.target.closest('[data-tab="perf"]') || e.target.textContent === 'Perf') {
    setTimeout(() => {
      if (document.getElementById('perf-view').style.display !== 'none') {
        initializePerformanceView();
        enhanceTimingBars();
      }
    }, 50);
  }
}); 