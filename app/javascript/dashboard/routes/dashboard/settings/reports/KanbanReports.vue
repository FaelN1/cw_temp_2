<script>
import { useAlert, useTrack } from 'dashboard/composables';
import ReportFilterSelector from './components/FilterSelector.vue';
import V4Button from 'dashboard/components-next/button/Button.vue';
import ReportHeader from './components/ReportHeader.vue';
import kanbanAPI from '../../../../api/kanban';
import funnelAPI from '../../../../api/funnel';
import { REPORTS_EVENTS } from '../../../../helper/AnalyticsHelper/events';
import { generateFileName } from '../../../../helper/downloadHelper';

export default {
  name: 'KanbanReports',
  components: {
    ReportFilterSelector,
    V4Button,
    ReportHeader,
  },
  data() {
    const today = new Date();
    const thirtyDaysAgo = new Date(today);
    thirtyDaysAgo.setDate(today.getDate() - 30);

    return {
      from: thirtyDaysAgo.getTime(),
      to: today.getTime(),
      userIds: [],
      inbox: null,
      metrics: {
        totalItems: 0,
        itemsByStage: {},
        averageValue: 0,
        totalValue: 0,
        avgTimeInStage: {},
        conversionRates: {},
        stageMetrics: {
          valueByStage: {},
          itemsCreatedToday: 0,
          itemsCreatedThisWeek: 0,
          itemsCreatedThisMonth: 0,
          stageVelocity: {},
          avgTimeToConversion: {},
          stageEfficiency: {},
          itemsWithDeadline: 0,
          itemsWithRescheduling: 0,
          itemsWithOffers: 0,
          avgOffersValue: 0,
          totalOffers: 0,
          offerRanges: {
            low: 0, // Até R$ 1.000
            medium: 0, // R$ 1.001 a R$ 5.000
            high: 0, // Acima de R$ 5.000
          },
          priorityDistribution: {
            low: 0,
            medium: 0,
            high: 0,
          },
          channelDistribution: {},
        },
        funnelMetrics: {
          totalFunnels: 0,
          activeStages: 0,
          stageDistribution: {},
          averageStagesPerFunnel: 0,
          conversionByStage: {},
          timeInStageByFunnel: {},
          valueByStage: {},
          stageColors: {},
          messageTemplates: {},
          stagePositions: {},
        },
        checklistMetrics: {
          totalTasks: 0,
          completedTasks: 0,
          completionRate: 0,
          itemsWithChecklists: 0,
          averageTasksPerItem: 0,
        },
        activityMetrics: {
          totalActivities: 0,
          activitiesByType: {},
          averageActivitiesPerItem: 0,
          itemsWithNotes: 0,
          itemsWithAttachments: 0,
          stageChanges: 0,
          valueChanges: 0,
          agentChanges: 0,
          itemsWithConversations: 0,
        },
        contactMetrics: {
          totalContacts: new Set(),
          contactsWithEmail: 0,
          contactsWithPhone: 0,
          contactsWithBoth: 0,
        },
      },
      isLoading: false,
      funnels: [],
      maxHourlyChanges: 0,
    };
  },
  computed: {
    requestPayload() {
      return {
        from: this.from,
        to: this.to,
        user_ids: this.userIds,
        inbox_id: this.inbox,
      };
    },
    defaultChartOptions() {
      return {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false,
        },
        animation: {
          duration: 750,
          easing: 'easeInOutQuart',
        },
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              usePointStyle: true,
              padding: 20,
              font: {
                family: "'Inter', sans-serif",
                size: 12,
              },
              color: '#94a3b8',
            },
          },
          tooltip: {
            backgroundColor: 'rgba(30, 41, 59, 0.95)',
            titleColor: '#e2e8f0',
            bodyColor: '#e2e8f0',
            borderColor: '#334155',
            borderWidth: 1,
            padding: 12,
            cornerRadius: 8,
            displayColors: true,
            usePointStyle: true,
            callbacks: {
              label: function (context) {
                let label = context.dataset.label || '';
                if (label) {
                  label += ': ';
                }
                if (context.parsed.y !== null) {
                  label += context.parsed.y.toLocaleString();
                }
                return label;
              },
            },
          },
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: 'rgba(51, 65, 85, 0.1)',
              drawBorder: false,
            },
            ticks: {
              color: '#94a3b8',
              padding: 10,
              font: {
                family: "'Inter', sans-serif",
                size: 11,
              },
            },
          },
          x: {
            grid: {
              display: false,
            },
            ticks: {
              color: '#94a3b8',
              padding: 10,
              font: {
                family: "'Inter', sans-serif",
                size: 11,
              },
            },
          },
        },
      };
    },
    lineChartOptions() {
      return {
        ...this.defaultChartOptions,
        plugins: {
          ...this.defaultChartOptions.plugins,
          tooltip: {
            ...this.defaultChartOptions.plugins.tooltip,
            intersect: false,
            mode: 'nearest',
          },
        },
        elements: {
          line: {
            tension: 0.4,
          },
          point: {
            radius: 4,
            hoverRadius: 6,
            backgroundColor: '#fff',
            borderWidth: 3,
          },
        },
      };
    },
    pieChartOptions() {
      return {
        ...this.defaultChartOptions,
        cutout: '60%',
        plugins: {
          ...this.defaultChartOptions.plugins,
          tooltip: {
            ...this.defaultChartOptions.plugins.tooltip,
            callbacks: {
              label: context => {
                const value = context.parsed;
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = ((value * 100) / total).toFixed(1);
                return `${context.label}: ${value.toLocaleString()} (${percentage}%)`;
              },
            },
          },
        },
      };
    },
    barChartOptions() {
      return {
        ...this.defaultChartOptions,
        plugins: {
          ...this.defaultChartOptions.plugins,
          tooltip: {
            ...this.defaultChartOptions.plugins.tooltip,
            callbacks: {
              label: context => {
                return `${context.dataset.label}: ${this.formatCurrency(context.parsed.y)}`;
              },
            },
          },
        },
        scales: {
          ...this.defaultChartOptions.scales,
          y: {
            ...this.defaultChartOptions.scales.y,
            ticks: {
              ...this.defaultChartOptions.scales.y.ticks,
              callback: value => this.formatCurrency(value),
            },
          },
        },
      };
    },
    radarChartOptions() {
      return {
        ...this.defaultChartOptions,
        scales: {
          r: {
            beginAtZero: true,
            max: 100,
            ticks: {
              stepSize: 20,
              color: '#94a3b8',
              backdropColor: 'transparent',
            },
            grid: {
              color: 'rgba(51, 65, 85, 0.1)',
            },
            angleLines: {
              color: 'rgba(51, 65, 85, 0.1)',
            },
            pointLabels: {
              color: '#94a3b8',
              font: {
                family: "'Inter', sans-serif",
                size: 11,
              },
            },
          },
        },
        plugins: {
          ...this.defaultChartOptions.plugins,
          tooltip: {
            ...this.defaultChartOptions.plugins.tooltip,
            callbacks: {
              label: context => {
                return `${context.dataset.label}: ${context.parsed}%`;
              },
            },
          },
        },
      };
    },
    lineChartData() {
      const stages = Object.keys(this.metrics.itemsByStage);
      const sortedStages = stages.sort((a, b) => {
        return (
          this.metrics.funnelMetrics.stagePositions[a] -
          this.metrics.funnelMetrics.stagePositions[b]
        );
      });

      return {
        labels: sortedStages,
        datasets: [
          {
            label: this.$t('KANBAN_REPORTS.METRICS.ITEMS_BY_STAGE'),
            data: sortedStages.map(stage =>
              Number(this.metrics.itemsByStage[stage] || 0)
            ),
            fill: true,
            borderColor: '#3b82f6',
            backgroundColor: 'rgba(59, 130, 246, 0.1)',
            borderWidth: 2,
            pointBackgroundColor: '#fff',
            pointBorderColor: '#3b82f6',
            pointHoverBackgroundColor: '#3b82f6',
            pointHoverBorderColor: '#fff',
          },
        ],
      };
    },
    pieChartData() {
      const stages = Object.keys(this.metrics.itemsByStage);
      return {
        labels: stages,
        datasets: [
          {
            data: stages.map(stage =>
              Number(this.metrics.itemsByStage[stage] || 0)
            ),
            backgroundColor: stages.map(
              stage =>
                this.metrics.funnelMetrics.stageColors[stage] || '#94a3b8'
            ),
            borderWidth: 2,
            borderColor: '#1e293b',
            hoverOffset: 15,
          },
        ],
      };
    },
    barChartData() {
      const stages = Object.keys(this.metrics.stageMetrics.valueByStage);
      const sortedStages = stages.sort((a, b) => {
        return (
          this.metrics.funnelMetrics.stagePositions[a] -
          this.metrics.funnelMetrics.stagePositions[b]
        );
      });

      return {
        labels: sortedStages,
        datasets: [
          {
            label: this.$t('KANBAN_REPORTS.METRICS.VALUE_BY_STAGE'),
            data: sortedStages.map(stage =>
              Number(this.metrics.stageMetrics.valueByStage[stage] || 0)
            ),
            backgroundColor: 'rgba(16, 185, 129, 0.2)',
            borderColor: '#10b981',
            borderWidth: 2,
            borderRadius: 6,
            hoverBackgroundColor: 'rgba(16, 185, 129, 0.4)',
          },
        ],
      };
    },
    radarChartData() {
      const stages = Object.keys(this.metrics.stageMetrics.stageEfficiency);
      return {
        labels: stages,
        datasets: [
          {
            label: this.$t('KANBAN_REPORTS.METRICS.STAGE_EFFICIENCY'),
            data: stages.map(stage =>
              Math.round(
                (this.metrics.stageMetrics.stageEfficiency[stage] || 0) * 100
              )
            ),
            backgroundColor: 'rgba(139, 92, 246, 0.2)',
            borderColor: '#8b5cf6',
            borderWidth: 2,
            pointBackgroundColor: '#fff',
            pointBorderColor: '#8b5cf6',
            pointHoverBackgroundColor: '#8b5cf6',
            pointHoverBorderColor: '#fff',
            pointRadius: 4,
            pointHoverRadius: 6,
          },
        ],
      };
    },
    calendarData() {
      const today = new Date();
      const data = [];
      let maxValue = 0;

      // Gerar dados dos últimos 365 dias
      for (let i = 0; i < 365; i += 1) {
        const date = new Date(today);
        date.setDate(date.getDate() - i);
        const value = Math.floor(Math.random() * 5); // Valor entre 0 e 5 para simular atividades
        maxValue = Math.max(maxValue, value);
        data.push({
          day: date.toISOString().split('T')[0],
          value: Number(value),
        });
      }

      return data;
    },
  },
  mounted() {
    this.fetchAllData();
  },
  methods: {
    async fetchAllData() {
      try {
        this.isLoading = true;
        await Promise.all([this.fetchMetrics(), this.fetchFunnels()]);
      } catch (error) {
        const { showAlert } = useAlert();
        showAlert('Erro ao carregar métricas do Kanban');
      } finally {
        this.isLoading = false;
      }
    },
    async fetchFunnels() {
      try {
        const response = await funnelAPI.get();
        this.funnels = response.data;
        this.calculateFunnelMetrics();
      } catch (error) {
        const { showAlert } = useAlert();
        showAlert('Erro ao carregar dados dos funis');
      }
    },
    calculateFunnelMetrics() {
      const funnelMetrics = {
        totalFunnels: this.funnels.length,
        activeStages: 0,
        stageDistribution: {},
        averageStagesPerFunnel: 0,
        conversionByStage: {},
        timeInStageByFunnel: {},
        valueByStage: {},
        stageColors: {},
        messageTemplates: {},
        stagePositions: {},
      };

      this.funnels.forEach(funnel => {
        const stages = Object.values(funnel.stages);
        funnelMetrics.activeStages += stages.length;

        // Distribuição de estágios e cores
        stages.forEach(stage => {
          funnelMetrics.stageDistribution[stage.name] =
            (funnelMetrics.stageDistribution[stage.name] || 0) + 1;
          funnelMetrics.stageColors[stage.name] = stage.color;
          funnelMetrics.stagePositions[stage.name] = stage.position;

          // Contagem de templates de mensagem por estágio
          if (stage.message_templates) {
            funnelMetrics.messageTemplates[stage.name] =
              (funnelMetrics.messageTemplates[stage.name] || 0) +
              stage.message_templates.length;
          }
        });
      });

      // Média de estágios por funil
      funnelMetrics.averageStagesPerFunnel =
        funnelMetrics.activeStages / funnelMetrics.totalFunnels;

      this.metrics.funnelMetrics = funnelMetrics;
    },
    async fetchMetrics() {
      try {
        const response = await kanbanAPI.getItems();
        const items = response.data;
        this.metrics = {
          ...this.metrics,
          ...this.calculateMetrics(items),
        };
      } catch (error) {
        const { showAlert } = useAlert();
        showAlert('Erro ao carregar métricas do Kanban');
      }
    },
    calculateMetrics(items) {
      const metrics = {
        totalItems: items.length,
        itemsByStage: {},
        totalValue: 0,
        averageValue: 0,
        avgTimeInStage: {},
        conversionRates: {},
        stageMetrics: {
          valueByStage: {},
          itemsCreatedToday: 0,
          itemsCreatedThisWeek: 0,
          itemsCreatedThisMonth: 0,
          stageVelocity: {},
          avgTimeToConversion: {},
          stageEfficiency: {},
          itemsWithDeadline: 0,
          itemsWithRescheduling: 0,
          itemsWithOffers: 0,
          avgOffersValue: 0,
          totalOffers: 0,
          offerRanges: {
            low: 0, // Até R$ 1.000
            medium: 0, // R$ 1.001 a R$ 5.000
            high: 0, // Acima de R$ 5.000
          },
          priorityDistribution: {
            low: 0,
            medium: 0,
            high: 0,
          },
          channelDistribution: {},
        },
        checklistMetrics: {
          totalTasks: 0,
          completedTasks: 0,
          completionRate: 0,
          itemsWithChecklists: 0,
          averageTasksPerItem: 0,
        },
        activityMetrics: {
          totalActivities: 0,
          activitiesByType: {},
          averageActivitiesPerItem: 0,
          itemsWithNotes: 0,
          itemsWithAttachments: 0,
          stageChanges: 0,
          valueChanges: 0,
          agentChanges: 0,
          itemsWithConversations: 0,
        },
        contactMetrics: {
          totalContacts: new Set(),
          contactsWithEmail: 0,
          contactsWithPhone: 0,
          contactsWithBoth: 0,
        },
      };

      const today = new Date();
      const thisWeek = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);
      const thisMonth = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);

      // Calcular métricas básicas e avançadas
      items.forEach(item => {
        const stage = item.funnel_stage;
        const details = item.item_details;
        const value = details?.value || 0;
        const createdAt = new Date(item.created_at);
        const checklist = details?.checklist || [];
        const activities = details?.activities || [];

        // Contagem por estágio
        metrics.itemsByStage[stage] = (metrics.itemsByStage[stage] || 0) + 1;

        // Valor total e por estágio
        metrics.totalValue += value;
        metrics.stageMetrics.valueByStage[stage] =
          (metrics.stageMetrics.valueByStage[stage] || 0) + value;

        // Contagem de itens recentes
        if (createdAt >= today.setHours(0, 0, 0, 0)) {
          metrics.stageMetrics.itemsCreatedToday += 1;
        }
        if (createdAt >= thisWeek) {
          metrics.stageMetrics.itemsCreatedThisWeek += 1;
        }
        if (createdAt >= thisMonth) {
          metrics.stageMetrics.itemsCreatedThisMonth += 1;
        }

        // Métricas de checklist
        if (checklist.length > 0) {
          metrics.checklistMetrics.itemsWithChecklists += 1;
          metrics.checklistMetrics.totalTasks += checklist.length;
          metrics.checklistMetrics.completedTasks += checklist.filter(
            task => task.completed
          ).length;
        }

        // Métricas de atividades
        if (activities.length > 0) {
          metrics.activityMetrics.totalActivities += activities.length;

          activities.forEach(activity => {
            metrics.activityMetrics.activitiesByType[activity.type] =
              (metrics.activityMetrics.activitiesByType[activity.type] || 0) +
              1;

            if (activity.type === 'stage_changed') {
              metrics.activityMetrics.stageChanges += 1;
            } else if (activity.type === 'value_changed') {
              metrics.activityMetrics.valueChanges += 1;
            } else if (activity.type === 'note_added') {
              metrics.activityMetrics.itemsWithNotes += 1;
            } else if (activity.type === 'attachment_added') {
              metrics.activityMetrics.itemsWithAttachments += 1;
            } else if (activity.type === 'agent_changed') {
              metrics.activityMetrics.agentChanges += 1;
            }
          });
        }

        // Métricas de prioridade
        if (details.priority) {
          metrics.stageMetrics.priorityDistribution[details.priority] += 1;
        }

        // Métricas de canal
        if (details.channel) {
          metrics.stageMetrics.channelDistribution[details.channel] =
            (metrics.stageMetrics.channelDistribution[details.channel] || 0) +
            1;
        }

        // Métricas de deadline e agendamento
        if (details.deadline_at) metrics.stageMetrics.itemsWithDeadline += 1;
        if (details.rescheduled)
          metrics.stageMetrics.itemsWithRescheduling += 1;

        // Métricas de ofertas
        if (details.offers && details.offers.length > 0) {
          metrics.stageMetrics.itemsWithOffers += 1;
          metrics.stageMetrics.totalOffers += details.offers.length;

          // Calcular valor total e médio das ofertas
          const offersTotal = details.offers.reduce(
            (sum, offer) => sum + (offer.value || 0),
            0
          );
          metrics.stageMetrics.avgOffersValue =
            offersTotal / details.offers.length;

          // Agrupar ofertas por faixa de valor
          details.offers.forEach(offer => {
            if (offer.value) {
              if (offer.value <= 1000) {
                metrics.stageMetrics.offerRanges.low += 1;
              } else if (offer.value <= 5000) {
                metrics.stageMetrics.offerRanges.medium += 1;
              } else {
                metrics.stageMetrics.offerRanges.high += 1;
              }
            }
          });
        }

        // Métricas de conversas
        if (item.conversation_display_id) {
          metrics.activityMetrics.itemsWithConversations += 1;
        }
      });

      // Calcular médias e taxas
      metrics.averageValue =
        items.length > 0 ? metrics.totalValue / items.length : 0;
      metrics.checklistMetrics.completionRate =
        metrics.checklistMetrics.totalTasks > 0
          ? metrics.checklistMetrics.completedTasks /
            metrics.checklistMetrics.totalTasks
          : 0;
      metrics.checklistMetrics.averageTasksPerItem =
        items.length > 0
          ? metrics.checklistMetrics.totalTasks / items.length
          : 0;
      metrics.activityMetrics.averageActivitiesPerItem =
        items.length > 0
          ? metrics.activityMetrics.totalActivities / items.length
          : 0;

      // Converter Set para número
      metrics.contactMetrics.totalContacts =
        metrics.contactMetrics.totalContacts.size;

      return metrics;
    },
    onFilterChange({ dateRange = {}, userIds = [], inboxId = null } = {}) {
      if (dateRange.from && dateRange.to) {
        this.from = dateRange.from;
        this.to = dateRange.to;
      }

      this.userIds = userIds;
      this.inbox = inboxId;

      useTrack(REPORTS_EVENTS.FILTER_REPORT, {
        filterType: 'kanban',
        filterValue: JSON.stringify(this.requestPayload),
      });

      this.fetchAllData();
    },
    async downloadReports() {
      try {
        const response = await kanbanAPI.getItems();
        const items = response.data;
        const csvContent = this.convertToCSV(items);
        const blob = new Blob([csvContent], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = generateFileName('kanban_report');
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
      } catch (error) {
        const { showAlert } = useAlert();
        showAlert('Erro ao baixar relatório do Kanban');
      }
    },
    convertToCSV(items) {
      const headers = [
        'ID',
        'Estágio',
        'Título',
        'Valor',
        'Data de Criação',
        'Data de Entrada no Estágio',
        'Descrição',
        'Prioridade',
        'Canal',
        'ID do Contato',
        'Email',
        'Telefone',
        'Data Limite',
        'Total de Atividades',
        'Total de Notas',
        'Total de Anexos',
      ].join(',');

      const rows = items.map(item => {
        const details = item.item_details || {};
        const activities = details.activities || [];
        const notes = activities.filter(a => a.type === 'note_added').length;
        const attachments = activities.filter(
          a => a.type === 'attachment_added'
        ).length;

        return [
          item.id,
          item.funnel_stage,
          details.title || '',
          details.value || '',
          item.created_at,
          item.stage_entered_at,
          (details.description || '').replace(/,/g, ';'),
          details.priority || '',
          details.channel || '',
          details.contact_id || '',
          details.email || '',
          details.phone || '',
          details.deadline_at || '',
          activities.length,
          notes,
          attachments,
        ].join(',');
      });

      return [headers, ...rows].join('\n');
    },
    formatCurrency(value) {
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL',
      }).format(value);
    },
    formatDuration(ms) {
      const days = Math.floor(ms / (1000 * 60 * 60 * 24));
      return `${days} ${days === 1 ? 'dia' : 'dias'}`;
    },
    formatPercentage(value) {
      return `${(value * 100).toFixed(1)}%`;
    },
    getHourlyChanges() {
      const hourlyChanges = Array(24).fill(0);
      const activities = Object.values(
        this.metrics.activityMetrics.activitiesByType
      ).reduce((acc, val) => acc + val, 0);

      // Distribuir as atividades ao longo do dia com uma curva natural
      for (let i = 0; i < activities; i += 1) {
        // Simular uma distribuição mais realista com pico durante horário comercial
        const hour = Math.floor((Math.sin(Math.random() * Math.PI) + 1) * 12);
        hourlyChanges[hour] = (hourlyChanges[hour] || 0) + 1;
      }

      this.maxHourlyChanges = Math.max(...hourlyChanges);
      return hourlyChanges;
    },
    getCompletionTrendClass(type = 'text') {
      const progress = this.getCompletionProgress();
      const baseClass = type === 'bg' ? 'bg-' : 'text-';

      if (progress >= 80)
        return `${baseClass}emerald-500 dark:${baseClass}emerald-400`;
      if (progress >= 50)
        return `${baseClass}yellow-500 dark:${baseClass}yellow-400`;
      return `${baseClass}red-500 dark:${baseClass}red-400`;
    },
    getCompletionProgress() {
      const totalItems = this.metrics.totalItems;
      const completedItems = Object.values(this.metrics.itemsByStage).reduce(
        (acc, val) => acc + val,
        0
      );
      return totalItems > 0 ? (completedItems / totalItems) * 100 : 0;
    },
    getCompletionForecast() {
      const velocity = this.getWeeklyThroughput();
      const remainingItems =
        this.metrics.totalItems -
        Object.values(this.metrics.itemsByStage).reduce(
          (acc, val) => acc + val,
          0
        );
      const weeksToComplete = remainingItems / velocity;

      const date = new Date();
      date.setDate(date.getDate() + weeksToComplete * 7);

      return date.toLocaleDateString('pt-BR', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
      });
    },
    identifyBottlenecks() {
      const bottlenecks = [];
      const stages = Object.keys(this.metrics.itemsByStage);

      stages.forEach(stage => {
        const itemCount = this.metrics.itemsByStage[stage];
        const avgTime = this.metrics.avgTimeInStage[stage];
        const efficiency = this.metrics.stageMetrics.stageEfficiency[stage];

        if (efficiency < 0.5 && itemCount > 0) {
          bottlenecks.push({
            stage,
            severity: 'high',
            reason: 'Baixa eficiência no processamento',
          });
        } else if (avgTime > 7 * 24 * 60 * 60 * 1000 && itemCount > 0) {
          bottlenecks.push({
            stage,
            severity: 'medium',
            reason: 'Tempo de permanência elevado',
          });
        }
      });

      return bottlenecks;
    },
    getBottleneckSeverityClass(severity) {
      const classes = {
        high: 'bg-red-500',
        medium: 'bg-yellow-500',
        low: 'bg-orange-500',
      };
      return classes[severity] || classes.medium;
    },
    getOptimizationSuggestions() {
      const suggestions = [];
      const stages = Object.keys(this.metrics.itemsByStage);

      // Análise de distribuição de trabalho
      const avgItemsPerStage = this.metrics.totalItems / stages.length;
      stages.forEach(stage => {
        const items = this.metrics.itemsByStage[stage];
        if (items > avgItemsPerStage * 1.5) {
          suggestions.push({
            icon: 'i-ph-warning-circle',
            title: `Distribuição desbalanceada em ${stage}`,
            description:
              'Considere redistribuir o trabalho ou aumentar a capacidade neste estágio',
          });
        }
      });

      // Análise de eficiência
      const lowEfficiencyStages = stages.filter(
        stage => this.metrics.stageMetrics.stageEfficiency[stage] < 0.6
      );
      if (lowEfficiencyStages.length > 0) {
        suggestions.push({
          icon: 'i-ph-trend-up',
          title: 'Oportunidade de melhoria na eficiência',
          description:
            'Alguns estágios apresentam baixa eficiência. Analise os processos e recursos',
        });
      }

      // Análise de valor
      const avgValue = this.metrics.averageValue;
      const lowValueStages = stages.filter(
        stage => this.metrics.stageMetrics.valueByStage[stage] < avgValue * 0.5
      );
      if (lowValueStages.length > 0) {
        suggestions.push({
          icon: 'i-ph-currency-circle-dollar',
          title: 'Otimização de valor por estágio',
          description:
            'Existem estágios com valor abaixo da média. Considere priorizar itens de maior valor',
        });
      }

      return suggestions;
    },
    getAverageCycleTime() {
      const times = Object.values(this.metrics.avgTimeInStage);
      return times.length > 0
        ? times.reduce((a, b) => a + b, 0) / times.length
        : 0;
    },
    getWeeklyThroughput() {
      return this.metrics.stageMetrics.itemsCreatedThisWeek;
    },
    getPriorityColor(priority) {
      const colors = {
        low: '#94a3b8',
        medium: '#f59e0b',
        high: '#ef4444',
      };
      return colors[priority] || '#94a3b8';
    },
    formatActivityType(type) {
      const typeMap = {
        stage_changed: 'Mudança de Estágio',
        value_changed: 'Alteração de Valor',
        agent_changed: 'Mudança de Agente',
        note_added: 'Nota Adicionada',
        attachment_added: 'Anexo Adicionado',
        checklist_item_added: 'Item de Checklist Adicionado',
        checklist_item_toggled: 'Item de Checklist Alterado',
        conversation_linked: 'Conversa Vinculada',
      };
      return typeMap[type] || type;
    },
  },
};
</script>

<template>
  <div class="flex flex-col">
    <ReportHeader header-title="Relatórios Kanban">
      <V4Button
        label="Baixar Relatório"
        icon="i-ph-download-simple"
        size="sm"
        @click="downloadReports"
      />
    </ReportHeader>

    <!-- Conteúdo principal -->
    <div class="flex flex-col gap-6 p-4">
      <!-- Filtros -->
      <ReportFilterSelector
        show-date-range
        show-agents-filter
        show-inbox-filter
        :show-business-hours-switch="false"
        class="bg-white dark:bg-slate-800 rounded-lg p-4 shadow-sm"
        @filter-change="onFilterChange"
      />

      <!-- Loading State -->
      <div v-if="isLoading" class="flex items-center justify-center p-8">
        <div class="loading-spinner">
          <i class="i-ph-circle-notch text-2xl animate-spin text-blue-500" />
          <span class="ml-3 text-slate-600">Carregando métricas...</span>
        </div>
      </div>

      <!-- Content Grid -->
      <div v-else class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
        <!-- Cards de Resumo -->
        <div class="col-span-full">
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <!-- Itens Totais -->
            <div class="stats-card">
              <div class="stats-icon bg-woot-50 text-woot-500">
                <i class="i-ph-list-numbers text-xl" />
              </div>
              <div class="stats-info">
                <h4>{{ metrics.totalItems }}</h4>
                <p>Total de Itens</p>
              </div>
            </div>

            <!-- Valor Total -->
            <div class="stats-card">
              <div class="stats-icon bg-emerald-50 text-emerald-500">
                <i class="i-ph-currency-circle-dollar text-xl" />
              </div>
              <div class="stats-info">
                <h4>{{ formatCurrency(metrics.totalValue) }}</h4>
                <p>Valor Total</p>
              </div>
            </div>

            <!-- Contatos -->
            <div class="stats-card">
              <div class="stats-icon bg-violet-50 text-violet-500">
                <i class="i-ph-users text-xl" />
              </div>
              <div class="stats-info">
                <h4>{{ metrics.contactMetrics.totalContacts }}</h4>
                <p>Total de Contatos</p>
              </div>
            </div>

            <!-- Conversas -->
            <div class="stats-card">
              <div class="stats-icon bg-amber-50 text-amber-500">
                <i class="i-ph-chats text-xl" />
              </div>
              <div class="stats-info">
                <h4>{{ metrics.activityMetrics.itemsWithConversations }}</h4>
                <p>Conversas</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Distribuição por Estágio -->
        <div class="report-card md:col-span-2">
          <div class="card-header">
            <h3 class="flex items-center gap-2">
              <i class="i-ph-funnel text-blue-500" />
              Distribuição por Estágio
            </h3>
          </div>
          <div class="card-body">
            <div class="space-y-4 p-4">
              <div
                v-for="(value, stage) in metrics.itemsByStage"
                :key="stage"
                class="stage-bar"
              >
                <div class="flex justify-between mb-1">
                  <span class="text-sm text-slate-600">{{ stage }}</span>
                  <span class="text-sm font-medium">{{ value }}</span>
                </div>
                <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
                  <div
                    class="h-full rounded-full transition-all duration-500"
                    :style="{
                      width: `${(value / Math.max(...Object.values(metrics.itemsByStage))) * 100}%`,
                      backgroundColor:
                        metrics.funnelMetrics.stageColors[stage] || '#94a3b8',
                    }"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Métricas de Checklist -->
        <div class="report-card">
          <div class="card-header">
            <h3 class="flex items-center gap-2">
              <i class="i-ph-check-square text-indigo-500" />
              Métricas de Checklist
            </h3>
          </div>
          <div class="card-body">
            <div class="space-y-4 p-4">
              <div class="grid grid-cols-2 gap-4">
                <div class="metric-summary-card">
                  <span class="metric-label">Total de Tarefas</span>
                  <span class="metric-value">{{
                    metrics.checklistMetrics.totalTasks
                  }}</span>
                </div>
                <div class="metric-summary-card">
                  <span class="metric-label">Tarefas Concluídas</span>
                  <span class="metric-value">{{
                    metrics.checklistMetrics.completedTasks
                  }}</span>
                </div>
              </div>
              <div class="metric-summary-card">
                <span class="metric-label">Taxa de Conclusão</span>
                <span class="metric-value">{{
                  formatPercentage(metrics.checklistMetrics.completionRate)
                }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Métricas de Prioridade -->
        <div class="report-card">
          <div class="card-header">
            <h3 class="flex items-center gap-2">
              <i class="i-ph-flag text-rose-500" />
              Distribuição por Prioridade
            </h3>
          </div>
          <div class="card-body">
            <div class="space-y-4 p-4">
              <div
                v-for="(count, priority) in metrics.stageMetrics
                  .priorityDistribution"
                :key="priority"
                class="priority-bar"
              >
                <div class="flex justify-between mb-1">
                  <span class="text-sm capitalize text-slate-600">{{
                    priority === 'low'
                      ? 'Baixa'
                      : priority === 'medium'
                        ? 'Média'
                        : 'Alta'
                  }}</span>
                  <span class="text-sm font-medium">{{ count }}</span>
                </div>
                <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
                  <div
                    class="h-full rounded-full transition-all duration-500"
                    :style="{
                      width: `${(count / metrics.totalItems) * 100}%`,
                      backgroundColor: getPriorityColor(priority),
                    }"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Métricas de Ofertas -->
        <div class="report-card md:col-span-2">
          <div class="card-header">
            <h3 class="flex items-center gap-2">
              <i class="i-ph-handshake text-emerald-500" />
              Métricas de Ofertas
            </h3>
          </div>
          <div class="card-body">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 p-4">
              <div class="space-y-4">
                <div class="metric-summary-card">
                  <span class="metric-label">Itens com Ofertas</span>
                  <span class="metric-value">{{
                    metrics.stageMetrics.itemsWithOffers
                  }}</span>
                </div>
                <div class="metric-summary-card">
                  <span class="metric-label">Total de Ofertas</span>
                  <span class="metric-value">{{
                    metrics.stageMetrics.totalOffers
                  }}</span>
                </div>
                <div class="metric-summary-card">
                  <span class="metric-label">Valor Médio</span>
                  <span class="metric-value">{{
                    formatCurrency(metrics.stageMetrics.avgOffersValue)
                  }}</span>
                </div>
              </div>

              <div class="space-y-4">
                <h4
                  class="text-sm font-medium text-slate-600 dark:text-slate-300"
                >
                  Distribuição por Valor
                </h4>
                <div class="offer-range-bar">
                  <div class="flex justify-between mb-1">
                    <span class="text-sm text-slate-600">Até R$ 1.000</span>
                    <span class="text-sm font-medium">{{
                      metrics.stageMetrics.offerRanges.low
                    }}</span>
                  </div>
                  <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
                    <div
                      class="h-full bg-emerald-400 rounded-full transition-all duration-500"
                      :style="{
                        width: `${(metrics.stageMetrics.offerRanges.low / metrics.stageMetrics.totalOffers) * 100}%`,
                      }"
                    />
                  </div>
                </div>

                <div class="offer-range-bar">
                  <div class="flex justify-between mb-1">
                    <span class="text-sm text-slate-600"
                      >R$ 1.001 a R$ 5.000</span
                    >
                    <span class="text-sm font-medium">{{
                      metrics.stageMetrics.offerRanges.medium
                    }}</span>
                  </div>
                  <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
                    <div
                      class="h-full bg-emerald-500 rounded-full transition-all duration-500"
                      :style="{
                        width: `${(metrics.stageMetrics.offerRanges.medium / metrics.stageMetrics.totalOffers) * 100}%`,
                      }"
                    />
                  </div>
                </div>

                <div class="offer-range-bar">
                  <div class="flex justify-between mb-1">
                    <span class="text-sm text-slate-600"
                      >Acima de R$ 5.000</span
                    >
                    <span class="text-sm font-medium">{{
                      metrics.stageMetrics.offerRanges.high
                    }}</span>
                  </div>
                  <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
                    <div
                      class="h-full bg-emerald-600 rounded-full transition-all duration-500"
                      :style="{
                        width: `${(metrics.stageMetrics.offerRanges.high / metrics.stageMetrics.totalOffers) * 100}%`,
                      }"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Métricas de Atividade -->
        <div class="report-card md:col-span-2">
          <div class="card-header">
            <h3 class="flex items-center gap-2">
              <i class="i-ph-activity text-amber-500" />
              Métricas de Atividade
            </h3>
          </div>
          <div class="card-body">
            <div class="space-y-4 p-4">
              <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
                <div class="metric-summary-card">
                  <span class="metric-label">Mudanças de Estágio</span>
                  <span class="metric-value">{{
                    metrics.activityMetrics.stageChanges
                  }}</span>
                </div>
                <div class="metric-summary-card">
                  <span class="metric-label">Alterações de Valor</span>
                  <span class="metric-value">{{
                    metrics.activityMetrics.valueChanges
                  }}</span>
                </div>
                <div class="metric-summary-card">
                  <span class="metric-label">Mudanças de Agente</span>
                  <span class="metric-value">{{
                    metrics.activityMetrics.agentChanges
                  }}</span>
                </div>
              </div>
              <div class="activity-list space-y-2">
                <div
                  v-for="(count, type) in metrics.activityMetrics
                    .activitiesByType"
                  :key="type"
                  class="flex justify-between items-center p-2 bg-slate-50 dark:bg-slate-700 rounded"
                >
                  <span class="text-sm text-slate-600 dark:text-slate-300">{{
                    type === 'stage_changed'
                      ? 'Mudança de Estágio'
                      : type === 'value_changed'
                        ? 'Alteração de Valor'
                        : type === 'agent_changed'
                          ? 'Mudança de Agente'
                          : type === 'note_added'
                            ? 'Nota Adicionada'
                            : type === 'attachment_added'
                              ? 'Anexo Adicionado'
                              : type === 'checklist_item_added'
                                ? 'Item de Checklist Adicionado'
                                : type === 'checklist_item_toggled'
                                  ? 'Item de Checklist Alterado'
                                  : type === 'conversation_linked'
                                    ? 'Conversa Vinculada'
                                    : type
                  }}</span>
                  <span class="text-sm font-medium">{{ count }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.stats-card {
  @apply bg-white dark:bg-slate-800 rounded-lg p-4 flex items-center gap-4 shadow-sm transition-all duration-200 hover:shadow-md border border-slate-100 dark:border-slate-700;
}

.stats-icon {
  @apply p-3 rounded-lg flex items-center justify-center;
}

.stats-info {
  @apply flex flex-col;
}

.stats-info h4 {
  @apply text-xl font-semibold text-slate-900 dark:text-white;
}

.stats-info p {
  @apply text-sm text-slate-500 dark:text-slate-400;
}

.report-card {
  @apply bg-white dark:bg-slate-800 rounded-lg shadow-sm transition-all duration-200 hover:shadow-md border border-slate-100 dark:border-slate-700 overflow-hidden;
}

.card-header {
  @apply p-4 border-b border-slate-100 dark:border-slate-700;
}

.card-header h3 {
  @apply text-base font-medium text-slate-700 dark:text-slate-200;
}

.metric-summary-card {
  @apply bg-slate-50 dark:bg-slate-700 rounded-lg p-3 flex flex-col items-center transition-all duration-200;
}

.metric-summary-card .metric-label {
  @apply text-xs text-slate-500 dark:text-slate-400 mb-1 text-center;
}

.metric-summary-card .metric-value {
  @apply text-lg font-semibold text-slate-900 dark:text-white;
}

.stage-bar,
.priority-bar {
  @apply transition-all duration-200;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.report-card {
  animation: fadeIn 0.3s ease-out forwards;
}
</style>
