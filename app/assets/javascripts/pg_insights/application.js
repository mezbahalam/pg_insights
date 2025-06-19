//= require chartkick
//= require Chart.bundle
//= require_tree .


// PG Insights JavaScript
document.addEventListener('DOMContentLoaded', function() {
  const InsightsApp = {
    // Configuration - will be set from data attribute
    config: {
      queries: [],
      savedQueries: []
    },

    // Initialize the application
    init() {
      this.loadQueriesFromDataAttribute();
      this.loadSavedQueries();
      this.bindEvents();
      this.validateInitialQuery();
      this.setupQueryExamples();
      this.loadTableNames();
    },

    // Load queries from data attribute
    loadQueriesFromDataAttribute() {
      const container = document.querySelector('.insights-container');
      if (container && container.dataset.queries) {
        try {
          this.config.queries = JSON.parse(container.dataset.queries);
        } catch (e) {
          console.error('Failed to parse queries data:', e);
          this.config.queries = [];
        }
      }
    },

    // Load saved queries from localStorage (keeping existing method)
    loadSavedQueries() {
      // Keep this for backward compatibility if needed elsewhere
    },

    // Copy current query functionality
    copyCurrentQuery() {
      const textarea = document.querySelector('.sql-editor');
      const btn = document.querySelector('.btn-icon.btn-copy');
      
      if (!textarea?.value.trim()) return;
      
      btn.disabled = true;
      btn.textContent = '✓';
      
      navigator.clipboard.writeText(textarea.value).then(() => {
        setTimeout(() => {
          btn.disabled = false;
          btn.textContent = '📋';
        }, 1000);
      });
    },

    // Save current query functionality
    saveCurrentQuery() {
      const textarea = document.querySelector('.sql-editor');
      const btn = document.querySelector('.btn-icon.btn-save');
      
      if (!textarea?.value.trim()) return;
      
      const name = prompt('Enter query name:');
      if (!name) return;
      
      btn.disabled = true;
      btn.textContent = '⏳';
      
      // Save to server
      fetch('/pg_insights/save_query', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({
          name: name.trim(),
          sql: textarea.value.trim()
        })
      })
      .then(response => response.json())
      .then(data => {
        btn.textContent = data.success ? '✓' : '✗';
        setTimeout(() => {
          btn.disabled = false;
          btn.textContent = '💾';
        }, 1000);
      })
      .catch(() => {
        btn.textContent = '✗';
        setTimeout(() => {
          btn.disabled = false;
          btn.textContent = '💾';
        }, 1000);
      });
    },

    // Query validation
    validateQuery(sql) {
      if (!sql || !sql.trim()) {
        return { valid: false, message: "Please enter a SQL query" };
      }

      const trimmedSql = sql.trim();

      // Check if it starts with SELECT (case insensitive)
      if (!trimmedSql.toLowerCase().startsWith('select')) {
        return { valid: false, message: "Only SELECT statements are allowed" };
      }

      // Check for semicolons
      if (trimmedSql.includes(';')) {
        return { valid: false, message: "Semicolons (;) are not allowed. Please use a single SELECT statement only." };
      }

      // Check for forbidden keywords
      const forbiddenWords = /\b(insert|update|delete|alter|drop|create|grant|revoke)\b/i;
      const match = trimmedSql.match(forbiddenWords);
      if (match) {
        return { valid: false, message: `${match[1].toUpperCase()} statements are not allowed. Only SELECT queries are permitted.` };
      }

      return { valid: true };
    },

    // UI Updates
    updateExecuteButton(isValid) {
      const executeBtn = document.getElementById('execute-btn');
      if (executeBtn) {
        executeBtn.disabled = !isValid;
        executeBtn.title = isValid ? 'Execute query' : 'Please fix query errors first';
      }
    },

    validateAndUpdateUI(sql) {
      const validation = this.validateQuery(sql);

      if (validation.valid) {
        this.hideValidationError();
        this.updateExecuteButton(true);
      } else {
        this.showValidationError(validation.message);
        this.updateExecuteButton(false);
      }

      return validation;
    },

    showValidationError(message) {
      // Remove existing error
      const existingError = document.querySelector('.validation-error');
      if (existingError) {
        existingError.remove();
      }

      // Create and show new error
      const errorDiv = document.createElement('div');
      errorDiv.className = 'validation-error';
      errorDiv.innerHTML = `<span>⚠️ ${message}</span>`;

      const textarea = document.querySelector('.sql-editor');
      if (textarea && textarea.parentNode) {
        textarea.parentNode.insertBefore(errorDiv, textarea.nextSibling);
      }
    },

    hideValidationError() {
      const existingError = document.querySelector('.validation-error');
      if (existingError) {
        existingError.remove();
      }
    },

    // Query management
    clearQuery() {
      const textarea = document.querySelector('.sql-editor');
      if (textarea) {
        textarea.value = '';
        textarea.focus();
        this.validateAndUpdateUI('');
      }
    },

    // Load table names for preview dropdown
    loadTableNames() {
      fetch('/pg_insights/table_names')
        .then(res => res.json())
        .then(data => {
          const select = document.getElementById('table-preview-select');
          if (select && data.tables) {
            // Clear existing options except the first one
            while (select.children.length > 1) {
              select.removeChild(select.lastChild);
            }
            
            // Add table options
            data.tables.forEach(table => {
              const option = document.createElement('option');
              option.value = table;
              option.textContent = table;
              select.appendChild(option);
            });
          }
        })
        .catch(error => {
          console.error('Failed to load table names:', error);
        });
    },

    // Preview selected table
    previewTable(tableName) {
      if (!tableName) return;
      
      const sql = `SELECT * FROM ${tableName} LIMIT 10`;
      const textarea = document.querySelector('.sql-editor');
      
      if (textarea) {
        textarea.value = sql;
        
        // Validate the query
        this.validateAndUpdateUI(sql);
        
        // Auto-resize textarea
        textarea.style.height = 'auto';
        textarea.style.height = Math.max(160, textarea.scrollHeight) + 'px';
        
        // Auto-execute the query
        const executeBtn = document.getElementById('execute-btn');
        if (executeBtn && !executeBtn.disabled) {
          executeBtn.click();
        }
      }
      
      // Reset the dropdown to the default option
      const select = document.getElementById('table-preview-select');
      if (select) {
        select.value = '';
      }
    },

    loadQueryById(queryId) {
      
      // Check saved queries and default queries
      let query = this.config.savedQueries.find(q => q.id === queryId);
      if (!query) {
        query = this.config.queries.find(q => q.id === queryId);
      }
      
      if (!query) {
        console.error('Query not found:', queryId);
        return;
      }

      const textarea = document.querySelector('.sql-editor');
      if (textarea) {
        textarea.value = query.sql;
        textarea.focus();

        // Validate the loaded query
        this.validateAndUpdateUI(query.sql);

        // Trigger auto-resize if available
        const event = new Event('input', { bubbles: true });
        textarea.dispatchEvent(event);
      }
    },

    // Query examples setup
    setupQueryExamples() {
      // Setup category filtering
      document.querySelectorAll('.filter-btn').forEach(button => {
        button.addEventListener('click', () => {
          const category = button.getAttribute('data-category');

          // Update active state
          document.querySelectorAll('.filter-btn').forEach(btn => btn.classList.remove('active'));
          button.classList.add('active');

          // Filter query buttons
          document.querySelectorAll('.query-example-btn').forEach(queryBtn => {
            const queryCategory = queryBtn.getAttribute('data-category');
            if (category === 'all' || queryCategory === category) {
              queryBtn.classList.remove('hidden');
            } else {
              queryBtn.classList.add('hidden');
            }
          });
        });
      });

      // Setup query example button clicks
      document.querySelectorAll('.query-example-btn').forEach(button => {
        button.addEventListener('click', () => {
          const queryId = button.getAttribute('data-query-id');
          console.log('Query button clicked, ID:', queryId);
          if (queryId) {
            this.loadQueryById(queryId);
          }
        });
      });
    },

    // Event binding
    bindEvents() {
      const textarea = document.querySelector('.sql-editor');
      const executeBtn = document.getElementById('execute-btn');

      // Real-time validation on input
      if (textarea) {
        textarea.addEventListener('input', () => {
          // Auto-resize
          textarea.style.height = 'auto';
          textarea.style.height = Math.max(160, textarea.scrollHeight) + 'px';

          // Instant validation
          this.validateAndUpdateUI(textarea.value);
        });

        // Validation on paste
        textarea.addEventListener('paste', () => {
          // Small delay to let paste complete
          setTimeout(() => {
            this.validateAndUpdateUI(textarea.value);
          }, 10);
        });
      }

      // Prevent form submission if button is disabled
      if (executeBtn) {
        executeBtn.addEventListener('click', (event) => {
          if (executeBtn.disabled) {
            event.preventDefault();
            if (textarea) {
              textarea.focus();
            }
            return false;
          }
        });
      }

      // Global functions - expose methods to global scope for onclick handlers
      window.clearQuery = () => this.clearQuery();
      window.copyCurrentQuery = () => this.copyCurrentQuery();
      window.saveCurrentQuery = () => this.saveCurrentQuery();

      // Table preview dropdown
      const tableSelect = document.getElementById('table-preview-select');
      if (tableSelect) {
        tableSelect.addEventListener('change', (event) => {
          const tableName = event.target.value;
          if (tableName) {
            this.previewTable(tableName);
          }
        });
      }
    },

    // Initial validation
    validateInitialQuery() {
      const textarea = document.querySelector('.sql-editor');
      if (textarea) {
        const initialValue = textarea.value.trim();
        if (initialValue) {
          this.validateAndUpdateUI(initialValue);
        } else {
          this.updateExecuteButton(false);
          textarea.focus();
        }
      }
    },

    saveQuery(name, sql) {
      // Basic validation
      if (!name || !sql) return;

      fetch('/pg_insights/insights/save_query', {
        method: 'POST',
        headers: this.headers,
        body: JSON.stringify({ name, sql })
      })
      .then(response => response.json())
      .then(data => {
        // Handle the response from the server
        console.log(data);
      })
      .catch(error => {
        console.error('Failed to save query:', error);
      });
    }
  };

  // Initialize the application
  InsightsApp.init();
});
