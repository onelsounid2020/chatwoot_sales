<script setup>
import { computed } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store.js';
import { ARTICLE_TABS, CATEGORY_ALL } from 'dashboard/helper/portalHelper';

import HelpCenterLayout from 'dashboard/components-next/HelpCenter/HelpCenterLayout.vue';
import ArticleList from 'dashboard/components-next/HelpCenter/Pages/ArticlePage/ArticleList.vue';
import ArticleHeaderControls from 'dashboard/components-next/HelpCenter/Pages/ArticlePage/ArticleHeaderControls.vue';
import CategoryHeaderControls from 'dashboard/components-next/HelpCenter/Pages/CategoryPage/CategoryHeaderControls.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ArticleEmptyState from 'dashboard/components-next/HelpCenter/EmptyState/Article/ArticleEmptyState.vue';

const props = defineProps({
  articles: {
    type: Array,
    required: true,
  },
  categories: {
    type: Array,
    required: true,
  },
  allowedLocales: {
    type: Array,
    required: true,
  },
  portalName: {
    type: String,
    required: true,
  },
  meta: {
    type: Object,
    required: true,
  },
  isCategoryArticles: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['pageChange', 'fetchPortal']);

const router = useRouter();
const route = useRoute();
const { t } = useI18n();

const isSwitchingPortal = useMapGetter('portals/isSwitchingPortal');
const isFetching = useMapGetter('articles/isFetching');

const hasNoArticles = computed(
  () => !isFetching.value && !props.articles.length
);

const isLoading = computed(() => isFetching.value || isSwitchingPortal.value);

const totalArticlesCount = computed(() => props.meta.allArticlesCount);

const hasNoArticlesInPortal = computed(
  () => totalArticlesCount.value === 0 && !props.isCategoryArticles
);

const shouldShowPaginationFooter = computed(() => {
  return !(isFetching.value || isSwitchingPortal.value || hasNoArticles.value);
});

const feedbackInsights = computed(() => props.meta.feedbackInsights || []);
const unansweredSearches = computed(() => props.meta.unansweredSearches || []);
const selectedLocaleName = computed(
  () =>
    props.allowedLocales.find(locale => locale.code === route.params.locale)
      ?.name || route.params.locale
);
const selectedCategoryName = computed(() => {
  if (!route.params.categorySlug) {
    return t('HELP_CENTER.ARTICLES_PAGE.ARTICLES_HEADER.CATEGORY.ALL');
  }
  return (
    props.categories.find(
      category => category.slug === route.params.categorySlug
    )?.name || route.params.categorySlug
  );
});
const insightsScopeText = computed(() =>
  t('HELP_CENTER.ARTICLES_PAGE.INSIGHTS.SCOPE', {
    locale: selectedLocaleName.value,
    category: selectedCategoryName.value,
  })
);

const updateRoute = newParams => {
  const { portalSlug, locale, tab, categorySlug } = route.params;
  router.push({
    name: 'portals_articles_index',
    params: {
      portalSlug,
      locale: newParams.locale ?? locale,
      tab: newParams.tab ?? tab,
      categorySlug: newParams.categorySlug ?? categorySlug,
      ...newParams,
    },
  });
};

const articlesCount = computed(() => {
  const { tab } = route.params;
  const { meta } = props;
  const countMap = {
    '': meta.articlesCount,
    mine: meta.mineArticlesCount,
    draft: meta.draftArticlesCount,
    archived: meta.archivedArticlesCount,
  };
  return Number(countMap[tab] || countMap['']);
});

const showArticleHeaderControls = computed(
  () => !props.isCategoryArticles && !isSwitchingPortal.value
);

const showCategoryHeaderControls = computed(
  () => props.isCategoryArticles && !isSwitchingPortal.value
);

const getEmptyStateText = type => {
  if (props.isCategoryArticles) {
    return t(`HELP_CENTER.ARTICLES_PAGE.EMPTY_STATE.CATEGORY.${type}`);
  }
  const tabName = route.params.tab?.toUpperCase() || 'ALL';
  return t(`HELP_CENTER.ARTICLES_PAGE.EMPTY_STATE.${tabName}.${type}`);
};

const getEmptyStateTitle = computed(() => getEmptyStateText('TITLE'));
const getEmptyStateSubtitle = computed(() => getEmptyStateText('SUBTITLE'));

const handleTabChange = tab =>
  updateRoute({ tab: tab.value === ARTICLE_TABS.ALL ? '' : tab.value });

const handleCategoryAction = value =>
  updateRoute({ categorySlug: value === CATEGORY_ALL ? '' : value });

const handleLocaleAction = value => {
  updateRoute({ locale: value, categorySlug: '' });
  emit('fetchPortal', value);
};
const handlePageChange = page => emit('pageChange', page);
const formatFeedbackMetric = item =>
  t('HELP_CENTER.ARTICLES_PAGE.INSIGHTS.LOW_FEEDBACK_ARTICLES.METRIC', {
    score: item.score,
    votes: item.totalVotes,
  });
const formatUnansweredMetric = item =>
  t('HELP_CENTER.ARTICLES_PAGE.INSIGHTS.UNANSWERED_SEARCHES.METRIC', {
    count: item.noResultsCount,
  });

const openInsightArticle = articleId => {
  const { tab, categorySlug, locale } = route.params;
  router.push({
    name: 'portals_articles_edit',
    params: {
      articleSlug: articleId,
      tab,
      categorySlug,
      locale,
    },
  });
};

const navigateToNewArticlePage = () => {
  const { categorySlug, locale } = route.params;
  router.push({
    name: 'portals_articles_new',
    params: { categorySlug, locale },
  });
};
</script>

<template>
  <HelpCenterLayout
    :current-page="Number(meta.currentPage)"
    :total-items="articlesCount"
    :items-per-page="25"
    :header="portalName"
    :show-pagination-footer="shouldShowPaginationFooter"
    @update:current-page="handlePageChange"
  >
    <template #header-actions>
      <div class="flex items-end justify-between">
        <ArticleHeaderControls
          v-if="showArticleHeaderControls"
          :categories="categories"
          :allowed-locales="allowedLocales"
          :meta="meta"
          @tab-change="handleTabChange"
          @locale-change="handleLocaleAction"
          @category-change="handleCategoryAction"
          @new-article="navigateToNewArticlePage"
        />
        <CategoryHeaderControls
          v-else-if="showCategoryHeaderControls"
          :categories="categories"
          :allowed-locales="allowedLocales"
          :has-selected-category="isCategoryArticles"
        />
      </div>
    </template>
    <template #content>
      <div
        v-if="
          !isLoading && (feedbackInsights.length || unansweredSearches.length)
        "
        class="grid grid-cols-1 gap-3 mb-4 lg:grid-cols-2"
      >
        <section
          v-if="feedbackInsights.length"
          class="rounded-2xl border border-n-weak bg-n-alpha-2 p-4"
        >
          <p class="text-sm font-semibold text-n-slate-12">
            {{
              t(
                'HELP_CENTER.ARTICLES_PAGE.INSIGHTS.LOW_FEEDBACK_ARTICLES.TITLE'
              )
            }}
          </p>
          <p class="text-xs text-n-slate-11 mt-1">
            {{
              t(
                'HELP_CENTER.ARTICLES_PAGE.INSIGHTS.LOW_FEEDBACK_ARTICLES.SUBTITLE'
              )
            }}
          </p>
          <p class="text-xs text-n-slate-10 mt-1">{{ insightsScopeText }}</p>
          <ul class="mt-3 space-y-2">
            <li
              v-for="item in feedbackInsights"
              :key="item.id"
              class="flex items-center justify-between gap-2 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 hover:bg-n-alpha-2 transition-colors"
            >
              <button
                type="button"
                class="text-left min-w-0 flex-1"
                @click="openInsightArticle(item.id)"
              >
                <span class="block text-sm text-n-slate-12 truncate">
                  {{ item.title }}
                </span>
                <span class="block text-xs font-medium text-n-ruby-11 mt-0.5">
                  {{ formatFeedbackMetric(item) }}
                </span>
              </button>
              <button
                type="button"
                class="text-xs font-semibold text-n-brand shrink-0 hover:underline"
                @click="openInsightArticle(item.id)"
              >
                {{
                  t(
                    'HELP_CENTER.ARTICLES_PAGE.INSIGHTS.LOW_FEEDBACK_ARTICLES.OPEN_ARTICLE'
                  )
                }}
              </button>
            </li>
          </ul>
        </section>
        <section
          v-if="unansweredSearches.length"
          class="rounded-2xl border border-n-weak bg-n-alpha-2 p-4"
        >
          <p class="text-sm font-semibold text-n-slate-12">
            {{
              t('HELP_CENTER.ARTICLES_PAGE.INSIGHTS.UNANSWERED_SEARCHES.TITLE')
            }}
          </p>
          <p class="text-xs text-n-slate-11 mt-1">
            {{
              t(
                'HELP_CENTER.ARTICLES_PAGE.INSIGHTS.UNANSWERED_SEARCHES.SUBTITLE'
              )
            }}
          </p>
          <p class="text-xs text-n-slate-10 mt-1">{{ insightsScopeText }}</p>
          <ul class="mt-3 space-y-2">
            <li
              v-for="item in unansweredSearches"
              :key="item.query"
              class="flex items-center justify-between gap-2 rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2"
            >
              <span class="text-sm text-n-slate-12 truncate">
                {{ item.query }}
              </span>
              <span class="text-xs font-medium text-n-amber-11 shrink-0">
                {{ formatUnansweredMetric(item) }}
              </span>
            </li>
          </ul>
        </section>
      </div>
      <div
        v-if="isLoading"
        class="flex items-center justify-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>
      <ArticleList
        v-else-if="!hasNoArticles"
        :articles="articles"
        :is-category-articles="isCategoryArticles"
      />
      <ArticleEmptyState
        v-else
        class="pt-14"
        :title="getEmptyStateTitle"
        :subtitle="getEmptyStateSubtitle"
        :show-button="hasNoArticlesInPortal"
        :button-label="
          t('HELP_CENTER.ARTICLES_PAGE.EMPTY_STATE.ALL.BUTTON_LABEL')
        "
        @click="navigateToNewArticlePage"
      />
    </template>
  </HelpCenterLayout>
</template>
