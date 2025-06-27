document.addEventListener('DOMContentLoaded', function() {
  initializeHealthDashboard();
});

function initializeHealthDashboard() {
  initializeSmoothScrolling();
  initializeSectionHighlighting();
  initializeResponsive();
}
function initializeSmoothScrolling() {
  const anchorLinks = document.querySelectorAll('a[href^="#"]');
  
  anchorLinks.forEach(link => {
    link.addEventListener('click', function(e) {
      const targetId = this.getAttribute('href').substring(1);
      const targetElement = document.getElementById(targetId);
      
      if (targetElement) {
        e.preventDefault();
        
        if (this.classList.contains('stat-card-link')) {
          this.classList.add('clicked');
          setTimeout(() => {
            this.classList.remove('clicked');
          }, 200);
        }
        
        const headerOffset = 20;
        const elementPosition = targetElement.getBoundingClientRect().top;
        const offsetPosition = elementPosition + window.pageYOffset - headerOffset;
        
        window.scrollTo({
          top: offsetPosition,
          behavior: 'smooth'
        });
        
        highlightSection(targetElement);
      }
    });
  });
}

function initializeSectionHighlighting() {
  if (window.location.hash) {
    const targetElement = document.querySelector(window.location.hash);
    if (targetElement) {
      setTimeout(() => {
        highlightSection(targetElement);
      }, 500);
    }
  }
}

function highlightSection(element) {
  const previousHighlighted = document.querySelector('.health-section.highlighted');
  if (previousHighlighted) {
    previousHighlighted.classList.remove('highlighted');
  }
  
  element.classList.add('highlighted');
  
  setTimeout(() => {
    element.classList.remove('highlighted');
  }, 2000);
}
function initializeResponsive() {
  let resizeTimeout;
  
  window.addEventListener('resize', function() {
    clearTimeout(resizeTimeout);
    resizeTimeout = setTimeout(function() {
      adjustForScreenSize();
    }, 250);
  });
  
  adjustForScreenSize();
}

function adjustForScreenSize() {
  const screenWidth = window.innerWidth;
  const queryTexts = document.querySelectorAll('.query-text');
  
  queryTexts.forEach(queryText => {
    if (screenWidth <= 768) {
      queryText.style.whiteSpace = 'normal';
      queryText.style.wordBreak = 'break-word';
    } else {
      queryText.style.whiteSpace = 'nowrap';
      queryText.style.wordBreak = 'normal';
    }
  });
}
function formatNumber(num) {
  return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

function truncateText(text, maxLength) {
  if (text.length <= maxLength) {
    return text;
  }
  return text.substring(0, maxLength - 3) + '...';
}

 