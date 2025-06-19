function initChartRendering() {
  const chartTypeSelect = document.getElementById('chartType');
  const chartDataElement = document.querySelector('[data-chart-data]');
  
  if (!chartTypeSelect || !chartDataElement) return;

  try {
    const chartData = JSON.parse(chartDataElement.dataset.chartData);
    
    chartTypeSelect.addEventListener('change', function() {
      renderChart(this.value, chartData);
    });

    // Initial render
    renderChart('bar', chartData);
  } catch (e) {
    console.error('Failed to parse chart data:', e);
  }
}

function renderChart(type, data) {
  const container = document.getElementById('dynamicChart');
  if (!container || !data || !data.chartData) return;

  const containerRect = container.getBoundingClientRect();
  const containerHeight = Math.max(250, containerRect.height - 20);
  const containerWidth = containerRect.width - 20;

  const options = {
    height: containerHeight + 'px',
    width: containerWidth + 'px',
    colors: ["#00979D", "#00838a", "#00767a", "#006064", "#004d4f"],
    responsive: true,
    maintainAspectRatio: false,
    library: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        intersect: false
      },
      plugins: {
        legend: {
          display: true,
          position: 'bottom',
          labels: {
            fontSize: 11,
            fontColor: '#6b7280',
            padding: 10
          }
        }
      },
      scales: {
        x: {
          ticks: {
            maxRotation: 45,
            minRotation: 0,
            font: {
              size: 10
            }
          }
        },
        y: {
          ticks: {
            font: {
              size: 10
            }
          }
        }
      }
    }
  };

  container.innerHTML = '';

  try {
    setTimeout(function() {
      var chartInstance;
      
      switch(type) {
        case 'line':
          chartInstance = new Chartkick.LineChart(container, data.chartData, options);
          break;
        case 'bar':
          chartInstance = new Chartkick.BarChart(container, data.chartData, options);
          break;
        case 'pie':
          chartInstance = new Chartkick.PieChart(container, data.chartData, {
            ...options,
            library: {
              ...options.library,
              plugins: {
                legend: {
                  display: true,
                  position: 'right',
                  labels: {
                    fontSize: 10,
                    fontColor: '#6b7280',
                    padding: 8
                  }
                }
              }
            }
          });
          break;
        case 'area':
          chartInstance = new Chartkick.AreaChart(container, data.chartData, options);
          break;
        default:
          chartInstance = new Chartkick.BarChart(container, data.chartData, options);
      }

      if (chartInstance && chartInstance.getChart) {
        setTimeout(function() {
          const chart = chartInstance.getChart();
          if (chart && chart.resize) {
            chart.resize();
          }
        }, 100);
      }
    }, 50);

  } catch (error) {
    console.error('Chart rendering error:', error);
    container.innerHTML = '<div style="display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100%; color: #64748b; text-align: center; padding: 20px;"><div style="font-size: 48px; margin-bottom: 16px; opacity: 0.5;">⚠️</div><h3 style="margin: 0 0 8px 0; color: #374151;">Chart Error</h3><p style="margin: 0 0 8px 0; font-size: 14px;">Unable to render chart</p><small style="opacity: 0.7;">' + error.message + '</small></div>';
  }
} 