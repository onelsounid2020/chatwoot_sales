<script>
import { mapGetters } from 'vuex';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAccount } from 'dashboard/composables/useAccount';
import ReportsAPI from 'dashboard/api/reports';
import ChatList from '../../../components/ChatList.vue';
import ConversationBox from '../../../components/widgets/conversation/ConversationBox.vue';
import wootConstants from 'dashboard/constants/globals';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import CmdBarConversationSnooze from 'dashboard/routes/dashboard/commands/CmdBarConversationSnooze.vue';
import { emitter } from 'shared/helpers/mitt';
import SidepanelSwitch from 'dashboard/components-next/Conversation/SidepanelSwitch.vue';
import ConversationSidebar from 'dashboard/components/widgets/conversation/ConversationSidebar.vue';

export default {
  components: {
    ChatList,
    ConversationBox,
    CmdBarConversationSnooze,
    SidepanelSwitch,
    ConversationSidebar,
  },
  beforeRouteLeave(to, from, next) {
    // Clear selected state if navigating away from a conversation to a route without a conversationId to prevent stale data issues
    // and resolves timing issues during navigation with conversation view and other screens
    if (this.conversationId) {
      this.$store.dispatch('clearSelectedState');
    }
    next(); // Continue with navigation
  },
  props: {
    inboxId: {
      type: [String, Number],
      default: 0,
    },
    conversationId: {
      type: [String, Number],
      default: 0,
    },
    label: {
      type: String,
      default: '',
    },
    teamId: {
      type: String,
      default: '',
    },
    conversationType: {
      type: String,
      default: '',
    },
    foldersId: {
      type: [String, Number],
      default: 0,
    },
  },
  setup() {
    const { uiSettings, updateUISettings } = useUISettings();
    const { accountId } = useAccount();

    return {
      uiSettings,
      updateUISettings,
      accountId,
    };
  },
  data() {
    return {
      showSearchModal: false,
      isSalesOverviewLoading: false,
      salesOverviewLoadFailed: false,
      salesOverview: {
        open_opportunities: 0,
        stale_opportunities: 0,
        won_opportunities: 0,
        win_rate: 0,
        pipeline_value: 0,
        won_value: 0,
        stage_breakdown: [],
        agent_target_progress: [],
      },
    };
  },
  computed: {
    ...mapGetters({
      chatList: 'getAllConversations',
      currentChat: 'getSelectedChat',
      agents: 'agents/getAgents',
      teams: 'teams/getTeams',
      currentUser: 'getCurrentUser',
      currentAccount: 'getCurrentAccount',
    }),
    isHomeRoute() {
      return this.$route.name === 'home';
    },
    showConversationList() {
      return this.isOnExpandedLayout ? !this.conversationId : true;
    },
    showMessageView() {
      return this.conversationId ? true : !this.isOnExpandedLayout;
    },
    isOnExpandedLayout() {
      const {
        LAYOUT_TYPES: { CONDENSED },
      } = wootConstants;
      const { conversation_display_type: conversationDisplayType = CONDENSED } =
        this.uiSettings;
      return conversationDisplayType !== CONDENSED;
    },

    shouldShowSidebar() {
      if (!this.currentChat.id) {
        return false;
      }

      const { is_contact_sidebar_open: isContactSidebarOpen } = this.uiSettings;
      return isContactSidebarOpen;
    },
    salesOverviewCards() {
      const proposalStageCount = Number(
        (this.salesOverview.stage_breakdown || []).find(
          stage => stage.stage === 'proposal'
        )?.count || 0
      );
      return [
        {
          key: 'open_opportunities',
          quickViewId: 'proposal_stage',
          label: this.$t('CONVERSATION.SALES_HOME.CARDS.OPEN_OPPORTUNITIES'),
          value: this.formatNumber(this.salesOverview.open_opportunities),
          count: this.salesOverview.open_opportunities,
        },
        {
          key: 'stale_opportunities',
          quickViewId: 'missing_follow_up',
          label: this.$t('CONVERSATION.SALES_HOME.CARDS.STALE_OPPORTUNITIES'),
          value: this.formatNumber(this.salesOverview.stale_opportunities),
          count: this.salesOverview.stale_opportunities,
        },
        {
          key: 'win_rate',
          quickViewId: 'won_stage',
          label: this.$t('CONVERSATION.SALES_HOME.CARDS.WIN_RATE'),
          value: `${this.formatNumber(this.salesOverview.win_rate)}%`,
          count: this.salesOverview.won_opportunities,
        },
        {
          key: 'pipeline_value',
          quickViewId: 'proposal_stage',
          label: this.$t('CONVERSATION.SALES_HOME.CARDS.PIPELINE_VALUE'),
          value: this.formatCurrency(this.salesOverview.pipeline_value),
          count: proposalStageCount,
        },
        {
          key: 'won_value',
          quickViewId: 'won_stage',
          label: this.$t('CONVERSATION.SALES_HOME.CARDS.WON_VALUE'),
          value: this.formatCurrency(this.salesOverview.won_value),
          count: this.salesOverview.won_opportunities,
        },
      ];
    },
    stageBreakdownRows() {
      const rows = (this.salesOverview.stage_breakdown || []).map(item => ({
        stage: item.stage,
        count: Number(item.count || 0),
        label: this.getDealStageLabel(item.stage),
      }));
      return rows
        .filter(item => item.count > 0)
        .sort((a, b) => b.count - a.count)
        .slice(0, 5);
    },
    maxStageBreakdownCount() {
      return this.stageBreakdownRows.reduce(
        (maxValue, item) => Math.max(maxValue, item.count),
        0
      );
    },
    salesAlerts() {
      const alerts = [];

      if (this.salesOverview.stale_opportunities > 0) {
        alerts.push({
          id: 'overdue_follow_up',
          level: 'critical',
          quickViewId: 'missing_follow_up',
          title: this.$t('CONVERSATION.SALES_HOME.ALERTS.OVERDUE_FOLLOW_UP', {
            count: this.formatNumber(this.salesOverview.stale_opportunities),
          }),
        });
      }

      if (
        this.salesOverview.open_opportunities > 0 &&
        this.salesOverview.win_rate < 20
      ) {
        alerts.push({
          id: 'low_win_rate',
          level: 'warning',
          quickViewId: 'proposal_stage',
          title: this.$t('CONVERSATION.SALES_HOME.ALERTS.LOW_WIN_RATE', {
            rate: this.formatNumber(this.salesOverview.win_rate),
          }),
        });
      }

      if (
        this.salesOverview.open_opportunities > 0 &&
        this.salesOverview.won_opportunities === 0
      ) {
        alerts.push({
          id: 'no_wins',
          level: 'neutral',
          quickViewId: 'proposal_stage',
          title: this.$t('CONVERSATION.SALES_HOME.ALERTS.NO_WINS'),
        });
      }

      return alerts.slice(0, 3);
    },
    topAgentsRows() {
      return (this.salesOverview.agent_target_progress || [])
        .map(item => ({
          agentId: item.agent_id,
          agentName:
            item.agent_name ||
            this.$t('CONVERSATION.SALES_HOME.AGENTS.UNKNOWN_AGENT'),
          wonValue: Number(item.won_value || 0),
          targetValue: Number(item.target_value || 0),
          attainmentPercent: Number(item.attainment_percent || 0),
        }))
        .sort((a, b) => b.wonValue - a.wonValue)
        .slice(0, 3);
    },
    teamTargetSummary() {
      const rows = this.topAgentsRows;
      const totals = rows.reduce(
        (acc, item) => {
          acc.won += item.wonValue;
          acc.target += item.targetValue;
          return acc;
        },
        { won: 0, target: 0 }
      );
      const attainment =
        totals.target > 0 ? Math.round((totals.won / totals.target) * 100) : 0;
      return {
        won: totals.won,
        target: totals.target,
        attainment,
      };
    },
    activeSalesQuickView() {
      return this.$route.query.sales_view || 'all_sales';
    },
    activeSalesAgentId() {
      return Number(this.$route.query.sales_agent_id || 0);
    },
    activeSalesSortBy() {
      return this.$route.query.sales_sort || '';
    },
    activeSalesStageId() {
      return this.$route.query.sales_stage || 'all_stages';
    },
    canViewGlobalSales() {
      const permissions = this.currentAccount?.permissions || [];
      return (
        this.currentAccount?.role === 'administrator' ||
        permissions.includes('conversation_manage')
      );
    },
    canViewTeamSales() {
      const permissions = this.currentAccount?.permissions || [];
      return !this.canViewGlobalSales && permissions.includes('report_manage');
    },
    memberSalesTeams() {
      return (this.teams || []).filter(team => team.is_member);
    },
    selectedSalesTeamId() {
      return Number(this.$route.query.sales_team_id || 0);
    },
    canManageTeamScope() {
      return this.canViewGlobalSales || this.canViewTeamSales;
    },
    effectiveSalesTeamIds() {
      if (!this.canManageTeamScope) {
        return [];
      }

      if (this.canViewGlobalSales) {
        return this.selectedSalesTeamId ? [this.selectedSalesTeamId] : [];
      }

      const memberTeamIds = this.memberSalesTeams.map(team => Number(team.id));
      if (!memberTeamIds.length) return [];

      if (
        this.selectedSalesTeamId &&
        memberTeamIds.includes(this.selectedSalesTeamId)
      ) {
        return [this.selectedSalesTeamId];
      }

      return memberTeamIds;
    },
    selectedSalesTeamName() {
      if (!this.selectedSalesTeamId) return '';
      return (
        this.memberSalesTeams.find(
          team => Number(team.id) === this.selectedSalesTeamId
        )?.name || ''
      );
    },
    salesScopeLabel() {
      if (this.canViewGlobalSales) {
        return this.$t('CONVERSATION.SALES_HOME.SCOPE.GLOBAL');
      }
      if (this.canViewTeamSales) {
        return this.$t('CONVERSATION.SALES_HOME.SCOPE.TEAM');
      }
      return this.$t('CONVERSATION.SALES_HOME.SCOPE.OWN');
    },
    canManageAgentFilter() {
      return this.canViewGlobalSales || this.canViewTeamSales;
    },
    selectableSalesAgents() {
      return [...(this.agents || [])].sort((a, b) =>
        String(a.name || '').localeCompare(String(b.name || ''))
      );
    },
    effectiveSalesAgentId() {
      if (this.canManageAgentFilter) {
        return this.activeSalesAgentId;
      }
      return Number(this.currentUser?.id || 0);
    },
    hasActiveSalesQuickView() {
      return this.activeSalesQuickView !== 'all_sales';
    },
    preferredSalesQuickView() {
      return this.normalizeSalesQuickView(
        this.uiSettings?.sales_home_default_view
      );
    },
    preferredSalesStageId() {
      return this.normalizeSalesStage(
        this.uiSettings?.sales_home_default_stage || 'all_stages'
      );
    },
    preferredSalesSortBy() {
      return this.normalizeSalesSort(this.uiSettings?.sales_home_default_sort);
    },
    isSalesHomeDefaultsConfigured() {
      return Boolean(
        this.preferredSalesQuickView ||
          this.preferredSalesStageId !== 'all_stages' ||
          this.preferredSalesSortBy !== ''
      );
    },
    isActiveSalesViewDefault() {
      const hasExplicitSalesContext =
        this.hasActiveSalesQuickView ||
        this.activeSalesStageId !== 'all_stages' ||
        this.activeSalesSortBy !== '';
      if (!hasExplicitSalesContext) return false;
      return (
        this.activeSalesQuickView === this.preferredSalesQuickView &&
        this.activeSalesStageId === this.preferredSalesStageId &&
        this.activeSalesSortBy === this.preferredSalesSortBy
      );
    },
    canSetActiveSalesViewAsDefault() {
      const hasExplicitSalesContext =
        this.hasActiveSalesQuickView ||
        this.activeSalesStageId !== 'all_stages' ||
        this.activeSalesSortBy !== '';
      return (
        this.canManageTeamScope &&
        hasExplicitSalesContext &&
        !this.isActiveSalesViewDefault
      );
    },
    hasActiveSalesAgent() {
      return this.effectiveSalesAgentId > 0;
    },
    hasActiveSalesFilter() {
      return (
        this.hasActiveSalesQuickView ||
        this.hasActiveSalesAgent ||
        this.selectedSalesTeamId > 0 ||
        this.activeSalesSortBy !== '' ||
        this.activeSalesStageId !== 'all_stages'
      );
    },
    activeSalesQuickViewLabel() {
      const view = [
        {
          id: 'follow_up_today',
          label: this.$t('CHAT_LIST.SALES_QUICK_VIEWS.FOLLOW_UP_TODAY'),
        },
        {
          id: 'overdue_follow_up',
          label: this.$t('CHAT_LIST.SALES_QUICK_VIEWS.OVERDUE_FOLLOW_UP'),
        },
        {
          id: 'high_value_overdue_follow_up',
          label: this.$t(
            'CHAT_LIST.SALES_QUICK_VIEWS.HIGH_VALUE_OVERDUE_FOLLOW_UP'
          ),
        },
        {
          id: 'follow_up_next_1h',
          label: this.$t('CHAT_LIST.SALES_QUICK_VIEWS.FOLLOW_UP_NEXT_1H'),
        },
        {
          id: 'follow_up_next_24h',
          label: this.$t('CHAT_LIST.SALES_QUICK_VIEWS.FOLLOW_UP_NEXT_24H'),
        },
        {
          id: 'missing_follow_up',
          label: this.$t('CHAT_LIST.SALES_QUICK_VIEWS.MISSING_FOLLOW_UP'),
        },
        {
          id: 'proposal_stage',
          label: this.$t('CHAT_LIST.SALES_QUICK_VIEWS.PROPOSAL_STAGE'),
        },
        {
          id: 'won_stage',
          label: this.$t('CHAT_LIST.SALES_QUICK_VIEWS.WON_STAGE'),
        },
      ].find(item => item.id === this.activeSalesQuickView);
      return view?.label || '';
    },
    activeSalesAgentName() {
      if (!this.effectiveSalesAgentId) return '';
      const fromAgents = (this.agents || []).find(
        item => Number(item.id) === this.effectiveSalesAgentId
      )?.name;
      if (fromAgents) return fromAgents;

      const fromTop = this.topAgentsRows.find(
        item => Number(item.agentId) === this.effectiveSalesAgentId
      )?.agentName;
      return fromTop || '';
    },
    activeSalesStageLabel() {
      if (this.activeSalesStageId === 'all_stages') return '';
      return this.getDealStageLabel(this.activeSalesStageId);
    },
  },
  watch: {
    conversationId() {
      this.fetchConversationIfUnavailable();
    },
    '$route.query.sales_view'() {
      this.fetchSalesOverviewIfRequired();
    },
    '$route.query.sales_agent_id'() {
      this.fetchSalesOverviewIfRequired();
    },
    '$route.query.sales_team_id'() {
      this.fetchSalesOverviewIfRequired();
    },
    '$route.query.sales_stage'() {
      this.fetchSalesOverviewIfRequired();
    },
    '$route.name': {
      handler() {
        if (this.ensureDefaultSalesView()) return;
        this.fetchSalesOverviewIfRequired();
      },
      immediate: true,
    },
  },

  created() {
    // Clear selected state early if no conversation is selected
    // This prevents child components from accessing stale data
    // and resolves timing issues during navigation
    // with conversation view and other screens
    if (!this.conversationId) {
      this.$store.dispatch('clearSelectedState');
    }
  },

  mounted() {
    this.$store.dispatch('agents/get');
    this.$store.dispatch('teams/get');
    this.$store.dispatch('portals/index');
    this.initialize();
    this.$watch('$store.state.route', () => this.initialize());
    this.$watch('chatList.length', () => {
      this.setActiveChat();
    });
  },

  methods: {
    normalizeSalesQuickView(viewId) {
      const supportedViews = [
        'all_sales',
        'missing_follow_up',
        'proposal_stage',
        'won_stage',
        'follow_up_today',
        'overdue_follow_up',
        'high_value_overdue_follow_up',
        'follow_up_next_1h',
        'follow_up_next_24h',
        'high_value_no_follow_up',
      ];

      const normalizedView = String(viewId || '');
      return supportedViews.includes(normalizedView) ? normalizedView : '';
    },
    normalizeSalesStage(stageId) {
      const supportedStages = [
        'all_stages',
        'incoming',
        'contacted',
        'qualified',
        'proposal',
        'won',
        'lost',
      ];
      const normalizedStage = String(stageId || 'all_stages');
      return supportedStages.includes(normalizedStage)
        ? normalizedStage
        : 'all_stages';
    },
    normalizeSalesSort(sortBy) {
      const normalizedSort = String(sortBy || '');
      if (!normalizedSort) return '';
      const supportedSorts = Object.values(wootConstants.SORT_BY_TYPE);
      return supportedSorts.includes(normalizedSort) ? normalizedSort : '';
    },
    savePreferredSalesHomeDefaults() {
      if (!this.canManageTeamScope) return;
      const normalizedView = this.normalizeSalesQuickView(
        this.activeSalesQuickView || 'all_sales'
      );
      const normalizedStage = this.normalizeSalesStage(this.activeSalesStageId);
      const normalizedSort = this.normalizeSalesSort(this.activeSalesSortBy);

      if (
        this.uiSettings?.sales_home_default_view === normalizedView &&
        this.uiSettings?.sales_home_default_stage === normalizedStage &&
        this.uiSettings?.sales_home_default_sort === normalizedSort
      ) {
        return;
      }

      this.updateUISettings({
        sales_home_default_view: normalizedView,
        sales_home_default_stage: normalizedStage,
        sales_home_default_sort: normalizedSort,
      });
    },
    resetPreferredSalesHomeDefaults() {
      if (!this.canManageTeamScope) return;
      if (!this.isSalesHomeDefaultsConfigured) return;

      this.updateUISettings({
        sales_home_default_view: null,
        sales_home_default_stage: null,
        sales_home_default_sort: null,
      });
    },
    onConversationLoad() {
      this.fetchConversationIfUnavailable();
    },
    initialize() {
      this.$store.dispatch('setActiveInbox', this.inboxId);
      this.setActiveChat();
    },
    toggleConversationLayout() {
      const { LAYOUT_TYPES } = wootConstants;
      const {
        conversation_display_type:
          conversationDisplayType = LAYOUT_TYPES.CONDENSED,
      } = this.uiSettings;
      const newViewType =
        conversationDisplayType === LAYOUT_TYPES.CONDENSED
          ? LAYOUT_TYPES.EXPANDED
          : LAYOUT_TYPES.CONDENSED;
      this.updateUISettings({
        conversation_display_type: newViewType,
        previously_used_conversation_display_type: newViewType,
      });
    },
    fetchConversationIfUnavailable() {
      if (!this.conversationId) {
        return;
      }
      const chat = this.findConversation();
      if (!chat) {
        this.$store.dispatch('getConversation', this.conversationId);
      }
    },
    findConversation() {
      const conversationId = parseInt(this.conversationId, 10);
      const [chat] = this.chatList.filter(c => c.id === conversationId);
      return chat;
    },
    setActiveChat() {
      if (this.conversationId) {
        const selectedConversation = this.findConversation();
        // If conversation doesn't exist or selected conversation is same as the active
        // conversation, don't set active conversation.
        if (
          !selectedConversation ||
          selectedConversation.id === this.currentChat.id
        ) {
          return;
        }
        const { messageId } = this.$route.query;
        this.$store
          .dispatch('setActiveChat', {
            data: selectedConversation,
            after: messageId,
          })
          .then(() => {
            emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, { messageId });
          });
      } else {
        this.$store.dispatch('clearSelectedState');
      }
    },
    onSearch() {
      this.showSearchModal = true;
    },
    closeSearch() {
      this.showSearchModal = false;
    },
    formatNumber(value) {
      return new Intl.NumberFormat(this.$i18n.locale || 'en').format(
        Number(value) || 0
      );
    },
    formatCurrency(value) {
      return new Intl.NumberFormat(this.$i18n.locale || 'en', {
        style: 'currency',
        currency: 'CLP',
        maximumFractionDigits: 0,
      }).format(Number(value) || 0);
    },
    async fetchSalesOverviewIfRequired() {
      if (!this.isHomeRoute) return;
      await this.fetchSalesOverview();
    },
    ensureDefaultSalesView() {
      if (!this.isHomeRoute || !this.canManageTeamScope) return false;

      const query = this.$route.query || {};
      const hasSalesFilters =
        query.sales_view ||
        query.sales_agent_id ||
        query.sales_team_id ||
        query.sales_stage ||
        query.sales_sort;

      if (hasSalesFilters) return false;

      const preferredView =
        this.normalizeSalesQuickView(
          this.uiSettings?.sales_home_default_view
        ) || 'high_value_overdue_follow_up';
      const preferredStage = this.normalizeSalesStage(
        this.uiSettings?.sales_home_default_stage || 'all_stages'
      );
      const preferredSort = this.normalizeSalesSort(
        this.uiSettings?.sales_home_default_sort
      );

      const nextQuery = { ...query };
      let hasAnyDefaultFilter = false;
      if (preferredView && preferredView !== 'all_sales') {
        nextQuery.sales_view = preferredView;
        hasAnyDefaultFilter = true;
      }
      if (preferredStage !== 'all_stages') {
        nextQuery.sales_stage = preferredStage;
        hasAnyDefaultFilter = true;
      }
      if (
        preferredSort &&
        preferredSort !== wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC
      ) {
        nextQuery.sales_sort = preferredSort;
        hasAnyDefaultFilter = true;
      }
      if (!hasAnyDefaultFilter) return false;

      this.$router.replace({
        query: nextQuery,
      });
      return true;
    },
    async fetchSalesOverview() {
      this.isSalesOverviewLoading = true;
      this.salesOverviewLoadFailed = false;
      try {
        const until = Math.floor(Date.now() / 1000);
        const since = until - 30 * 24 * 60 * 60;
        const { data } = await ReportsAPI.getSalesMetrics({
          from: since,
          to: until,
          assigneeId: this.effectiveSalesAgentId || undefined,
          teamIds: this.effectiveSalesTeamIds.length
            ? this.effectiveSalesTeamIds
            : undefined,
        });
        this.salesOverview = {
          open_opportunities: Number(data?.open_opportunities || 0),
          stale_opportunities: Number(data?.stale_opportunities || 0),
          won_opportunities: Number(data?.won_opportunities || 0),
          win_rate: Number(data?.win_rate || 0),
          pipeline_value: Number(data?.pipeline_value || 0),
          won_value: Number(data?.won_value || 0),
          stage_breakdown: Array.isArray(data?.stage_breakdown)
            ? data.stage_breakdown
            : [],
          agent_target_progress: Array.isArray(data?.agent_target_progress)
            ? data.agent_target_progress
            : [],
        };
      } catch (error) {
        this.salesOverviewLoadFailed = true;
      } finally {
        this.isSalesOverviewLoading = false;
      }
    },
    goToSalesPipeline() {
      this.$router.push({
        name: 'sales_pipeline_index',
        params: { accountId: this.accountId },
      });
    },
    goToSalesReports() {
      this.$router.push({
        name: 'sales_reports',
        params: { accountId: this.accountId },
      });
    },
    selectSalesQuickView(quickViewId) {
      const nextQuery = { ...this.$route.query };
      if (this.canManageAgentFilter) {
        delete nextQuery.sales_agent_id;
      }
      this.$router.replace({
        query: {
          ...nextQuery,
          sales_view: quickViewId,
        },
      });
    },
    clearSalesQuickView() {
      const nextQuery = { ...this.$route.query };
      delete nextQuery.sales_view;
      this.$router.replace({ query: nextQuery });
    },
    clearSalesFilters() {
      const nextQuery = { ...this.$route.query };
      delete nextQuery.sales_view;
      delete nextQuery.sales_stage;
      delete nextQuery.sales_sort;
      if (this.canManageAgentFilter) {
        delete nextQuery.sales_agent_id;
      }
      if (this.canManageTeamScope) {
        delete nextQuery.sales_team_id;
      }
      this.$router.replace({ query: nextQuery });
    },
    clearSalesAgent() {
      if (!this.canManageAgentFilter) return;
      const nextQuery = { ...this.$route.query };
      delete nextQuery.sales_agent_id;
      this.$router.replace({ query: nextQuery });
    },
    selectSalesAgent(agentId) {
      if (!this.canManageAgentFilter) return;
      const normalizedAgentId = Number(agentId || 0);
      if (!normalizedAgentId) {
        this.clearSalesAgent();
        return;
      }
      this.$router.replace({
        query: {
          ...this.$route.query,
          sales_agent_id: String(normalizedAgentId),
        },
      });
    },
    selectSalesTeam(teamId) {
      if (!this.canManageTeamScope) return;
      const normalizedTeamId = Number(teamId || 0);
      const nextQuery = { ...this.$route.query };
      if (normalizedTeamId > 0) {
        nextQuery.sales_team_id = String(normalizedTeamId);
      } else {
        delete nextQuery.sales_team_id;
      }
      this.$router.replace({ query: nextQuery });
    },
    clearSalesTeam() {
      if (!this.canManageTeamScope) return;
      const nextQuery = { ...this.$route.query };
      delete nextQuery.sales_team_id;
      this.$router.replace({ query: nextQuery });
    },
    clearSalesStage() {
      const nextQuery = { ...this.$route.query };
      delete nextQuery.sales_stage;
      this.$router.replace({ query: nextQuery });
    },
    getDealStageLabel(stage) {
      const normalizedStage = String(stage || 'incoming').toUpperCase();
      const stageKey = `CONVERSATION.SALES.DEAL_STAGE.OPTIONS.${normalizedStage}`;
      const translation = this.$t(stageKey);
      if (translation === stageKey) {
        return this.$t('CONVERSATION.SALES.DEAL_STAGE.OPTIONS.INCOMING');
      }
      return translation;
    },
    stageBarRatio(count) {
      return Number(count || 0) / Math.max(this.maxStageBreakdownCount, 1);
    },
    progressRatio(attainment) {
      return Number(attainment || 0) / 100;
    },
    progressWidthClass(ratio) {
      if (ratio <= 0.1) return 'w-1/12';
      if (ratio <= 0.2) return 'w-2/12';
      if (ratio <= 0.3) return 'w-3/12';
      if (ratio <= 0.4) return 'w-4/12';
      if (ratio <= 0.5) return 'w-5/12';
      if (ratio <= 0.6) return 'w-6/12';
      if (ratio <= 0.7) return 'w-7/12';
      if (ratio <= 0.8) return 'w-8/12';
      if (ratio <= 0.9) return 'w-9/12';
      return 'w-full';
    },
    progressToneClass(attainment) {
      if (Number(attainment || 0) >= 100) return 'bg-emerald-500';
      if (Number(attainment || 0) >= 60) return 'bg-amber-500';
      return 'bg-red-500';
    },
  },
};
</script>

<template>
  <section class="flex flex-col w-full h-full min-w-0">
    <div
      v-if="isHomeRoute"
      class="px-3 py-3 border-b border-n-weak bg-n-alpha-2 backdrop-blur-sm"
    >
      <div
        class="flex flex-wrap items-start justify-between gap-3 px-3 py-3 rounded-2xl bg-n-solid-1 border border-n-weak shadow-sm"
      >
        <div class="space-y-1">
          <p class="text-[11px] uppercase tracking-[0.08em] text-n-slate-11">
            {{ $t('CONVERSATION.SALES_HOME.HEADLINE') }}
          </p>
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ $t('CONVERSATION.SALES_HOME.SUBHEAD') }}
          </h2>
          <p class="text-xs text-n-slate-10">
            {{
              $t('CONVERSATION.SALES_HOME.SCOPE_LABEL', {
                scope: salesScopeLabel,
              })
            }}
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <div
            v-if="canManageTeamScope && memberSalesTeams.length"
            class="relative inline-flex h-9 w-36 md:w-44 items-center rounded-lg border border-n-weak bg-n-solid-1"
          >
            <select
              class="h-full w-full appearance-none bg-transparent pl-3 pr-7 text-xs text-n-slate-12 focus:outline-none"
              :value="selectedSalesTeamId"
              :aria-label="$t('CONVERSATION.SALES_HOME.TEAM_FILTER.LABEL')"
              @change="selectSalesTeam($event.target.value)"
            >
              <option :value="0">
                {{ $t('CONVERSATION.SALES_HOME.TEAM_FILTER.ALL') }}
              </option>
              <option
                v-for="team in memberSalesTeams"
                :key="team.id"
                :value="Number(team.id)"
              >
                {{ team.name }}
              </option>
            </select>
            <svg
              class="pointer-events-none absolute right-2 h-3 w-3 text-n-slate-10"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 11.168l3.71-3.937a.75.75 0 1 1 1.08 1.04l-4.25 4.51a.75.75 0 0 1-1.08 0l-4.25-4.51a.75.75 0 0 1 .02-1.06Z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div
            v-if="canManageAgentFilter && selectableSalesAgents.length"
            class="relative inline-flex h-9 w-36 md:w-44 items-center rounded-lg border border-n-weak bg-n-solid-1"
          >
            <select
              class="h-full w-full appearance-none bg-transparent pl-3 pr-7 text-xs text-n-slate-12 focus:outline-none"
              :value="activeSalesAgentId"
              :aria-label="$t('CONVERSATION.SALES_HOME.AGENT_FILTER.LABEL')"
              @change="selectSalesAgent($event.target.value)"
            >
              <option :value="0">
                {{ $t('CONVERSATION.SALES_HOME.AGENT_FILTER.ALL') }}
              </option>
              <option
                v-for="agent in selectableSalesAgents"
                :key="agent.id"
                :value="Number(agent.id)"
              >
                {{ agent.name }}
              </option>
            </select>
            <svg
              class="pointer-events-none absolute right-2 h-3 w-3 text-n-slate-10"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M5.23 7.21a.75.75 0 0 1 1.06.02L10 11.168l3.71-3.937a.75.75 0 1 1 1.08 1.04l-4.25 4.51a.75.75 0 0 1-1.08 0l-4.25-4.51a.75.75 0 0 1 .02-1.06Z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <button
            v-if="
              hasActiveSalesQuickView ||
              (canManageAgentFilter && hasActiveSalesAgent) ||
              selectedSalesTeamId > 0 ||
              activeSalesStageId !== 'all_stages'
            "
            type="button"
            class="inline-flex h-9 items-center px-3 text-xs font-medium rounded-lg border border-n-weak bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3"
            @click="clearSalesFilters"
          >
            {{ $t('CONVERSATION.SALES_HOME.ACTIONS.CLEAR_FILTER') }}
          </button>
          <button
            v-if="canSetActiveSalesViewAsDefault"
            type="button"
            class="inline-flex h-9 items-center px-3 text-xs font-medium rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12 hover:bg-n-alpha-2"
            @click="savePreferredSalesHomeDefaults()"
          >
            {{ $t('CONVERSATION.SALES_HOME.ACTIONS.SAVE_DEFAULT_VIEW') }}
          </button>
          <button
            v-if="canManageTeamScope && isSalesHomeDefaultsConfigured"
            type="button"
            class="inline-flex h-9 items-center px-3 text-xs font-medium rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12 hover:bg-n-alpha-2"
            @click="resetPreferredSalesHomeDefaults()"
          >
            {{ $t('CONVERSATION.SALES_HOME.ACTIONS.RESET_DEFAULT_VIEW') }}
          </button>
          <button
            type="button"
            class="inline-flex h-9 items-center px-3 text-xs font-medium rounded-lg border border-n-weak bg-n-alpha-3 text-n-slate-12 hover:bg-n-alpha-4"
            @click="goToSalesPipeline"
          >
            {{ $t('CONVERSATION.SALES_HOME.ACTIONS.PIPELINE') }}
          </button>
          <button
            type="button"
            class="inline-flex h-9 items-center px-3 text-xs font-medium rounded-lg bg-n-brand text-n-solid-1 hover:brightness-110"
            @click="goToSalesReports"
          >
            {{ $t('CONVERSATION.SALES_HOME.ACTIONS.REPORTS') }}
          </button>
        </div>
      </div>
      <div
        v-if="hasActiveSalesFilter"
        class="flex flex-wrap items-center gap-2 mt-2"
      >
        <span class="text-xs text-n-slate-10">
          {{ $t('CONVERSATION.SALES_HOME.ACTIVE_FILTERS_LABEL') }}
        </span>
        <span
          v-if="hasActiveSalesQuickView"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-n-weak bg-n-alpha-2 text-xs text-n-slate-12"
        >
          {{
            $t('CONVERSATION.SALES_HOME.ACTIVE_VIEW_CHIP', {
              view: activeSalesQuickViewLabel,
            })
          }}
          <span
            v-if="isActiveSalesViewDefault"
            class="inline-flex items-center px-1.5 py-0.5 rounded-full bg-n-brand/20 text-[10px] font-medium text-n-brand"
          >
            {{ $t('CONVERSATION.SALES_HOME.DEFAULT_VIEW_BADGE') }}
          </span>
          <button
            type="button"
            class="inline-flex h-4 w-4 items-center justify-center rounded-full text-n-slate-11 hover:bg-n-alpha-3 hover:text-n-slate-12"
            @click="clearSalesQuickView"
          >
            {{ $t('CONVERSATION.SALES_HOME.CLOSE_CHIP') }}
          </button>
        </span>
        <span
          v-if="activeSalesStageId !== 'all_stages' && activeSalesStageLabel"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-n-weak bg-n-alpha-2 text-xs text-n-slate-12"
        >
          {{
            $t('CONVERSATION.SALES_HOME.ACTIVE_STAGE_CHIP', {
              stage: activeSalesStageLabel,
            })
          }}
          <button
            type="button"
            class="inline-flex h-4 w-4 items-center justify-center rounded-full text-n-slate-11 hover:bg-n-alpha-3 hover:text-n-slate-12"
            @click="clearSalesStage"
          >
            {{ $t('CONVERSATION.SALES_HOME.CLOSE_CHIP') }}
          </button>
        </span>
        <span
          v-if="selectedSalesTeamId && selectedSalesTeamName"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-n-weak bg-n-alpha-2 text-xs text-n-slate-12"
        >
          {{
            $t('CONVERSATION.SALES_HOME.ACTIVE_TEAM_CHIP', {
              team: selectedSalesTeamName,
            })
          }}
          <button
            v-if="canManageTeamScope"
            type="button"
            class="inline-flex h-4 w-4 items-center justify-center rounded-full text-n-slate-11 hover:bg-n-alpha-3 hover:text-n-slate-12"
            @click="clearSalesTeam"
          >
            {{ $t('CONVERSATION.SALES_HOME.CLOSE_CHIP') }}
          </button>
        </span>
        <span
          v-if="hasActiveSalesAgent"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-n-weak bg-n-alpha-2 text-xs text-n-slate-12"
        >
          {{
            $t('CONVERSATION.SALES_HOME.ACTIVE_AGENT_CHIP', {
              agent: activeSalesAgentName,
            })
          }}
          <button
            v-if="canManageAgentFilter"
            type="button"
            class="inline-flex h-4 w-4 items-center justify-center rounded-full text-n-slate-11 hover:bg-n-alpha-3 hover:text-n-slate-12"
            @click="clearSalesAgent"
          >
            {{ $t('CONVERSATION.SALES_HOME.CLOSE_CHIP') }}
          </button>
        </span>
      </div>

      <div class="grid grid-cols-2 gap-2 mt-3 md:grid-cols-5">
        <button
          v-for="card in salesOverviewCards"
          :key="card.key"
          type="button"
          class="px-3 py-2 rounded-xl border text-left transition-colors duration-150 hover:border-n-brand/40 hover:bg-n-alpha-2 focus:outline-none focus:ring-2 focus:ring-n-brand/30"
          :class="
            activeSalesQuickView === card.quickViewId
              ? 'bg-n-brand/10 border-n-brand text-n-brand'
              : 'bg-n-solid-1 border-n-weak'
          "
          @click="selectSalesQuickView(card.quickViewId)"
        >
          <div class="flex items-start justify-between gap-2">
            <p
              class="text-[11px] uppercase tracking-wide"
              :class="
                activeSalesQuickView === card.quickViewId
                  ? 'text-n-brand'
                  : 'text-n-slate-10'
              "
            >
              {{ card.label }}
            </p>
            <span
              class="inline-flex items-center px-1.5 py-0.5 text-[10px] font-medium rounded-full"
              :class="
                activeSalesQuickView === card.quickViewId
                  ? 'bg-n-brand/20 text-n-brand'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
            >
              {{
                $t('CONVERSATION.SALES_HOME.CARDS_COUNT', {
                  count: formatNumber(card.count),
                })
              }}
            </span>
          </div>
          <p
            class="mt-1 text-sm font-semibold"
            :class="
              activeSalesQuickView === card.quickViewId
                ? 'text-n-brand'
                : 'text-n-slate-12'
            "
          >
            {{ card.value }}
          </p>
        </button>
      </div>

      <div class="grid gap-2 mt-2 md:grid-cols-2">
        <div class="p-3 rounded-xl bg-n-solid-1 border border-n-weak shadow-sm">
          <div class="flex items-center justify-between gap-2">
            <p class="text-xs font-semibold text-n-slate-12">
              {{ $t('CONVERSATION.SALES_HOME.ALERTS.TITLE') }}
            </p>
          </div>
          <div v-if="salesAlerts.length" class="flex flex-col gap-2 mt-2">
            <button
              v-for="alert in salesAlerts"
              :key="alert.id"
              type="button"
              class="w-full flex items-center justify-between gap-2 px-2 py-1.5 rounded-lg text-left border"
              :class="
                alert.level === 'critical'
                  ? 'border-red-200 bg-red-50 text-red-700'
                  : alert.level === 'warning'
                    ? 'border-amber-200 bg-amber-50 text-amber-700'
                    : 'border-n-weak bg-n-alpha-2 text-n-slate-11'
              "
              @click="selectSalesQuickView(alert.quickViewId)"
            >
              <span class="text-xs font-medium">{{ alert.title }}</span>
              <span class="text-[11px] font-semibold">
                {{ $t('CONVERSATION.SALES_HOME.ALERTS.ACTION') }}
              </span>
            </button>
          </div>
          <p v-else class="mt-2 text-xs text-n-slate-10">
            {{ $t('CONVERSATION.SALES_HOME.ALERTS.EMPTY') }}
          </p>
        </div>

        <div class="p-3 rounded-xl bg-n-solid-1 border border-n-weak shadow-sm">
          <p class="text-xs font-semibold text-n-slate-12">
            {{ $t('CONVERSATION.SALES_HOME.STAGES.TITLE') }}
          </p>
          <div
            v-if="stageBreakdownRows.length"
            class="flex flex-col gap-2 mt-2"
          >
            <div
              v-for="item in stageBreakdownRows"
              :key="item.stage"
              class="space-y-1"
            >
              <div class="flex items-center justify-between gap-2">
                <p class="text-xs text-n-slate-11">
                  {{ item.label }}
                </p>
                <p class="text-xs font-semibold text-n-slate-12">
                  {{ formatNumber(item.count) }}
                </p>
              </div>
              <div
                class="w-full h-1.5 rounded-full bg-n-alpha-2 overflow-hidden"
              >
                <div
                  class="h-full rounded-full bg-n-brand min-w-[8%]"
                  :class="{
                    'w-1/12': stageBarRatio(item.count) <= 0.1,
                    'w-2/12':
                      stageBarRatio(item.count) > 0.1 &&
                      stageBarRatio(item.count) <= 0.2,
                    'w-3/12':
                      stageBarRatio(item.count) > 0.2 &&
                      stageBarRatio(item.count) <= 0.3,
                    'w-4/12':
                      stageBarRatio(item.count) > 0.3 &&
                      stageBarRatio(item.count) <= 0.4,
                    'w-5/12':
                      stageBarRatio(item.count) > 0.4 &&
                      stageBarRatio(item.count) <= 0.5,
                    'w-6/12':
                      stageBarRatio(item.count) > 0.5 &&
                      stageBarRatio(item.count) <= 0.6,
                    'w-7/12':
                      stageBarRatio(item.count) > 0.6 &&
                      stageBarRatio(item.count) <= 0.7,
                    'w-8/12':
                      stageBarRatio(item.count) > 0.7 &&
                      stageBarRatio(item.count) <= 0.8,
                    'w-9/12':
                      stageBarRatio(item.count) > 0.8 &&
                      stageBarRatio(item.count) <= 0.9,
                    'w-full': stageBarRatio(item.count) > 0.9,
                  }"
                />
              </div>
            </div>
          </div>
          <p v-else class="mt-2 text-xs text-n-slate-10">
            {{ $t('CONVERSATION.SALES_HOME.STAGES.EMPTY') }}
          </p>
        </div>
      </div>
      <div class="grid gap-2 mt-2 md:grid-cols-2">
        <div class="p-3 rounded-xl bg-n-solid-1 border border-n-weak shadow-sm">
          <p class="text-xs font-semibold text-n-slate-12">
            {{ $t('CONVERSATION.SALES_HOME.AGENTS.TITLE') }}
          </p>
          <div v-if="topAgentsRows.length" class="flex flex-col gap-2 mt-2">
            <div
              v-for="(item, index) in topAgentsRows"
              :key="item.agentId || `${item.agentName}-${index}`"
              class="px-2 py-1.5 rounded-lg border bg-n-alpha-2 cursor-pointer transition-colors duration-150 hover:border-n-brand/40 focus:outline-none"
              :class="
                effectiveSalesAgentId === Number(item.agentId)
                  ? 'border-n-brand bg-n-brand/10'
                  : 'border-n-weak'
              "
              role="button"
              tabindex="0"
              @click="selectSalesAgent(item.agentId)"
            >
              <div class="flex items-center justify-between gap-2">
                <p class="text-xs font-medium text-n-slate-12">
                  {{ item.agentName }}
                </p>
                <p class="text-xs font-semibold text-n-slate-12">
                  {{ formatCurrency(item.wonValue) }}
                </p>
              </div>
              <p class="mt-1 text-[11px] text-n-slate-10">
                {{
                  $t('CONVERSATION.SALES_HOME.AGENTS.ATTAINMENT', {
                    percent: formatNumber(item.attainmentPercent),
                  })
                }}
              </p>
            </div>
          </div>
          <p v-else class="mt-2 text-xs text-n-slate-10">
            {{ $t('CONVERSATION.SALES_HOME.AGENTS.EMPTY') }}
          </p>
        </div>
        <div class="p-3 rounded-xl bg-n-solid-1 border border-n-weak shadow-sm">
          <div class="flex items-center justify-between gap-2">
            <p class="text-xs font-semibold text-n-slate-12">
              {{ $t('CONVERSATION.SALES_HOME.TARGET.TITLE') }}
            </p>
            <p class="text-xs font-semibold text-n-slate-12">
              {{
                $t('CONVERSATION.SALES_HOME.TARGET.PERCENT', {
                  percent: formatNumber(teamTargetSummary.attainment),
                })
              }}
            </p>
          </div>
          <p class="mt-2 text-xs text-n-slate-11">
            {{
              $t('CONVERSATION.SALES_HOME.TARGET.SUBTITLE', {
                won: formatCurrency(teamTargetSummary.won),
                target: formatCurrency(teamTargetSummary.target),
              })
            }}
          </p>
          <div
            class="w-full h-2 mt-2 rounded-full bg-n-alpha-2 overflow-hidden"
          >
            <div
              class="h-full rounded-full min-w-[8%]"
              :class="[
                progressWidthClass(progressRatio(teamTargetSummary.attainment)),
                progressToneClass(teamTargetSummary.attainment),
              ]"
            />
          </div>
        </div>
      </div>

      <p v-if="isSalesOverviewLoading" class="mt-2 text-xs text-n-slate-10">
        {{ $t('CONVERSATION.SALES_HOME.LOADING') }}
      </p>
      <p v-else-if="salesOverviewLoadFailed" class="mt-2 text-xs text-red-500">
        {{ $t('CONVERSATION.SALES_HOME.LOAD_ERROR') }}
      </p>
      <p v-else class="mt-2 text-xs text-n-slate-10">
        {{ $t('CONVERSATION.SALES_HOME.RANGE_NOTE') }}
      </p>
    </div>

    <div class="flex flex-1 min-h-0 w-full">
      <ChatList
        :show-conversation-list="showConversationList"
        :conversation-inbox="inboxId"
        :label="label"
        :team-id="teamId"
        :conversation-type="conversationType"
        :folders-id="foldersId"
        :sales-quick-view="isHomeRoute ? $route.query.sales_view : ''"
        :sales-agent-id="isHomeRoute ? effectiveSalesAgentId : ''"
        :sales-team-id="isHomeRoute ? selectedSalesTeamId : ''"
        :sales-stage-id="isHomeRoute ? activeSalesStageId : ''"
        :sales-sort-by="isHomeRoute ? activeSalesSortBy : ''"
        :is-on-expanded-layout="isOnExpandedLayout"
        @conversation-load="onConversationLoad"
      />
      <ConversationBox
        v-if="showMessageView"
        :inbox-id="inboxId"
        :is-on-expanded-layout="isOnExpandedLayout"
      >
        <SidepanelSwitch v-if="currentChat.id" />
      </ConversationBox>
      <ConversationSidebar
        v-if="shouldShowSidebar"
        :current-chat="currentChat"
      />
      <CmdBarConversationSnooze />
    </div>
  </section>
</template>
