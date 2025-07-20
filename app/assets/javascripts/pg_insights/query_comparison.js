// Query History and Comparison JavaScript
document.addEventListener('DOMContentLoaded', function() {
  // Only initialize if we're on the insights page
  if (!document.querySelector('.insights-container')) return;

  const QueryComparison = {
    selectedQueries: [],
    queryHistory: [],
    
    init() {
      this.bindEvents();
      this.loadQueryHistory();
    },
    
    bindEvents() {
      // Make functions globally available for onclick handlers
      window.toggleHistoryBar = this.toggleHistoryBar.bind(this);
      window.selectQuery = this.selectQuery.bind(this);
      window.triggerCompare = this.triggerCompare.bind(this);
      window.swapQueries = this.swapQueries.bind(this);
      window.performComparison = this.performComparison.bind(this);
    },
    
    loadQueryHistory() {
      const historyBar = document.getElementById('query-history-bar');
      if (!historyBar) return;
      
      fetch('/pg_insights/query_history.json')
        .then(response => response.json())
        .then(data => {
          this.queryHistory = data;
          this.renderHistoryItems(data);
          this.updateHistoryCount(data.length);
        })
        .catch(error => {
          console.error('Failed to load query history:', error);
          this.showHistoryError();
        });
    },
    
    renderHistoryItems(queries) {
      const loadingEl = document.querySelector('.history-loading');
      const itemsEl = document.querySelector('.history-items');
      const emptyEl = document.querySelector('.history-empty');
      
      loadingEl.style.display = 'none';
      
      if (queries.length === 0) {
        emptyEl.style.display = 'block';
        itemsEl.style.display = 'none';
        return;
      }
      
      emptyEl.style.display = 'none';
      itemsEl.style.display = 'grid';
      itemsEl.innerHTML = '';
      
      queries.forEach(query => {
        const item = this.createHistoryItem(query);
        itemsEl.appendChild(item);
      });
    },
    
    createHistoryItem(query) {
      const item = document.createElement('div');
      item.className = 'history-item';
      item.dataset.queryId = query.id;
      
      item.innerHTML = `
        <div class="history-checkbox">
          <input type="checkbox" id="query-${query.id}" onchange="selectQuery(${query.id}, this.checked)">
        </div>
        <div class="history-details">
          <div class="history-title-text">${query.title}</div>
          <div class="history-meta">
            <span>${query.created_at}</span>
            <span>${query.summary}</span>
          </div>
        </div>
        <div class="history-performance ${query.performance_class}"></div>
      `;
      
      return item;
    },
    
    selectQuery(queryId, selected) {
      const query = this.queryHistory.find(q => q.id === queryId);
      if (!query) return;
      
      if (selected) {
        if (this.selectedQueries.length < 2) {
          this.selectedQueries.push(query);
          document.querySelector(`[data-query-id="${queryId}"]`)?.classList.add('selected');
        } else {
          // Deselect the checkbox if we already have 2 selected
          document.getElementById(`query-${queryId}`).checked = false;
          alert('You can only select up to 2 queries for comparison.');
          return;
        }
      } else {
        this.selectedQueries = this.selectedQueries.filter(q => q.id !== queryId);
        document.querySelector(`[data-query-id="${queryId}"]`)?.classList.remove('selected');
      }
      
      this.updateSelectionUI();
    },
    
    updateSelectionUI() {
      const selectedCount = this.selectedQueries.length;
      const countEl = document.getElementById('selected-count');
      const selectedCountEl = document.querySelector('.selected-count');
      const compareBtnEl = document.getElementById('compare-btn');
      const compareTabEl = document.getElementById('compare-tab');
      
      if (selectedCount > 0) {
        countEl.textContent = selectedCount;
        selectedCountEl.style.display = 'inline';
        
        if (selectedCount === 2) {
          compareBtnEl.style.display = 'inline-block';
          compareTabEl.style.display = 'inline-flex';
        } else {
          compareBtnEl.style.display = 'none';
          compareTabEl.style.display = 'none';
        }
      } else {
        selectedCountEl.style.display = 'none';
        compareBtnEl.style.display = 'none';
        compareTabEl.style.display = 'none';
      }
    },
    
    toggleHistoryBar() {
      const historyBar = document.getElementById('query-history-bar');
      const isExpanded = historyBar.classList.contains('expanded');
      
      if (isExpanded) {
        historyBar.classList.remove('expanded');
        historyBar.classList.add('collapsed');
      } else {
        historyBar.classList.remove('collapsed');
        historyBar.classList.add('expanded');
      }
    },
    
    triggerCompare(event) {
      event.stopPropagation();
      
      if (this.selectedQueries.length !== 2) {
        alert('Please select exactly 2 queries to compare.');
        return;
      }
      
      // Switch to compare tab
      this.activateCompareTab();
      this.loadComparisonInterface();
    },
    
    activateCompareTab() {
      // Deactivate all tabs
      document.querySelectorAll('.toggle-btn').forEach(btn => btn.classList.remove('active'));
      
      // Activate compare tab
      const compareTab = document.getElementById('compare-tab');
      compareTab.classList.add('active');
      
      // Hide all views, show compare view
      document.querySelectorAll('.view-content').forEach(view => view.style.display = 'none');
      document.getElementById('compare-view').style.display = 'block';
    },
    
    loadComparisonInterface() {
      if (this.selectedQueries.length !== 2) return;
      
      const queryA = this.selectedQueries[0];
      const queryB = this.selectedQueries[1];
      
      // Update query selector cards
      this.updateQueryCard('a', queryA);
      this.updateQueryCard('b', queryB);
      
      // Hide empty state, show header
      document.getElementById('comparison-empty').style.display = 'none';
      document.querySelector('.compare-header').classList.add('active');
    },
    
    updateQueryCard(position, query) {
      const titleEl = document.getElementById(`compare-title-${position}`);
      const summaryEl = document.getElementById(`compare-summary-${position}`);
      const cardEl = document.querySelector(`.query-card.query-${position}`);
      
      titleEl.textContent = query.title;
      summaryEl.textContent = query.summary;
      cardEl.classList.add('selected');
    },
    
    swapQueries() {
      if (this.selectedQueries.length === 2) {
        [this.selectedQueries[0], this.selectedQueries[1]] = [this.selectedQueries[1], this.selectedQueries[0]];
        this.loadComparisonInterface();
      }
    },
    
    performComparison() {
      if (this.selectedQueries.length !== 2) return;
      
      // Show loading state
      document.getElementById('comparison-empty').style.display = 'none';
      document.getElementById('comparison-results').style.display = 'none';
      document.getElementById('comparison-loading').style.display = 'block';
      
      const executionIds = this.selectedQueries.map(q => q.id);
      
      fetch('/pg_insights/compare.json', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({ 
          execution_ids: executionIds,
          authenticity_token: document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        })
      })
      .then(response => response.json())
      .then(data => {
        if (data.error) {
          throw new Error(data.error);
        }
        this.renderComparisonResults(data);
      })
      .catch(error => {
        console.error('Comparison failed:', error);
        this.showComparisonError(error.message);
      });
    },
    
    renderComparisonResults(data) {
      document.getElementById('comparison-loading').style.display = 'none';
      document.getElementById('comparison-results').style.display = 'block';
      
      // Render metrics table
      this.renderMetricsTable(data);
      
      // Render winner summary
      this.renderWinnerSummary(data);
      
      // Render insights
      this.renderInsights(data);
      
      // Render execution plans
      this.renderExecutionPlans(data);
    },
    
    renderMetricsTable(data) {
      const tbody = document.getElementById('metrics-table-body');
      const execA = data.executions.a;
      const execB = data.executions.b;
      const comparison = data.comparison;
      
      tbody.innerHTML = '';
      
      // Helper function to create metric rows
      const createMetricRow = (label, valueA, valueB, difference, betterDirection = 'lower') => {
        const row = document.createElement('tr');
        
        let diffClass = 'metric-same';
        let diffText = '⚖️ Same';
        
        if (difference && difference !== '0%') {
          const isABetter = betterDirection === 'lower' ? 
            parseFloat(valueA) < parseFloat(valueB) : 
            parseFloat(valueA) > parseFloat(valueB);
          
          diffClass = isABetter ? 'metric-better' : 'metric-worse';
          diffText = difference;
        }
        
        row.innerHTML = `
          <td>${label}</td>
          <td>${valueA || 'N/A'}</td>
          <td>${valueB || 'N/A'}</td>
          <td class="${diffClass}">${diffText}</td>
        `;
        
        return row;
      };
      
      // Add metric rows
      tbody.appendChild(createMetricRow(
        '⏱️ Total Time',
        execA.metrics.total_time_ms ? `${execA.metrics.total_time_ms}ms` : null,
        execB.metrics.total_time_ms ? `${execB.metrics.total_time_ms}ms` : null,
        comparison.performance.time_difference_pct ? 
          `${Math.abs(comparison.performance.time_difference_pct)}% ${comparison.performance.time_faster === 'b' ? 'B faster' : 'A faster'}` : null
      ));
      
      tbody.appendChild(createMetricRow(
        '💰 Query Cost',
        execA.metrics.query_cost || null,
        execB.metrics.query_cost || null,
        comparison.performance.cost_difference_pct ? 
          `${Math.abs(comparison.performance.cost_difference_pct)}% ${comparison.performance.cost_cheaper === 'b' ? 'B cheaper' : 'A cheaper'}` : null
      ));
      
      tbody.appendChild(createMetricRow(
        '📋 Rows Returned',
        execA.metrics.rows_returned || null,
        execB.metrics.rows_returned || null,
        null
      ));
    },
    
    renderWinnerSummary(data) {
      const winnerEl = document.getElementById('winner-summary');
      const winner = data.comparison.winner;
      
      if (winner && winner !== 'unknown') {
        const winnerQuery = winner === 'a' ? 'Query A' : 'Query B';
        winnerEl.querySelector('.winner-text').textContent = `${winnerQuery} performs better overall`;
        winnerEl.style.display = 'block';
      } else {
        winnerEl.style.display = 'none';
      }
    },
    
    renderInsights(data) {
      const insightsList = document.getElementById('insights-list');
      const insights = data.comparison.insights || [];
      
      insightsList.innerHTML = '';
      
      if (insights.length === 0) {
        document.getElementById('insights-section').style.display = 'none';
        return;
      }
      
      document.getElementById('insights-section').style.display = 'block';
      
      insights.forEach(insight => {
        const item = document.createElement('div');
        item.className = 'insight-item';
        item.innerHTML = `
          <div class="insight-icon">💡</div>
          <div class="insight-text">${insight}</div>
        `;
        insightsList.appendChild(item);
      });
    },
    
    renderExecutionPlans(data) {
      const planAContent = document.getElementById('plan-a-content');
      const planBContent = document.getElementById('plan-b-content');
      
      const execA = data.executions.a;
      const execB = data.executions.b;
      
      // Render plan A
      if (execA.sql_text) {
        planAContent.innerHTML = this.formatPlanPreview(execA.sql_text);
      } else {
        planAContent.innerHTML = '<div style="color: #6b7280; font-style: italic;">No execution plan available</div>';
      }
      
      // Render plan B
      if (execB.sql_text) {
        planBContent.innerHTML = this.formatPlanPreview(execB.sql_text);
      } else {
        planBContent.innerHTML = '<div style="color: #6b7280; font-style: italic;">No execution plan available</div>';
      }
    },
    
    formatPlanPreview(sqlText) {
      // Format SQL text for preview
      const formattedSql = sqlText
        .replace(/SELECT/gi, '<span style="color: #059669; font-weight: 600;">SELECT</span>')
        .replace(/FROM/gi, '<span style="color: #0ea5e9; font-weight: 600;">FROM</span>')
        .replace(/WHERE/gi, '<span style="color: #8b5cf6; font-weight: 600;">WHERE</span>')
        .replace(/JOIN/gi, '<span style="color: #f59e0b; font-weight: 600;">JOIN</span>')
        .replace(/ORDER BY/gi, '<span style="color: #ef4444; font-weight: 600;">ORDER BY</span>')
        .replace(/GROUP BY/gi, '<span style="color: #ec4899; font-weight: 600;">GROUP BY</span>');
      
      return `
        <div style="background: #f4f4f5; padding: 8px; margin-bottom: 8px; font-weight: 600; color: #18181b; font-size: 12px;">
          SQL Query
        </div>
        <div style="line-height: 1.4; white-space: pre-wrap; font-size: 12px;">${formattedSql}</div>
      `;
    },
    
    updateHistoryCount(count) {
      document.querySelector('.history-count').textContent = `(${count})`;
    },
    
    showHistoryError() {
      const loadingEl = document.querySelector('.history-loading');
      const itemsEl = document.querySelector('.history-items');
      
      loadingEl.innerHTML = '<span style="color: #dc2626;">Failed to load query history</span>';
      itemsEl.style.display = 'none';
    },
    
    showComparisonError(message) {
      document.getElementById('comparison-loading').style.display = 'none';
      document.getElementById('comparison-results').style.display = 'none';
      document.getElementById('comparison-empty').innerHTML = `
        <div class="empty-icon">⚠️</div>
        <h3>Comparison Failed</h3>
        <p>${message}</p>
      `;
      document.getElementById('comparison-empty').style.display = 'block';
    }
  };
  
  // Initialize the comparison system
  QueryComparison.init();
  
  // Refresh history when a new analysis completes
  document.addEventListener('analysisCompleted', function() {
    QueryComparison.loadQueryHistory();
  });
}); 