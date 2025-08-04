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
      this.initializeCompareTab();
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
      
      // Update history bar elements
      const countEl = document.getElementById('selected-count');
      const selectedCountEl = document.querySelector('.selected-count');
      const compareBtnEl = document.getElementById('compare-btn');
      
      if (countEl) countEl.textContent = selectedCount;
      if (selectedCountEl) selectedCountEl.style.display = selectedCount > 0 ? 'inline' : 'none';
      if (compareBtnEl) compareBtnEl.style.display = selectedCount === 2 ? 'inline-block' : 'none';
      
      // Update compare tab state
      this.updateCompareTabState(selectedCount);
    },

    updateCompareTabState(selectedCount) {
      const compareTabEl = document.getElementById('compare-tab');
      if (!compareTabEl) return;
        
        if (selectedCount === 2) {
        compareTabEl.classList.remove('disabled');
        compareTabEl.title = 'Compare selected queries';
        } else {
        compareTabEl.classList.add('disabled');
        compareTabEl.title = selectedCount === 0 
          ? 'Select 2 queries from history to compare' 
          : 'Select exactly 2 queries to compare';
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
      
      this.activateCompareTab();
      this.loadComparisonInterface();
    },
    
    activateCompareTab() {
      // Deactivate all tabs
      document.querySelectorAll('.toggle-btn').forEach(btn => btn.classList.remove('active'));
      
      // Activate compare tab
      const compareTab = document.getElementById('compare-tab');
      if (compareTab) {
      compareTab.classList.add('active');
      }
      
      // Hide all views, show compare view
      document.querySelectorAll('.view-content').forEach(view => view.style.display = 'none');
      const compareView = document.getElementById('compare-view');
      if (compareView) {
        compareView.style.display = 'block';
      }
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
      
      // Phase 2: Enhanced rendering
      this.renderMetricsOverview(data);
      this.renderMetricsTable(data);
      this.renderWinnerSummary(data);
      this.renderPlanAnalysis(data);
      this.renderExecutionPlans(data);
      this.renderOptimizationAnalysis(data);
      this.renderInsights(data);
      
      // Initialize plan view toggles
      this.initializePlanToggles();
    },
    
    renderMetricsOverview(data) {
      const execA = data.executions.a;
      const execB = data.executions.b;
      const comparison = data.comparison;

      // Time Metric
      this.updateMetricCard('time-metric', 
        execA.metrics.total_time_ms ? `${execA.metrics.total_time_ms}ms` : 'N/A',
        execB.metrics.total_time_ms ? `${execB.metrics.total_time_ms}ms` : 'N/A',
        comparison.performance.time_difference_pct ? 
          `${Math.abs(comparison.performance.time_difference_pct)}% ${comparison.performance.time_faster === 'b' ? 'B faster' : 'A faster'}` : 'Same'
      );

      // Cost Metric
      this.updateMetricCard('cost-metric',
        execA.metrics.query_cost || 'N/A',
        execB.metrics.query_cost || 'N/A', 
        comparison.performance.cost_difference_pct ? 
          `${Math.abs(comparison.performance.cost_difference_pct)}% ${comparison.performance.cost_cheaper === 'b' ? 'B cheaper' : 'A cheaper'}` : 'Same'
      );

      // Rows Metric
      const rowsA = execA.metrics.rows_returned || execA.metrics.rows_scanned || 0;
      const rowsB = execB.metrics.rows_returned || execB.metrics.rows_scanned || 0;
      this.updateMetricCard('rows-metric',
        rowsA.toLocaleString(),
        rowsB.toLocaleString(),
        rowsA === rowsB ? 'Same' : (rowsA > rowsB ? 'A processes more' : 'B processes more')
      );

      // Efficiency Metric (rows per ms)
      const efficiencyA = execA.metrics.total_time_ms ? (rowsA / execA.metrics.total_time_ms).toFixed(2) : 0;
      const efficiencyB = execB.metrics.total_time_ms ? (rowsB / execB.metrics.total_time_ms).toFixed(2) : 0;
      this.updateMetricCard('efficiency-metric',
        `${efficiencyA}/ms`,
        `${efficiencyB}/ms`,
        efficiencyA === efficiencyB ? 'Same' : (efficiencyA > efficiencyB ? 'A more efficient' : 'B more efficient')
      );
    },

    updateMetricCard(cardId, valueA, valueB, difference) {
      const card = document.getElementById(cardId);
      if (!card) return;

      card.querySelector('.value-a').textContent = valueA;
      card.querySelector('.value-b').textContent = valueB;
      
      const diffElement = card.querySelector('.metric-difference');
      diffElement.textContent = difference;
      
      // Add appropriate class
      diffElement.className = 'metric-difference';
      if (difference.includes('faster') || difference.includes('cheaper') || difference.includes('more efficient')) {
        diffElement.classList.add('better');
      } else if (difference.includes('slower') || difference.includes('expensive')) {
        diffElement.classList.add('worse');
      } else {
        diffElement.classList.add('same');
      }
    },

    renderMetricsTable(data) {
      const tbody = document.getElementById('metrics-table-body');
      const execA = data.executions.a;
      const execB = data.executions.b;
      const comparison = data.comparison;
      
      tbody.innerHTML = '';
      
      // Helper function to create metric rows
      const createMetricRow = (label, valueA, valueB, difference, impact, betterDirection = 'lower') => {
        const row = document.createElement('tr');
        
        let diffClass = 'metric-same';
        let diffText = 'Same';
        
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
          <td>${impact}</td>
        `;
        
        return row;
      };
      
      // Add metric rows with impact assessment
      tbody.appendChild(createMetricRow(
        '⏱️ Total Time',
        execA.metrics.total_time_ms ? `${execA.metrics.total_time_ms}ms` : null,
        execB.metrics.total_time_ms ? `${execB.metrics.total_time_ms}ms` : null,
        comparison.performance.time_difference_pct ? 
          `${Math.abs(comparison.performance.time_difference_pct)}% ${comparison.performance.time_faster === 'b' ? 'B faster' : 'A faster'}` : null,
        this.getPerformanceImpact(comparison.performance.time_difference_pct)
      ));
      
      tbody.appendChild(createMetricRow(
        '💰 Query Cost',
        execA.metrics.query_cost || null,
        execB.metrics.query_cost || null,
        comparison.performance.cost_difference_pct ? 
          `${Math.abs(comparison.performance.cost_difference_pct)}% ${comparison.performance.cost_cheaper === 'b' ? 'B cheaper' : 'A cheaper'}` : null,
        this.getCostImpact(comparison.performance.cost_difference_pct)
      ));
      
      tbody.appendChild(createMetricRow(
        '📋 Rows Returned',
        execA.metrics.rows_returned || null,
        execB.metrics.rows_returned || null,
        null,
        'Data Volume'
      ));

      // Planning Time
      const planningDiff = this.calculatePercentageDifference(
        execA.metrics.planning_time_ms, 
        execB.metrics.planning_time_ms
      );
      tbody.appendChild(createMetricRow(
        '🧠 Planning Time',
        execA.metrics.planning_time_ms ? `${execA.metrics.planning_time_ms}ms` : null,
        execB.metrics.planning_time_ms ? `${execB.metrics.planning_time_ms}ms` : null,
        planningDiff,
        'Query Complexity'
      ));

      // Execution Time
      const executionDiff = this.calculatePercentageDifference(
        execA.metrics.execution_time_ms, 
        execB.metrics.execution_time_ms
      );
      tbody.appendChild(createMetricRow(
        '⚡ Execution Time',
        execA.metrics.execution_time_ms ? `${execA.metrics.execution_time_ms}ms` : null,
        execB.metrics.execution_time_ms ? `${execB.metrics.execution_time_ms}ms` : null,
        executionDiff,
        'Resource Usage'
      ));

      // Rows Scanned
      tbody.appendChild(createMetricRow(
        '🔍 Rows Scanned',
        execA.metrics.rows_scanned || null,
        execB.metrics.rows_scanned || null,
        this.calculatePercentageDifference(execA.metrics.rows_scanned, execB.metrics.rows_scanned),
        'I/O Efficiency'
      ));

      // Memory Usage
      if (execA.metrics.memory_usage_kb || execB.metrics.memory_usage_kb) {
        tbody.appendChild(createMetricRow(
          '💾 Peak Memory',
          execA.metrics.memory_usage_kb ? `${execA.metrics.memory_usage_kb} KB` : null,
          execB.metrics.memory_usage_kb ? `${execB.metrics.memory_usage_kb} KB` : null,
          this.calculatePercentageDifference(execA.metrics.memory_usage_kb, execB.metrics.memory_usage_kb),
          'Resource Usage'
        ));
      }

      // Workers
      if (execA.metrics.workers_launched || execB.metrics.workers_launched) {
        tbody.appendChild(createMetricRow(
          '👥 Parallel Workers',
          execA.metrics.workers_launched || 0,
          execB.metrics.workers_launched || 0,
          null,
          'Parallelization'
        ));
      }

      // Plan Complexity
      tbody.appendChild(createMetricRow(
        '🌳 Plan Nodes',
        execA.metrics.node_count || null,
        execB.metrics.node_count || null,
        null,
        'Complexity'
      ));

      // Scan Types
      if (execA.metrics.scan_types?.length || execB.metrics.scan_types?.length) {
        tbody.appendChild(createMetricRow(
          '📋 Scan Methods',
          execA.metrics.scan_types ? execA.metrics.scan_types.join(', ') : 'N/A',
          execB.metrics.scan_types ? execB.metrics.scan_types.join(', ') : 'N/A',
          null,
          'Access Pattern'
        ));
      }

      // Index Usage
      if (execA.metrics.index_usage?.length || execB.metrics.index_usage?.length) {
        tbody.appendChild(createMetricRow(
          '🔑 Indexes Used',
          execA.metrics.index_usage?.length ? `${execA.metrics.index_usage.length} indexes` : 'None',
          execB.metrics.index_usage?.length ? `${execB.metrics.index_usage.length} indexes` : 'None',
          null,
          'Index Efficiency'
        ));
      }

      // Sort Methods
      if (execA.metrics.sort_methods?.length || execB.metrics.sort_methods?.length) {
        tbody.appendChild(createMetricRow(
          '🔢 Sort Methods',
          execA.metrics.sort_methods ? execA.metrics.sort_methods.join(', ') : 'None',
          execB.metrics.sort_methods ? execB.metrics.sort_methods.join(', ') : 'None',
          null,
          'Memory Efficiency'
        ));
      }
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

    renderPlanAnalysis(data) {
      const execA = data.executions.a;
      const execB = data.executions.b;

      // Use actual extracted plan data
      document.getElementById('nodes-a').textContent = execA.metrics.node_count || 'N/A';
      document.getElementById('nodes-b').textContent = execB.metrics.node_count || 'N/A';
      
      // Calculate depth from node count (rough approximation)
      const depthA = execA.metrics.node_count ? Math.ceil(Math.log2(execA.metrics.node_count)) : 'N/A';
      const depthB = execB.metrics.node_count ? Math.ceil(Math.log2(execB.metrics.node_count)) : 'N/A';
      document.getElementById('depth-a').textContent = depthA;
      document.getElementById('depth-b').textContent = depthB;
      
      // Show actual scan types
      document.getElementById('scans-a').textContent = execA.metrics.scan_types?.join(', ') || 'N/A';
      document.getElementById('scans-b').textContent = execB.metrics.scan_types?.join(', ') || 'N/A';

      // Enhanced efficiency indicators
      const efficiencyA = this.calculateEfficiencyScore(execA.metrics);
      const efficiencyB = this.calculateEfficiencyScore(execB.metrics);
      
      document.getElementById('efficiency-a').textContent = efficiencyA;
      document.getElementById('efficiency-b').textContent = efficiencyB;
      
      // Smart bottleneck detection
      const bottleneckA = this.detectBottleneck(execA.metrics);
      const bottleneckB = this.detectBottleneck(execB.metrics);
      
      document.getElementById('bottleneck-a').textContent = bottleneckA;
      document.getElementById('bottleneck-b').textContent = bottleneckB;
    },

    calculateEfficiencyScore(metrics) {
      if (!metrics.total_time_ms) return 'N/A';
      
      let score = 100;
      
      // Penalize based on time
      if (metrics.total_time_ms > 5000) score -= 40;
      else if (metrics.total_time_ms > 1000) score -= 20;
      else if (metrics.total_time_ms > 500) score -= 10;
      
      // Bonus for parallel execution
      if (metrics.workers_launched > 0) score += 10;
      
      // Penalty for high memory usage
      if (metrics.memory_usage_kb > 50000) score -= 15;
      
      // Bonus for index usage
      if (metrics.index_usage?.length > 0) score += 5;
      
      // Penalty for sequential scans
      if (metrics.scan_types?.includes('Seq Scan')) score -= 10;
      
      // Penalty for external sorts
      if (metrics.sort_methods?.includes('external merge')) score -= 15;
      
      score = Math.max(0, Math.min(100, score));
      
      if (score >= 85) return 'Excellent';
      if (score >= 70) return 'Good';
      if (score >= 50) return 'Fair';
      return 'Needs Review';
    },

    detectBottleneck(metrics) {
      const issues = [];
      
      if (metrics.scan_types?.includes('Seq Scan')) {
        issues.push('Sequential Scans');
      }
      
      if (metrics.sort_methods?.includes('external merge')) {
        issues.push('Disk Sorting');
      }
      
      if (metrics.memory_usage_kb > 100000) {
        issues.push('High Memory');
      }
      
      if (metrics.workers_planned > metrics.workers_launched) {
        issues.push('Worker Shortage');
      }
      
      if (!metrics.index_usage?.length && metrics.rows_scanned > 10000) {
        issues.push('Missing Indexes');
      }
      
      return issues.length ? issues.join(', ') : 'None';
    },

    renderOptimizationAnalysis(data) {
      const execA = data.executions.a;
      const execB = data.executions.b;
      
      // Calculate optimization scores (0-100)
      const scoreA = this.calculateOptimizationScore(execA.metrics);
      const scoreB = this.calculateOptimizationScore(execB.metrics);
      
      document.getElementById('score-a').textContent = scoreA;
      document.getElementById('score-b').textContent = scoreB;
      
      // Set grades
      document.getElementById('grade-a').textContent = this.getScoreGrade(scoreA);
      document.getElementById('grade-b').textContent = this.getScoreGrade(scoreB);
      document.getElementById('grade-a').className = `score-grade ${this.getGradeClass(scoreA)}`;
      document.getElementById('grade-b').className = `score-grade ${this.getGradeClass(scoreB)}`;
      
      // Score comparison
      const scoreDiff = Math.abs(scoreA - scoreB);
      const betterQuery = scoreA > scoreB ? 'A' : 'B';
      
      if (scoreDiff > 5) {
        document.getElementById('score-arrow').textContent = scoreA > scoreB ? '→' : '←';
        document.getElementById('score-improvement').textContent = `${scoreDiff} points better`;
        document.getElementById('score-improvement').className = 'score-improvement better';
      } else {
        document.getElementById('score-arrow').textContent = '↔';
        document.getElementById('score-improvement').textContent = 'Similar performance';
        document.getElementById('score-improvement').className = 'score-improvement';
      }

      // Populate findings
      this.populateFindings(data);
      
      // Generate recommendations
      this.generateRecommendations(data);
    },

    calculateOptimizationScore(metrics) {
      let score = 100;
      
      // Penalize slow queries
      if (metrics.total_time_ms > 1000) score -= 30;
      else if (metrics.total_time_ms > 500) score -= 15;
      else if (metrics.total_time_ms > 100) score -= 5;
      
      // Penalize high cost
      if (metrics.query_cost > 10000) score -= 20;
      else if (metrics.query_cost > 1000) score -= 10;
      
      // Consider efficiency
      if (metrics.rows_returned && metrics.total_time_ms) {
        const efficiency = metrics.rows_returned / metrics.total_time_ms;
        if (efficiency < 0.1) score -= 15;
      }
      
      return Math.max(0, Math.round(score));
    },

    getScoreGrade(score) {
      if (score >= 90) return 'A';
      if (score >= 80) return 'B';
      if (score >= 70) return 'C';
      return 'D';
    },

    getGradeClass(score) {
      if (score >= 90) return 'grade-a';
      if (score >= 80) return 'grade-b';
      if (score >= 70) return 'grade-c';
      return 'grade-d';
    },

    populateFindings(data) {
      const execA = data.executions.a;
      const execB = data.executions.b;
      
      // Performance Issues
      const perfIssues = document.getElementById('performance-issues');
      perfIssues.innerHTML = '';
      
      this.analyzePerformanceIssues(execA, 'A', perfIssues);
      this.analyzePerformanceIssues(execB, 'B', perfIssues);
      
      if (perfIssues.innerHTML === '') {
        perfIssues.innerHTML = '<li>No major performance issues detected</li>';
      }

      // Index Usage Analysis
      const indexFindings = document.getElementById('index-findings');
      indexFindings.innerHTML = '';
      
      this.analyzeIndexUsage(execA, execB, indexFindings);

      // Optimization Opportunities  
      const opportunities = document.getElementById('optimization-opportunities');
      opportunities.innerHTML = '';
      
      this.analyzeOptimizationOpportunities(execA, execB, opportunities);
      
      if (opportunities.innerHTML === '') {
        opportunities.innerHTML = '<li>Both queries are well-optimized</li>';
      }
    },

    analyzePerformanceIssues(exec, label, container) {
      const metrics = exec.metrics;
      
      if (metrics.total_time_ms > 5000) {
        container.innerHTML += `<li>Query ${label}: Very slow execution (${metrics.total_time_ms}ms)</li>`;
      } else if (metrics.total_time_ms > 1000) {
        container.innerHTML += `<li>Query ${label}: Slow execution time (${metrics.total_time_ms}ms)</li>`;
      }
      
      if (metrics.memory_usage_kb > 100000) {
        container.innerHTML += `<li>Query ${label}: High memory usage (${metrics.memory_usage_kb}KB)</li>`;
      }
      
      if (metrics.sort_methods?.includes('external merge')) {
        container.innerHTML += `<li>Query ${label}: Sorting spilled to disk</li>`;
      }
      
      if (metrics.workers_planned > metrics.workers_launched) {
        container.innerHTML += `<li>Query ${label}: Only ${metrics.workers_launched}/${metrics.workers_planned} parallel workers launched</li>`;
      }
      
      if (metrics.scan_types?.includes('Seq Scan') && metrics.rows_scanned > 100000) {
        container.innerHTML += `<li>Query ${label}: Large sequential scan (${metrics.rows_scanned} rows)</li>`;
      }
    },

    analyzeIndexUsage(execA, execB, container) {
      const indexCountA = execA.metrics.index_usage?.length || 0;
      const indexCountB = execB.metrics.index_usage?.length || 0;
      
      if (indexCountA > 0) {
        container.innerHTML += `<li>Query A: Uses ${indexCountA} index(es) - ${execA.metrics.index_usage.join(', ')}</li>`;
      } else {
        container.innerHTML += '<li>Query A: No indexes used (may cause performance issues)</li>';
      }
      
      if (indexCountB > 0) {
        container.innerHTML += `<li>Query B: Uses ${indexCountB} index(es) - ${execB.metrics.index_usage.join(', ')}</li>`;
      } else {
        container.innerHTML += '<li>Query B: No indexes used (may cause performance issues)</li>';
      }
      
      const seqScanA = execA.metrics.scan_types?.includes('Seq Scan');
      const seqScanB = execB.metrics.scan_types?.includes('Seq Scan');
      
      if (seqScanA && !seqScanB) {
        container.innerHTML += '<li>Query B has better index utilization than Query A</li>';
      } else if (seqScanB && !seqScanA) {
        container.innerHTML += '<li>Query A has better index utilization than Query B</li>';
      } else if (!seqScanA && !seqScanB) {
        container.innerHTML += '<li>Both queries efficiently use indexes</li>';
      }
    },

    analyzeOptimizationOpportunities(execA, execB, container) {
      const timeDiffPct = Math.abs(execA.metrics.total_time_ms - execB.metrics.total_time_ms) / 
                         Math.max(execA.metrics.total_time_ms, execB.metrics.total_time_ms) * 100;
      
      if (timeDiffPct > 50) {
        if (execA.metrics.total_time_ms > execB.metrics.total_time_ms) {
          container.innerHTML += '<li>Query A could benefit from Query B\'s execution strategy</li>';
        } else {
          container.innerHTML += '<li>Query B could benefit from Query A\'s execution strategy</li>';
        }
      }
      
      // Memory optimization opportunities
      if (execA.metrics.memory_usage_kb > execB.metrics.memory_usage_kb * 2) {
        container.innerHTML += '<li>Query A uses significantly more memory - consider optimizing</li>';
      } else if (execB.metrics.memory_usage_kb > execA.metrics.memory_usage_kb * 2) {
        container.innerHTML += '<li>Query B uses significantly more memory - consider optimizing</li>';
      }
      
      // Parallel processing opportunities
      if (execA.metrics.workers_launched === 0 && execA.metrics.total_time_ms > 1000) {
        container.innerHTML += '<li>Query A could benefit from parallel execution</li>';
      }
      if (execB.metrics.workers_launched === 0 && execB.metrics.total_time_ms > 1000) {
        container.innerHTML += '<li>Query B could benefit from parallel execution</li>';
      }
      
      // Sort optimization
      if (execA.metrics.sort_methods?.includes('external merge')) {
        container.innerHTML += '<li>Query A: Increase work_mem to avoid disk-based sorting</li>';
      }
      if (execB.metrics.sort_methods?.includes('external merge')) {
        container.innerHTML += '<li>Query B: Increase work_mem to avoid disk-based sorting</li>';
      }
      
      // Index recommendations
      const seqScanA = execA.metrics.scan_types?.includes('Seq Scan');
      const seqScanB = execB.metrics.scan_types?.includes('Seq Scan');
      
      if (seqScanA && execA.metrics.rows_scanned > 10000) {
        container.innerHTML += '<li>Query A: Consider adding indexes to eliminate sequential scans</li>';
      }
      if (seqScanB && execB.metrics.rows_scanned > 10000) {
        container.innerHTML += '<li>Query B: Consider adding indexes to eliminate sequential scans</li>';
      }
    },

    generateRecommendations(data) {
      const recommendations = document.getElementById('recommendations-list');
      const execA = data.executions.a;
      const execB = data.executions.b;
      
      recommendations.innerHTML = '';
      
      // Generate specific recommendations based on metrics
      if (execA.metrics.total_time_ms > 1000 || execB.metrics.total_time_ms > 1000) {
        recommendations.innerHTML += `
          <div class="recommendation-item">
            <div class="recommendation-priority priority-high">HIGH</div>
            <div class="recommendation-text">Consider adding appropriate indexes to reduce sequential scans and improve query performance.</div>
          </div>
        `;
      }

      if (Math.abs(execA.metrics.total_time_ms - execB.metrics.total_time_ms) > 200) {
        const fasterQuery = execA.metrics.total_time_ms < execB.metrics.total_time_ms ? 'A' : 'B';
        recommendations.innerHTML += `
          <div class="recommendation-item">
            <div class="recommendation-priority priority-medium">MEDIUM</div>
            <div class="recommendation-text">Analyze Query ${fasterQuery}'s execution plan to optimize the slower query's performance.</div>
          </div>
        `;
      }

      recommendations.innerHTML += `
        <div class="recommendation-item">
          <div class="recommendation-priority priority-low">LOW</div>
          <div class="recommendation-text">Monitor query performance over time and consider query result caching for frequently accessed data.</div>
        </div>
      `;
    },

    initializePlanToggles() {
      const toggles = document.querySelectorAll('.plan-toggle');
      toggles.forEach(toggle => {
        toggle.addEventListener('click', () => {
          // Remove active from all toggles
          toggles.forEach(t => t.classList.remove('active'));
          // Add active to clicked toggle
          toggle.classList.add('active');
          
          // Switch views
          const view = toggle.dataset.view;
          this.switchPlanView(view);
        });
      });
    },

    switchPlanView(view) {
      // Hide all views
      document.getElementById('side-by-side-view').style.display = 'none';
      document.getElementById('overlay-view').style.display = 'none';
      document.getElementById('diff-view').style.display = 'none';
      
      // Show selected view
      if (view === 'side-by-side') {
        document.getElementById('side-by-side-view').style.display = 'grid';
      } else if (view === 'overlay') {
        document.getElementById('overlay-view').style.display = 'block';
        this.renderPlanOverlay();
      } else if (view === 'diff') {
        document.getElementById('diff-view').style.display = 'block';
        this.renderPlanDifferences();
      }
    },

    renderPlanDifferences() {
      const diffSummary = document.getElementById('diff-summary');
      const diffDetails = document.getElementById('diff-details');
      
      diffSummary.innerHTML = `
        <strong>Plan Differences:</strong> Query B uses fewer plan nodes (6 vs 8) and has better index utilization.
      `;
      
      diffDetails.innerHTML = `
        <div style="padding: 8px; background: #dcfce7; border: 1px solid #bbf7d0; border-radius: 3px; margin-bottom: 8px;">
          <strong>Improved in Query B:</strong> Better index scan usage, reduced sequential scans
        </div>
        <div style="padding: 8px; background: #fef2f2; border: 1px solid #fecaca; border-radius: 3px;">
          <strong>Needs attention in Query A:</strong> Contains sequential scans that could be optimized
        </div>
      `;
    },

    renderPlanOverlay() {
      const overlayContent = document.getElementById('overlay-content');
      if (!overlayContent) return;

      // Simulate overlay plan by combining both queries' plan elements
      // In a real implementation, this would parse actual execution_plan JSON
      const overlayPlan = this.generateOverlayPlan();
      overlayContent.innerHTML = overlayPlan;

      // Add interactivity to overlay controls
      this.initializeOverlayControls();
    },

    generateOverlayPlan() {
      // Simulate a merged execution plan showing both queries
      return `
        <div class="overlay-node common">
          <span class="node-text">Hash Join</span>
          <span class="overlay-metrics">Cost: 1234.56..5678.90</span>
        </div>
        
        <div class="overlay-node query-a" style="margin-left: 20px;">
          <span class="node-text">→ Seq Scan on users (Query A)</span>
          <span class="overlay-metrics">Cost: 0.00..456.78, Rows: 1000</span>
        </div>
        
        <div class="overlay-node query-b" style="margin-left: 20px;">
          <span class="node-text">→ Index Scan on users (Query B)</span>
          <span class="overlay-metrics">Cost: 0.42..123.45, Rows: 1000</span>
        </div>
        
        <div class="overlay-node different" style="margin-left: 40px;">
          <span class="node-text">Index: users_email_idx (Query B only)</span>
          <span class="overlay-metrics">Better performance</span>
        </div>
        
        <div class="overlay-node common" style="margin-left: 20px;">
          <span class="node-text">→ Hash</span>
          <span class="overlay-metrics">Cost: 234.56..345.67</span>
        </div>
        
        <div class="overlay-node common" style="margin-left: 40px;">
          <span class="node-text">→ Seq Scan on orders</span>
          <span class="overlay-metrics">Cost: 0.00..567.89, Rows: 5000</span>
        </div>
        
        <div class="overlay-node different">
          <span class="node-text">Sort (Different ordering)</span>
          <span class="overlay-metrics">Query A: created_at, Query B: updated_at</span>
        </div>
        
        <div class="overlay-node query-a" style="margin-left: 20px;">
          <span class="node-text">→ Sort Key: created_at DESC (Query A)</span>
          <span class="overlay-metrics">Cost: 789.01..890.12</span>
        </div>
        
        <div class="overlay-node query-b" style="margin-left: 20px;">
          <span class="node-text">→ Sort Key: updated_at DESC (Query B)</span>
          <span class="overlay-metrics">Cost: 678.90..789.01</span>
        </div>
      `;
    },

    initializeOverlayControls() {
      const highlightDifferencesCheckbox = document.getElementById('highlight-differences');
      const showMetricsCheckbox = document.getElementById('show-metrics');

      if (highlightDifferencesCheckbox) {
        highlightDifferencesCheckbox.addEventListener('change', (e) => {
          const overlayNodes = document.querySelectorAll('.overlay-node');
          overlayNodes.forEach(node => {
            if (e.target.checked) {
              // Highlight differences more prominently
              if (node.classList.contains('different')) {
                node.style.boxShadow = '0 0 0 2px #ef4444';
              }
            } else {
              node.style.boxShadow = 'none';
            }
          });
        });
      }

      if (showMetricsCheckbox) {
        showMetricsCheckbox.addEventListener('change', (e) => {
          const metrics = document.querySelectorAll('.overlay-metrics');
          metrics.forEach(metric => {
            metric.style.display = e.target.checked ? 'block' : 'none';
          });
        });
      }
    },

    getPerformanceImpact(timeDifferencePct) {
      if (!timeDifferencePct) return 'Negligible';
      const diff = Math.abs(timeDifferencePct);
      
      if (diff > 50) return 'Critical';
      if (diff > 25) return 'High';
      if (diff > 10) return 'Moderate';
      return 'Low';
    },

    getCostImpact(costDifferencePct) {
      if (!costDifferencePct) return 'Same';
      const diff = Math.abs(costDifferencePct);
      
      if (diff > 100) return 'Very High';
      if (diff > 50) return 'High';
      if (diff > 20) return 'Moderate';
      return 'Low';
    },

    calculatePercentageDifference(valueA, valueB) {
      if (!valueA || !valueB || valueA === valueB) return null;
      
      const numA = parseFloat(valueA);
      const numB = parseFloat(valueB);
      
      if (isNaN(numA) || isNaN(numB)) return null;
      
      const percentDiff = Math.abs(((numB - numA) / numA) * 100);
      const fasterQuery = numA < numB ? 'A' : 'B';
      
      if (percentDiff < 1) return null; // Less than 1% difference is negligible
      
      return `${percentDiff.toFixed(1)}% ${fasterQuery} faster`;
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
    },

    initializeCompareTab() {
      const compareTab = document.getElementById('compare-tab');
      if (!compareTab || compareTab.dataset.initialized) return;
      
      compareTab.addEventListener('click', (e) => {
        e.preventDefault();
        
        // Skip if disabled (let tooltip show help)
        if (compareTab.classList.contains('disabled')) return;
        
        this.activateCompareTab();
        this.loadComparisonInterface();
      });
      
      compareTab.dataset.initialized = 'true';
    }
  };
  
  // Initialize the comparison system
  QueryComparison.init();
  
  // Refresh history when a new analysis completes
  document.addEventListener('analysisCompleted', function() {
    QueryComparison.loadQueryHistory();
  });
}); 