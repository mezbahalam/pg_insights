function TableManager() {
  this.table = document.getElementById('resultsTable');
  this.tableScroll = document.getElementById('tableScroll');
  this.columnPanel = document.getElementById('columnPanel');
  this.originalColumnWidths = new Map();
  this.isResizing = false;

  if (this.table) {
    this.init();
  }
}

TableManager.prototype.init = function() {
  this.setupColumnToggles();
  this.setupTableControls();
  this.setupScrollIndicators();
  this.setupColumnResizing();
  this.setupKeyboardNavigation();
  this.detectColumnTypes();
};

TableManager.prototype.setupColumnToggles = function() {
  var self = this;
  var toggleBtn = document.getElementById('toggleColumns');
  var showAllBtn = document.getElementById('showAllColumns');
  var hideAllBtn = document.getElementById('hideAllColumns');
  var columnToggles = document.querySelectorAll('.column-toggle');

  if (toggleBtn && this.columnPanel) {
    toggleBtn.addEventListener('click', function() {
      var isVisible = self.columnPanel.style.display !== 'none';
      self.columnPanel.style.display = isVisible ? 'none' : 'block';
      toggleBtn.textContent = isVisible ? '👁️ Show/Hide Columns' : '👁️ Hide Panel';
    });
  }

  if (showAllBtn) {
    showAllBtn.addEventListener('click', function() {
      columnToggles.forEach(function(toggle) {
        toggle.checked = true;
        self.toggleColumn(toggle.dataset.column, true);
      });
    });
  }

  if (hideAllBtn) {
    hideAllBtn.addEventListener('click', function() {
      columnToggles.forEach(function(toggle) {
        toggle.checked = false;
        self.toggleColumn(toggle.dataset.column, false);
      });
    });
  }

  columnToggles.forEach(function(toggle) {
    toggle.addEventListener('change', function() {
      self.toggleColumn(toggle.dataset.column, toggle.checked);
    });
  });
};

TableManager.prototype.toggleColumn = function(columnIndex, show) {
  var columns = document.querySelectorAll('[data-column="' + columnIndex + '"]');
  columns.forEach(function(col) {
    if (show) {
      col.classList.remove('column-hidden');
      col.style.display = '';
    } else {
      col.classList.add('column-hidden');
      col.style.display = 'none';
    }
  });
};

TableManager.prototype.setupTableControls = function() {
  var self = this;
  var fitBtn = document.getElementById('fitColumns');
  var resetBtn = document.getElementById('resetTable');

  if (fitBtn) {
    fitBtn.addEventListener('click', function(e) { 
      e.preventDefault();
      self.fitColumns(); 
    });
  }

  if (resetBtn) {
    resetBtn.addEventListener('click', function(e) { 
      e.preventDefault();
      self.resetTable(); 
    });
  }
};

TableManager.prototype.fitColumns = function() {
  // Check if required elements exist
  if (!this.table || !this.tableScroll) {
    return;
  }

  // Get all non-row-number headers that are visible
  var headers = this.table.querySelectorAll('th:not(.row-num):not(.column-hidden)');
  
  if (headers.length === 0) {
    return;
  }

  // Calculate available width (subtract row number column and padding)
  var rowNumWidth = 60; // Width for row number column
  var scrollbarWidth = 20; // Account for scrollbar
  var padding = 20; // Additional padding
  var containerWidth = this.tableScroll.clientWidth - rowNumWidth - scrollbarWidth - padding;
  
  // Ensure minimum total width and calculate per-column width
  var minColumnWidth = 100;
  var maxColumnWidth = 300;
  var columnWidth = Math.max(minColumnWidth, Math.min(maxColumnWidth, containerWidth / headers.length));

  // Set table layout to fixed for consistent column sizing
  this.table.style.tableLayout = 'fixed';

  // Apply width to headers and corresponding cells
  headers.forEach(function(header, index) {
    var columnIndex = header.getAttribute('data-column');
    
    // Set header width
    header.style.width = columnWidth + 'px';
    header.style.minWidth = columnWidth + 'px';
    header.style.maxWidth = columnWidth + 'px';

    // Set corresponding cell widths
    var cells = document.querySelectorAll('td[data-column="' + columnIndex + '"]:not(.column-hidden)');
    cells.forEach(function(cell) {
      cell.style.width = columnWidth + 'px';
      cell.style.minWidth = columnWidth + 'px';
      cell.style.maxWidth = columnWidth + 'px';
    });
  });
};

TableManager.prototype.resetTable = function() {
  // Reset table layout
  if (this.table) {
    this.table.style.tableLayout = '';
  }

  // Reset all column and cell styles
  var allColumns = this.table.querySelectorAll('th, td');
  allColumns.forEach(function(col) {
    col.style.width = '';
    col.style.minWidth = '';
    col.style.maxWidth = '';
    col.style.display = '';
    col.classList.remove('column-hidden');
  });

  // Show all hidden columns
  var hiddenColumns = this.table.querySelectorAll('.column-hidden');
  hiddenColumns.forEach(function(col) { 
    col.classList.remove('column-hidden');
    col.style.display = '';
  });

  // Reset all column toggles to checked state
  var toggles = document.querySelectorAll('.column-toggle');
  toggles.forEach(function(toggle) { 
    toggle.checked = true; 
  });

  // Hide column panel
  if (this.columnPanel) {
    this.columnPanel.style.display = 'none';
    
    // Also reset the toggle button text
    var toggleBtn = document.getElementById('toggleColumns');
    if (toggleBtn) {
      toggleBtn.innerHTML = '<span class="btn-icon">👁️</span> Show/Hide Columns';
    }
  }
};

TableManager.prototype.setupScrollIndicators = function() {
  if (!this.tableScroll) return;

  var self = this;
  var scrollIndicatorH = document.getElementById('scrollIndicatorH');
  var scrollIndicatorV = document.getElementById('scrollIndicatorV');
  var scrollTimeout;

  this.tableScroll.addEventListener('scroll', function() {
    self.updateScrollIndicators();

    if (scrollIndicatorH) scrollIndicatorH.classList.add('visible');
    if (scrollIndicatorV) scrollIndicatorV.classList.add('visible');

    clearTimeout(scrollTimeout);
    scrollTimeout = setTimeout(function() {
      if (scrollIndicatorH) scrollIndicatorH.classList.remove('visible');
      if (scrollIndicatorV) scrollIndicatorV.classList.remove('visible');
    }, 1000);
  });

  this.updateScrollIndicators();
};

TableManager.prototype.updateScrollIndicators = function() {
  var scrollIndicatorH = document.getElementById('scrollIndicatorH');
  var scrollIndicatorV = document.getElementById('scrollIndicatorV');
  var scrollThumbH = document.getElementById('scrollThumbH');
  var scrollThumbV = document.getElementById('scrollThumbV');

  if (!this.tableScroll) return;

  var scrollLeft = this.tableScroll.scrollLeft;
  var scrollTop = this.tableScroll.scrollTop;
  var scrollWidth = this.tableScroll.scrollWidth;
  var scrollHeight = this.tableScroll.scrollHeight;
  var clientWidth = this.tableScroll.clientWidth;
  var clientHeight = this.tableScroll.clientHeight;

  if (scrollIndicatorH && scrollThumbH && scrollWidth > clientWidth) {
    var thumbWidth = (clientWidth / scrollWidth) * 100;
    var thumbLeft = (scrollLeft / (scrollWidth - clientWidth)) * (100 - thumbWidth);

    scrollThumbH.style.width = thumbWidth + '%';
    scrollThumbH.style.left = thumbLeft + '%';
  }

  if (scrollIndicatorV && scrollThumbV && scrollHeight > clientHeight) {
    var thumbHeight = (clientHeight / scrollHeight) * 100;
    var thumbTop = (scrollTop / (scrollHeight - clientHeight)) * (100 - thumbHeight);

    scrollThumbV.style.height = thumbHeight + '%';
    scrollThumbV.style.top = thumbTop + '%';
  }
};

TableManager.prototype.setupColumnResizing = function() {
  var self = this;
  var headers = this.table.querySelectorAll('th:not(.row-num)');

  headers.forEach(function(header, index) {
    var resizeHandle = document.createElement('div');
    resizeHandle.className = 'resize-handle';
    header.appendChild(resizeHandle);

    var startX, startWidth;

    resizeHandle.addEventListener('mousedown', function(e) {
      self.isResizing = true;
      startX = e.clientX;
      startWidth = parseInt(document.defaultView.getComputedStyle(header).width, 10);

      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);

      e.preventDefault();
    });

    var handleMouseMove = function(e) {
      if (!self.isResizing) return;

      var width = startWidth + e.clientX - startX;
      var minWidth = 80;
      var maxWidth = 500;
      var newWidth = Math.max(minWidth, Math.min(maxWidth, width));

      header.style.width = newWidth + 'px';
      header.style.minWidth = newWidth + 'px';
      header.style.maxWidth = newWidth + 'px';

      var cells = self.table.querySelectorAll('td[data-column="' + (index + 1) + '"]');
      cells.forEach(function(cell) {
        cell.style.width = newWidth + 'px';
        cell.style.minWidth = newWidth + 'px';
        cell.style.maxWidth = newWidth + 'px';
      });
    };

    var handleMouseUp = function() {
      self.isResizing = false;
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };
  });
};

TableManager.prototype.setupKeyboardNavigation = function() {
  var self = this;
  
  this.tableScroll.addEventListener('keydown', function(e) {
    if (!e.target.closest('.results-table')) return;

    var scrollAmount = 50;

    switch(e.key) {
      case 'ArrowLeft':
        self.tableScroll.scrollLeft -= scrollAmount;
        e.preventDefault();
        break;
      case 'ArrowRight':
        self.tableScroll.scrollLeft += scrollAmount;
        e.preventDefault();
        break;
      case 'ArrowUp':
        self.tableScroll.scrollTop -= scrollAmount;
        e.preventDefault();
        break;
      case 'ArrowDown':
        self.tableScroll.scrollTop += scrollAmount;
        e.preventDefault();
        break;
      case 'Home':
        if (e.ctrlKey) {
          self.tableScroll.scrollTop = 0;
          self.tableScroll.scrollLeft = 0;
        } else {
          self.tableScroll.scrollLeft = 0;
        }
        e.preventDefault();
        break;
      case 'End':
        if (e.ctrlKey) {
          self.tableScroll.scrollTop = self.tableScroll.scrollHeight;
          self.tableScroll.scrollLeft = self.tableScroll.scrollWidth;
        } else {
          self.tableScroll.scrollLeft = self.tableScroll.scrollWidth;
        }
        e.preventDefault();
        break;
    }
  });
};

TableManager.prototype.detectColumnTypes = function() {
  var headers = this.table.querySelectorAll('th:not(.row-num)');

  headers.forEach(function(header, index) {
    var cells = document.querySelectorAll('td[data-column="' + (index + 1) + '"] .cell-content');
    var typeSpan = header.querySelector('.header-type');

    if (!typeSpan || cells.length === 0) return;

    var numericCount = 0;
    var dateCount = 0;
    var sampleSize = Math.min(10, cells.length);

    for (var i = 0; i < sampleSize; i++) {
      var cell = cells[i];
      var value = cell.textContent.trim();

      if (value && value !== 'NULL' && value !== 'empty') {
        if (/^-?\d+(\.\d+)?$/.test(value)) {
          numericCount++;
        } else if (/^\d{4}-\d{2}-\d{2}/.test(value)) {
          dateCount++;
        }
      }
    }

    var numericRatio = numericCount / sampleSize;
    var dateRatio = dateCount / sampleSize;

    if (numericRatio > 0.7) {
      typeSpan.textContent = 'number';
      typeSpan.style.background = '#dcfce7';
      typeSpan.style.color = '#166534';
    } else if (dateRatio > 0.7) {
      typeSpan.textContent = 'date';
      typeSpan.style.background = '#e0f2fe';
      typeSpan.style.color = '#0c4a6e';
    } else {
      typeSpan.textContent = 'text';
      typeSpan.style.background = '#f1f5f9';
      typeSpan.style.color = '#64748b';
    }
  });
}; 