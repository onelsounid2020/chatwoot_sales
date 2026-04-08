<script setup>
import { reactive, watch, computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { buildPortalURL } from 'dashboard/helper/portalHelper';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import { checkFileSizeLimit } from 'shared/helpers/FileHelper';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, helpers, url } from '@vuelidate/validators';
import { isValidSlug } from 'shared/helpers/Validators';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import ColorPicker from 'dashboard/components-next/colorpicker/ColorPicker.vue';

const props = defineProps({
  activePortal: {
    type: Object,
    required: true,
  },
  isFetching: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['updatePortal']);

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const MAXIMUM_FILE_UPLOAD_SIZE = 4; // in MB
const DEFAULT_THEME_COLORS = {
  headerBgColor: '#ffffff',
  headerTextColor: '#0f172a',
  homeBgColor: '#ffffff',
  articleBgColor: '#ffffff',
  articleTextColor: '#0f172a',
  articleTitleColor: '#0f172a',
  heroBgColor: '#f8fafc',
  heroTitleColor: '#0f172a',
  heroSubtitleColor: '#475569',
  cardBgColor: '#ffffff',
  cardBorderColor: '#e2e8f0',
  cardTitleColor: '#1e293b',
  cardTextColor: '#475569',
};
const THEME_PRESET_VALUES = {
  clean: {
    headerBgColor: '#ffffff',
    headerTextColor: '#0f172a',
    homeBgColor: '#ffffff',
    articleBgColor: '#ffffff',
    articleTextColor: '#0f172a',
    articleTitleColor: '#0f172a',
    heroBgColor: '#f8fafc',
    heroTitleColor: '#0f172a',
    heroSubtitleColor: '#475569',
    cardBgColor: '#ffffff',
    cardBorderColor: '#e2e8f0',
    cardTitleColor: '#1e293b',
    cardTextColor: '#475569',
  },
  ocean: {
    headerBgColor: '#ffffff',
    headerTextColor: '#0c4a6e',
    homeBgColor: '#f0f9ff',
    articleBgColor: '#ffffff',
    articleTextColor: '#0c4a6e',
    articleTitleColor: '#0c4a6e',
    heroBgColor: '#dbeafe',
    heroTitleColor: '#0c4a6e',
    heroSubtitleColor: '#155e75',
    cardBgColor: '#ffffff',
    cardBorderColor: '#bae6fd',
    cardTitleColor: '#0c4a6e',
    cardTextColor: '#0369a1',
  },
  sand: {
    headerBgColor: '#ffffff',
    headerTextColor: '#78350f',
    homeBgColor: '#fffbeb',
    articleBgColor: '#ffffff',
    articleTextColor: '#78350f',
    articleTitleColor: '#78350f',
    heroBgColor: '#fef3c7',
    heroTitleColor: '#78350f',
    heroSubtitleColor: '#92400e',
    cardBgColor: '#ffffff',
    cardBorderColor: '#fde68a',
    cardTitleColor: '#78350f',
    cardTextColor: '#92400e',
  },
  midnight: {
    headerBgColor: '#0b1220',
    headerTextColor: '#e2e8f0',
    homeBgColor: '#0f172a',
    articleBgColor: '#111827',
    articleTextColor: '#e5e7eb',
    articleTitleColor: '#f8fafc',
    heroBgColor: '#1e293b',
    heroTitleColor: '#f8fafc',
    heroSubtitleColor: '#cbd5e1',
    cardBgColor: '#0b1220',
    cardBorderColor: '#334155',
    cardTitleColor: '#f8fafc',
    cardTextColor: '#cbd5e1',
  },
  graphite: {
    headerBgColor: '#111111',
    headerTextColor: '#f3f4f6',
    homeBgColor: '#18181b',
    articleBgColor: '#1f1f23',
    articleTextColor: '#e4e4e7',
    articleTitleColor: '#fafafa',
    heroBgColor: '#27272a',
    heroTitleColor: '#fafafa',
    heroSubtitleColor: '#d4d4d8',
    cardBgColor: '#202024',
    cardBorderColor: '#3f3f46',
    cardTitleColor: '#fafafa',
    cardTextColor: '#d4d4d8',
  },
  sunset: {
    headerBgColor: '#3f1d2e',
    headerTextColor: '#fde68a',
    homeBgColor: '#fff7ed',
    articleBgColor: '#ffffff',
    articleTextColor: '#7c2d12',
    articleTitleColor: '#7c2d12',
    heroBgColor: '#7c2d12',
    heroTitleColor: '#fffbeb',
    heroSubtitleColor: '#fde68a',
    cardBgColor: '#ffffff',
    cardBorderColor: '#fdba74',
    cardTitleColor: '#7c2d12',
    cardTextColor: '#9a3412',
  },
};
const TYPOGRAPHY_PRESET_VALUES = ['modern', 'classic', 'reading'];
const CONTENT_WIDTH_VALUES = ['narrow', 'regular', 'wide'];
const DENSITY_MODE_VALUES = ['compact', 'comfortable'];
const CARD_STYLE_VALUES = ['soft', 'outlined', 'elevated'];
const TEXT_ALIGN_VALUES = ['left', 'center'];
const HEADER_STYLE_VALUES = ['solid', 'transparent'];
const VISUAL_TEMPLATE_VALUES = ['cognism', 'picsart', 'custom'];
const HOME_LAYOUT_MODE_VALUES = [
  'balanced',
  'categories_first',
  'featured_focus',
  'compact',
];
const ADVANCED_SECTION_SPACING_VALUES = ['compact', 'regular', 'relaxed'];
const ADVANCED_CARD_RADIUS_VALUES = ['sm', 'md', 'lg'];
const ADVANCED_SHADOW_STYLE_VALUES = ['none', 'soft', 'medium'];
const HERO_STYLE_VALUES = ['minimal', 'soft', 'spotlight'];
const CATEGORY_COLUMNS_VALUES = ['2', '3'];
const ARTICLE_LINK_STYLE_VALUES = ['boxed', 'minimal'];
const ARTICLE_TITLE_ALIGN_VALUES = ['left', 'center'];
const DESIGNER_PRESET_VALUES = [
  'balanced',
  'conversion',
  'editorial',
  'cognito_clean',
  'picsart_bold',
];
const VISUAL_TEMPLATE_PRESETS = {
  cognism: {
    widgetColor: '#1f2937',
    headerBgColor: '#ffffff',
    headerTextColor: '#1f2937',
    homeBgColor: '#f8fafc',
    articleBgColor: '#ffffff',
    articleTextColor: '#0f172a',
    articleTitleColor: '#0f172a',
    heroBgColor: '#e2e8f0',
    heroTitleColor: '#0f172a',
    heroSubtitleColor: '#475569',
    cardBgColor: '#ffffff',
    cardBorderColor: '#cbd5e1',
    cardTitleColor: '#0f172a',
    cardTextColor: '#475569',
    typographyPreset: 'modern',
    contentWidth: 'regular',
    densityMode: 'comfortable',
    cardStyle: 'outlined',
    textAlign: 'left',
    headerStyle: 'solid',
    homeLayoutMode: 'categories_first',
    advancedSectionSpacing: 'regular',
    advancedCardRadius: 'md',
    advancedShadowStyle: 'soft',
    heroStyle: 'soft',
    categoryColumns: '2',
    articleLinkStyle: 'boxed',
  },
  picsart: {
    widgetColor: '#7c3aed',
    headerBgColor: '#ffffff',
    headerTextColor: '#4c1d95',
    homeBgColor: '#f5f3ff',
    articleBgColor: '#ffffff',
    articleTextColor: '#312e81',
    articleTitleColor: '#312e81',
    heroBgColor: '#ede9fe',
    heroTitleColor: '#4c1d95',
    heroSubtitleColor: '#6d28d9',
    cardBgColor: '#ffffff',
    cardBorderColor: '#c4b5fd',
    cardTitleColor: '#5b21b6',
    cardTextColor: '#6d28d9',
    typographyPreset: 'modern',
    contentWidth: 'wide',
    densityMode: 'comfortable',
    cardStyle: 'elevated',
    textAlign: 'center',
    headerStyle: 'transparent',
    homeLayoutMode: 'featured_focus',
    advancedSectionSpacing: 'relaxed',
    advancedCardRadius: 'lg',
    advancedShadowStyle: 'medium',
    heroStyle: 'spotlight',
    categoryColumns: '3',
    articleLinkStyle: 'boxed',
  },
};

const state = reactive({
  name: '',
  headerText: '',
  pageTitle: '',
  slug: '',
  widgetColor: '',
  headerBgColor: '',
  headerTextColor: '',
  homeBgColor: '',
  articleBgColor: '',
  articleTextColor: '',
  articleTitleColor: '',
  heroBgColor: '',
  heroTitleColor: '',
  heroSubtitleColor: '',
  cardBgColor: '',
  cardBorderColor: '',
  cardTitleColor: '',
  cardTextColor: '',
  typographyPreset: '',
  contentWidth: '',
  densityMode: '',
  cardStyle: '',
  textAlign: '',
  headerStyle: '',
  visualTemplate: '',
  homeLayoutMode: '',
  advancedSectionSpacing: '',
  advancedCardRadius: '',
  advancedShadowStyle: '',
  heroStyle: '',
  categoryColumns: '',
  articleLinkStyle: '',
  articleTitleAlign: '',
  homePageLink: '',
  liveChatWidgetInboxId: '',
  logoUrl: '',
  avatarBlobId: '',
});

const originalState = reactive({ ...state });
const activeSettingsTab = ref('basic');
const selectedDesignerPreset = ref('');

const liveChatWidgets = computed(() => {
  const inboxes = store.getters['inboxes/getInboxes'];
  const widgetOptions = inboxes
    .filter(inbox => inbox.channel_type === 'Channel::WebWidget')
    .map(inbox => ({
      value: inbox.id,
      label: inbox.name,
    }));

  return [
    {
      value: '',
      label: t('HELP_CENTER.PORTAL_SETTINGS.FORM.LIVE_CHAT_WIDGET.NONE_OPTION'),
    },
    ...widgetOptions,
  ];
});
const themePresetOptions = computed(() => [
  {
    value: 'clean',
    label: t('HELP_CENTER.PORTAL_SETTINGS.FORM.THEME_PRESET.OPTIONS.CLEAN'),
  },
  {
    value: 'ocean',
    label: t('HELP_CENTER.PORTAL_SETTINGS.FORM.THEME_PRESET.OPTIONS.OCEAN'),
  },
  {
    value: 'sand',
    label: t('HELP_CENTER.PORTAL_SETTINGS.FORM.THEME_PRESET.OPTIONS.SAND'),
  },
  {
    value: 'midnight',
    label: t('HELP_CENTER.PORTAL_SETTINGS.FORM.THEME_PRESET.OPTIONS.MIDNIGHT'),
  },
  {
    value: 'graphite',
    label: t('HELP_CENTER.PORTAL_SETTINGS.FORM.THEME_PRESET.OPTIONS.GRAPHITE'),
  },
  {
    value: 'sunset',
    label: t('HELP_CENTER.PORTAL_SETTINGS.FORM.THEME_PRESET.OPTIONS.SUNSET'),
  },
]);
const typographyPresetOptions = computed(() =>
  TYPOGRAPHY_PRESET_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.TYPOGRAPHY_PRESET.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const contentWidthOptions = computed(() =>
  CONTENT_WIDTH_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.CONTENT_WIDTH.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const densityModeOptions = computed(() =>
  DENSITY_MODE_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.DENSITY_MODE.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const cardStyleOptions = computed(() =>
  CARD_STYLE_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_STYLE.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const textAlignOptions = computed(() =>
  TEXT_ALIGN_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.TEXT_ALIGN.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const headerStyleOptions = computed(() =>
  HEADER_STYLE_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.HEADER_STYLE.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const visualTemplateOptions = computed(() =>
  VISUAL_TEMPLATE_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.VISUAL_TEMPLATE.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const homeLayoutModeOptions = computed(() =>
  HOME_LAYOUT_MODE_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.HOME_LAYOUT_MODE.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const advancedSectionSpacingOptions = computed(() =>
  ADVANCED_SECTION_SPACING_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.ADVANCED_SECTION_SPACING.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const advancedCardRadiusOptions = computed(() =>
  ADVANCED_CARD_RADIUS_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.ADVANCED_CARD_RADIUS.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const advancedShadowStyleOptions = computed(() =>
  ADVANCED_SHADOW_STYLE_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.ADVANCED_SHADOW_STYLE.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const heroStyleOptions = computed(() =>
  HERO_STYLE_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_STYLE.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const categoryColumnsOptions = computed(() =>
  CATEGORY_COLUMNS_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.CATEGORY_COLUMNS.OPTIONS.${value}`
    ),
  }))
);
const articleLinkStyleOptions = computed(() =>
  ARTICLE_LINK_STYLE_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.ARTICLE_LINK_STYLE.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const articleTitleAlignOptions = computed(() =>
  ARTICLE_TITLE_ALIGN_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.ARTICLE_TITLE_ALIGN.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const designerPresetOptions = computed(() =>
  DESIGNER_PRESET_VALUES.map(value => ({
    value,
    label: t(
      `HELP_CENTER.PORTAL_SETTINGS.FORM.DESIGNER_PRESET.OPTIONS.${value.toUpperCase()}`
    ),
  }))
);
const previewTypographyClass = computed(() => {
  const typographyMap = {
    modern: 'font-sans',
    classic: 'font-serif',
    reading: 'font-serif',
  };

  return typographyMap[state.typographyPreset] || 'font-sans';
});
const previewWidthClass = computed(() => {
  const widthMap = {
    narrow: 'max-w-xl',
    regular: 'max-w-3xl',
    wide: 'max-w-5xl',
  };

  return widthMap[state.contentWidth] || 'max-w-3xl';
});
const previewDensityClasses = computed(() => {
  const isCompact = state.densityMode === 'compact';
  return {
    cardPadding: isCompact ? 'p-3' : 'p-5',
    itemPadding: isCompact ? 'py-1' : 'py-2',
    spacing: isCompact ? 'space-y-2' : 'space-y-3',
  };
});
const previewCardStyleClass = computed(() => {
  const styleMap = {
    soft: 'border border-n-weak bg-n-alpha-2 shadow-none rounded-lg',
    outlined: 'border-2 border-n-strong bg-n-solid-1 shadow-none rounded-lg',
    elevated: 'border border-n-weak bg-n-solid-1 shadow-md rounded-xl',
  };
  return styleMap[state.cardStyle] || styleMap.soft;
});
const previewTextAlignClass = computed(() =>
  state.textAlign === 'center'
    ? 'text-center items-center'
    : 'text-left items-start'
);
const colorPreviewLabel = (labelKey, value) =>
  `${t(labelKey)}: ${value || '-'}`;

const rules = {
  name: { required, minLength: minLength(2) },
  slug: {
    required: helpers.withMessage(
      () => t('HELP_CENTER.CREATE_PORTAL_DIALOG.SLUG.ERROR'),
      required
    ),
    isValidSlug: helpers.withMessage(
      () => t('HELP_CENTER.CREATE_PORTAL_DIALOG.SLUG.FORMAT_ERROR'),
      isValidSlug
    ),
  },
  homePageLink: { url },
};

const v$ = useVuelidate(rules, state);

const nameError = computed(() =>
  v$.value.name.$error ? t('HELP_CENTER.CREATE_PORTAL_DIALOG.NAME.ERROR') : ''
);

const slugError = computed(() => {
  return v$.value.slug.$errors[0]?.$message || '';
});

const homePageLinkError = computed(() =>
  v$.value.homePageLink.$error
    ? t('HELP_CENTER.PORTAL_SETTINGS.FORM.HOME_PAGE_LINK.ERROR')
    : ''
);

const isUpdatingPortal = computed(() => {
  const slug = props.activePortal?.slug;
  if (slug) return getters['portals/uiFlagsIn'].value(slug)?.isUpdating;

  return false;
});

watch(
  () => props.activePortal,
  newVal => {
    if (newVal && !props.isFetching) {
      Object.assign(state, {
        name: newVal.name,
        headerText: newVal.header_text,
        pageTitle: newVal.page_title,
        widgetColor: newVal.color,
        headerBgColor: newVal.header_bg_color || '#ffffff',
        headerTextColor: newVal.header_text_color || '#0f172a',
        homeBgColor: newVal.home_bg_color || '#ffffff',
        articleBgColor: newVal.article_bg_color || '#ffffff',
        articleTextColor: newVal.article_text_color || '#0f172a',
        articleTitleColor: newVal.article_title_color || '#0f172a',
        heroBgColor: newVal.hero_bg_color || '#f8fafc',
        heroTitleColor: newVal.hero_title_color || '#0f172a',
        heroSubtitleColor: newVal.hero_subtitle_color || '#475569',
        cardBgColor: newVal.card_bg_color || '#ffffff',
        cardBorderColor: newVal.card_border_color || '#e2e8f0',
        cardTitleColor: newVal.card_title_color || '#1e293b',
        cardTextColor: newVal.card_text_color || '#475569',
        typographyPreset: newVal.typography_preset || 'modern',
        contentWidth: newVal.content_width || 'regular',
        densityMode: newVal.density_mode || 'comfortable',
        cardStyle: newVal.card_style || 'soft',
        textAlign: newVal.text_align || 'left',
        headerStyle: newVal.header_style || 'solid',
        visualTemplate: newVal.visual_template || 'custom',
        homeLayoutMode: newVal.home_layout_mode || 'balanced',
        advancedSectionSpacing: newVal.advanced_section_spacing || 'regular',
        advancedCardRadius: newVal.advanced_card_radius || 'md',
        advancedShadowStyle: newVal.advanced_shadow_style || 'soft',
        heroStyle: newVal.hero_style || 'soft',
        categoryColumns: newVal.category_columns || '2',
        articleLinkStyle: newVal.article_link_style || 'boxed',
        articleTitleAlign: newVal.article_title_align || 'left',
        homePageLink: newVal.homepage_link,
        slug: newVal.slug,
        liveChatWidgetInboxId: newVal.inbox?.id || '',
      });
      if (newVal.logo) {
        const {
          logo: { file_url: logoURL, blob_id: blobId },
        } = newVal;
        state.logoUrl = logoURL;
        state.avatarBlobId = blobId;
      } else {
        state.logoUrl = '';
        state.avatarBlobId = '';
      }
      Object.assign(originalState, state);
    }
  },
  { immediate: true, deep: true }
);

const hasChanges = computed(() => {
  return JSON.stringify(state) !== JSON.stringify(originalState);
});

const handleUpdatePortal = () => {
  const portal = {
    id: props.activePortal?.id,
    slug: state.slug,
    name: state.name,
    color: state.widgetColor,
    page_title: state.pageTitle,
    header_text: state.headerText,
    homepage_link: state.homePageLink,
    header_bg_color: state.headerBgColor,
    header_text_color: state.headerTextColor,
    home_bg_color: state.homeBgColor,
    article_bg_color: state.articleBgColor,
    article_text_color: state.articleTextColor,
    article_title_color: state.articleTitleColor,
    hero_bg_color: state.heroBgColor,
    hero_title_color: state.heroTitleColor,
    hero_subtitle_color: state.heroSubtitleColor,
    card_bg_color: state.cardBgColor,
    card_border_color: state.cardBorderColor,
    card_title_color: state.cardTitleColor,
    card_text_color: state.cardTextColor,
    typography_preset: state.typographyPreset,
    content_width: state.contentWidth,
    density_mode: state.densityMode,
    card_style: state.cardStyle,
    text_align: state.textAlign,
    header_style: state.headerStyle || 'solid',
    visual_template: state.visualTemplate || 'custom',
    home_layout_mode: state.homeLayoutMode || 'balanced',
    advanced_section_spacing: state.advancedSectionSpacing || 'regular',
    advanced_card_radius: state.advancedCardRadius || 'md',
    advanced_shadow_style: state.advancedShadowStyle || 'soft',
    hero_style: state.heroStyle || 'soft',
    category_columns: state.categoryColumns || '2',
    article_link_style: state.articleLinkStyle || 'boxed',
    article_title_align: state.articleTitleAlign || 'left',
    blob_id: state.avatarBlobId,
    inbox_id: state.liveChatWidgetInboxId,
  };
  emit('updatePortal', portal);
};

async function uploadLogoToStorage({ file }) {
  try {
    const { fileUrl, blobId } = await uploadFile(file);
    if (fileUrl) {
      state.logoUrl = fileUrl;
      state.avatarBlobId = blobId;
    }
    useAlert(t('HELP_CENTER.PORTAL_SETTINGS.FORM.AVATAR.IMAGE_UPLOAD_SUCCESS'));
  } catch (error) {
    useAlert(t('HELP_CENTER.PORTAL_SETTINGS.FORM.AVATAR.IMAGE_UPLOAD_ERROR'));
  }
}

async function deleteLogo() {
  try {
    const portalSlug = props.activePortal?.slug;
    await store.dispatch('portals/deleteLogo', {
      portalSlug,
    });
    useAlert(t('HELP_CENTER.PORTAL_SETTINGS.FORM.AVATAR.IMAGE_DELETE_SUCCESS'));
  } catch (error) {
    useAlert(
      error?.message ||
        t('HELP_CENTER.PORTAL_SETTINGS.FORM.AVATAR.IMAGE_DELETE_ERROR')
    );
  }
}

const handleAvatarUpload = file => {
  if (checkFileSizeLimit(file, MAXIMUM_FILE_UPLOAD_SIZE)) {
    uploadLogoToStorage(file);
  } else {
    const errorKey =
      'HELP_CENTER.PORTAL_SETTINGS.FORM.AVATAR.IMAGE_UPLOAD_SIZE_ERROR';
    useAlert(t(errorKey, { size: MAXIMUM_FILE_UPLOAD_SIZE }));
  }
};

const handleAvatarDelete = () => {
  state.logoUrl = '';
  state.avatarBlobId = '';
  deleteLogo();
};

const applyThemePreset = preset => {
  const presetValues = THEME_PRESET_VALUES[preset];
  if (!presetValues) return;
  state.visualTemplate = 'custom';

  state.homeBgColor = presetValues.homeBgColor;
  state.headerBgColor = presetValues.headerBgColor;
  state.headerTextColor = presetValues.headerTextColor;
  state.articleBgColor = presetValues.articleBgColor;
  state.articleTextColor = presetValues.articleTextColor;
  state.articleTitleColor = presetValues.articleTitleColor;
  state.heroBgColor = presetValues.heroBgColor;
  state.heroTitleColor = presetValues.heroTitleColor;
  state.heroSubtitleColor = presetValues.heroSubtitleColor;
  state.cardBgColor = presetValues.cardBgColor;
  state.cardBorderColor = presetValues.cardBorderColor;
  state.cardTitleColor = presetValues.cardTitleColor;
  state.cardTextColor = presetValues.cardTextColor;
};

const resetThemeColors = () => {
  state.homeBgColor = DEFAULT_THEME_COLORS.homeBgColor;
  state.headerBgColor = DEFAULT_THEME_COLORS.headerBgColor;
  state.headerTextColor = DEFAULT_THEME_COLORS.headerTextColor;
  state.articleBgColor = DEFAULT_THEME_COLORS.articleBgColor;
  state.articleTextColor = DEFAULT_THEME_COLORS.articleTextColor;
  state.articleTitleColor = DEFAULT_THEME_COLORS.articleTitleColor;
  state.heroBgColor = DEFAULT_THEME_COLORS.heroBgColor;
  state.heroTitleColor = DEFAULT_THEME_COLORS.heroTitleColor;
  state.heroSubtitleColor = DEFAULT_THEME_COLORS.heroSubtitleColor;
  state.cardBgColor = DEFAULT_THEME_COLORS.cardBgColor;
  state.cardBorderColor = DEFAULT_THEME_COLORS.cardBorderColor;
  state.cardTitleColor = DEFAULT_THEME_COLORS.cardTitleColor;
  state.cardTextColor = DEFAULT_THEME_COLORS.cardTextColor;
  state.visualTemplate = 'custom';
};

const applyVisualTemplate = template => {
  state.visualTemplate = template;
  if (template === 'custom') return;

  const preset = VISUAL_TEMPLATE_PRESETS[template];
  if (!preset) return;

  state.widgetColor = preset.widgetColor;
  state.headerBgColor = preset.headerBgColor;
  state.headerTextColor = preset.headerTextColor;
  state.homeBgColor = preset.homeBgColor;
  state.articleBgColor = preset.articleBgColor;
  state.articleTextColor = preset.articleTextColor;
  state.articleTitleColor = preset.articleTitleColor;
  state.heroBgColor = preset.heroBgColor;
  state.heroTitleColor = preset.heroTitleColor;
  state.heroSubtitleColor = preset.heroSubtitleColor;
  state.cardBgColor = preset.cardBgColor;
  state.cardBorderColor = preset.cardBorderColor;
  state.cardTitleColor = preset.cardTitleColor;
  state.cardTextColor = preset.cardTextColor;
  state.typographyPreset = preset.typographyPreset;
  state.contentWidth = preset.contentWidth;
  state.densityMode = preset.densityMode;
  state.cardStyle = preset.cardStyle;
  state.textAlign = preset.textAlign;
  state.headerStyle = preset.headerStyle || 'solid';
  state.homeLayoutMode = preset.homeLayoutMode || 'balanced';
  state.advancedSectionSpacing = preset.advancedSectionSpacing || 'regular';
  state.advancedCardRadius = preset.advancedCardRadius || 'md';
  state.advancedShadowStyle = preset.advancedShadowStyle || 'soft';
  state.heroStyle = preset.heroStyle || 'soft';
  state.categoryColumns = preset.categoryColumns || '2';
  state.articleLinkStyle = preset.articleLinkStyle || 'boxed';
  state.articleTitleAlign = preset.textAlign || 'left';
};

const applyDesignerPreset = preset => {
  selectedDesignerPreset.value = preset;
  state.visualTemplate = 'custom';

  if (preset === 'cognito_clean') {
    state.widgetColor = '#1f2937';
    state.headerBgColor = '#ffffff';
    state.headerTextColor = '#1f2937';
    state.homeBgColor = '#f8fafc';
    state.articleBgColor = '#ffffff';
    state.articleTextColor = '#0f172a';
    state.articleTitleColor = '#0f172a';
    state.heroBgColor = '#e2e8f0';
    state.heroTitleColor = '#0f172a';
    state.heroSubtitleColor = '#475569';
    state.cardBgColor = '#ffffff';
    state.cardBorderColor = '#cbd5e1';
    state.cardTitleColor = '#0f172a';
    state.cardTextColor = '#475569';
    state.heroStyle = 'soft';
    state.categoryColumns = '2';
    state.articleLinkStyle = 'boxed';
    state.contentWidth = 'regular';
    state.densityMode = 'comfortable';
    state.cardStyle = 'outlined';
    state.textAlign = 'left';
    state.headerStyle = 'solid';
    state.homeLayoutMode = 'categories_first';
    state.advancedSectionSpacing = 'regular';
    state.advancedCardRadius = 'md';
    state.advancedShadowStyle = 'soft';
    state.articleTitleAlign = 'left';
    return;
  }

  if (preset === 'picsart_bold') {
    state.widgetColor = '#7c3aed';
    state.headerBgColor = '#ffffff';
    state.headerTextColor = '#4c1d95';
    state.homeBgColor = '#f5f3ff';
    state.articleBgColor = '#ffffff';
    state.articleTextColor = '#312e81';
    state.articleTitleColor = '#312e81';
    state.heroBgColor = '#ede9fe';
    state.heroTitleColor = '#4c1d95';
    state.heroSubtitleColor = '#6d28d9';
    state.cardBgColor = '#ffffff';
    state.cardBorderColor = '#c4b5fd';
    state.cardTitleColor = '#5b21b6';
    state.cardTextColor = '#6d28d9';
    state.heroStyle = 'spotlight';
    state.categoryColumns = '3';
    state.articleLinkStyle = 'boxed';
    state.contentWidth = 'wide';
    state.densityMode = 'comfortable';
    state.cardStyle = 'elevated';
    state.textAlign = 'center';
    state.headerStyle = 'transparent';
    state.homeLayoutMode = 'featured_focus';
    state.advancedSectionSpacing = 'relaxed';
    state.advancedCardRadius = 'lg';
    state.advancedShadowStyle = 'medium';
    state.articleTitleAlign = 'center';
    return;
  }

  if (preset === 'conversion') {
    state.heroStyle = 'spotlight';
    state.categoryColumns = '3';
    state.articleLinkStyle = 'boxed';
    state.contentWidth = 'wide';
    state.densityMode = 'comfortable';
    state.cardStyle = 'elevated';
    state.textAlign = 'center';
    state.headerStyle = 'transparent';
    state.homeLayoutMode = 'featured_focus';
    state.advancedSectionSpacing = 'relaxed';
    state.advancedCardRadius = 'lg';
    state.advancedShadowStyle = 'medium';
    state.articleTitleAlign = 'center';
    return;
  }

  if (preset === 'editorial') {
    state.heroStyle = 'minimal';
    state.categoryColumns = '2';
    state.articleLinkStyle = 'minimal';
    state.contentWidth = 'narrow';
    state.densityMode = 'compact';
    state.cardStyle = 'soft';
    state.textAlign = 'left';
    state.headerStyle = 'solid';
    state.homeLayoutMode = 'categories_first';
    state.advancedSectionSpacing = 'compact';
    state.advancedCardRadius = 'sm';
    state.advancedShadowStyle = 'none';
    state.articleTitleAlign = 'left';
    return;
  }

  state.heroStyle = 'soft';
  state.categoryColumns = '2';
  state.articleLinkStyle = 'boxed';
  state.contentWidth = 'regular';
  state.densityMode = 'comfortable';
  state.cardStyle = 'outlined';
  state.textAlign = 'left';
  state.headerStyle = 'solid';
  state.homeLayoutMode = 'balanced';
  state.advancedSectionSpacing = 'regular';
  state.advancedCardRadius = 'md';
  state.advancedShadowStyle = 'soft';
  state.articleTitleAlign = 'left';
};
</script>

<template>
  <div class="flex flex-col w-full gap-4">
    <div class="flex flex-col w-full gap-2">
      <label class="mb-0.5 text-sm font-medium text-gray-900 dark:text-gray-50">
        {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.AVATAR.LABEL') }}
      </label>
      <Avatar
        :src="state.logoUrl"
        :name="state.name"
        :size="72"
        allow-upload
        icon-name="i-lucide-building-2"
        @upload="handleAvatarUpload"
        @delete="handleAvatarDelete"
      />
    </div>
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="inline-flex items-center rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors"
        :class="
          activeSettingsTab === 'basic'
            ? 'border-n-brand bg-n-brand/10 text-n-brand'
            : 'border-n-weak bg-n-solid-1 text-n-slate-11 hover:bg-n-alpha-2'
        "
        @click="activeSettingsTab = 'basic'"
      >
        {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.TABS.BASIC') }}
      </button>
      <button
        type="button"
        class="inline-flex items-center rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors"
        :class="
          activeSettingsTab === 'articles'
            ? 'border-n-brand bg-n-brand/10 text-n-brand'
            : 'border-n-weak bg-n-solid-1 text-n-slate-11 hover:bg-n-alpha-2'
        "
        @click="activeSettingsTab = 'articles'"
      >
        {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.TABS.ARTICLES') }}
      </button>
      <button
        type="button"
        class="inline-flex items-center rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors"
        :class="
          activeSettingsTab === 'advanced'
            ? 'border-n-brand bg-n-brand/10 text-n-brand'
            : 'border-n-weak bg-n-solid-1 text-n-slate-11 hover:bg-n-alpha-2'
        "
        @click="activeSettingsTab = 'advanced'"
      >
        {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.TABS.ADVANCED') }}
      </button>
      <button
        type="button"
        class="inline-flex items-center rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors"
        :class="
          activeSettingsTab === 'designer'
            ? 'border-n-brand bg-n-brand/10 text-n-brand'
            : 'border-n-weak bg-n-solid-1 text-n-slate-11 hover:bg-n-alpha-2'
        "
        @click="activeSettingsTab = 'designer'"
      >
        {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.TABS.DESIGNER') }}
      </button>
    </div>
    <div
      class="grid w-full gap-4 xl:grid-cols-[minmax(0,1fr),20rem] 2xl:grid-cols-[minmax(0,1fr),22rem] xl:items-start"
    >
      <div
        v-show="activeSettingsTab === 'basic'"
        class="flex flex-col w-full gap-4"
      >
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.THEME_PRESET.LABEL') }}
          </label>
          <div class="flex items-center gap-2">
            <div class="w-full max-w-[320px]">
              <ComboBox
                :options="themePresetOptions"
                :placeholder="
                  t('HELP_CENTER.PORTAL_SETTINGS.FORM.THEME_PRESET.PLACEHOLDER')
                "
                @update:model-value="applyThemePreset"
              />
            </div>
            <Button
              color="slate"
              :label="t('HELP_CENTER.PORTAL_SETTINGS.FORM.THEME_PRESET.RESET')"
              @click="resetThemeColors"
            />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.HOME_LAYOUT_MODE.LABEL') }}
          </label>
          <div class="w-full max-w-[320px]">
            <ComboBox
              v-model="state.homeLayoutMode"
              :options="homeLayoutModeOptions"
              :placeholder="
                t(
                  'HELP_CENTER.PORTAL_SETTINGS.FORM.HOME_LAYOUT_MODE.PLACEHOLDER'
                )
              "
              class="[&>div>button:not(.focused)]:!outline-n-weak"
            />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.VISUAL_TEMPLATE.LABEL') }}
          </label>
          <div class="w-full max-w-[320px]">
            <ComboBox
              v-model="state.visualTemplate"
              :options="visualTemplateOptions"
              :placeholder="
                t(
                  'HELP_CENTER.PORTAL_SETTINGS.FORM.VISUAL_TEMPLATE.PLACEHOLDER'
                )
              "
              class="[&>div>button:not(.focused)]:!outline-n-weak"
              @update:model-value="applyVisualTemplate"
            />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.TYPOGRAPHY_PRESET.LABEL') }}
          </label>
          <div class="w-full max-w-[320px]">
            <ComboBox
              v-model="state.typographyPreset"
              :options="typographyPresetOptions"
              :placeholder="
                t(
                  'HELP_CENTER.PORTAL_SETTINGS.FORM.TYPOGRAPHY_PRESET.PLACEHOLDER'
                )
              "
              class="[&>div>button:not(.focused)]:!outline-n-weak"
            />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_STYLE.LABEL') }}
          </label>
          <div class="w-full max-w-[320px]">
            <ComboBox
              v-model="state.cardStyle"
              :options="cardStyleOptions"
              :placeholder="
                t('HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_STYLE.PLACEHOLDER')
              "
              class="[&>div>button:not(.focused)]:!outline-n-weak"
            />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.TEXT_ALIGN.LABEL') }}
          </label>
          <div class="w-full max-w-[320px]">
            <ComboBox
              v-model="state.textAlign"
              :options="textAlignOptions"
              :placeholder="
                t('HELP_CENTER.PORTAL_SETTINGS.FORM.TEXT_ALIGN.PLACEHOLDER')
              "
              class="[&>div>button:not(.focused)]:!outline-n-weak"
            />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.CONTENT_WIDTH.LABEL') }}
          </label>
          <div class="w-full max-w-[320px]">
            <ComboBox
              v-model="state.contentWidth"
              :options="contentWidthOptions"
              :placeholder="
                t('HELP_CENTER.PORTAL_SETTINGS.FORM.CONTENT_WIDTH.PLACEHOLDER')
              "
              class="[&>div>button:not(.focused)]:!outline-n-weak"
            />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.DENSITY_MODE.LABEL') }}
          </label>
          <div class="w-full max-w-[320px]">
            <ComboBox
              v-model="state.densityMode"
              :options="densityModeOptions"
              :placeholder="
                t('HELP_CENTER.PORTAL_SETTINGS.FORM.DENSITY_MODE.PLACEHOLDER')
              "
              class="[&>div>button:not(.focused)]:!outline-n-weak"
            />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.NAME.LABEL') }}
          </label>
          <Input
            v-model="state.name"
            :placeholder="
              t('HELP_CENTER.PORTAL_SETTINGS.FORM.NAME.PLACEHOLDER')
            "
            :message-type="nameError ? 'error' : 'info'"
            :message="nameError"
            custom-input-class="!bg-transparent dark:!bg-transparent"
            @input="v$.name.$touch()"
            @blur="v$.name.$touch()"
          />
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.HEADER_TEXT.LABEL') }}
          </label>
          <Input
            v-model="state.headerText"
            :placeholder="
              t('HELP_CENTER.PORTAL_SETTINGS.FORM.HEADER_TEXT.PLACEHOLDER')
            "
            custom-input-class="!bg-transparent dark:!bg-transparent"
          />
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap text-n-slate-12 py-2.5"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.PAGE_TITLE.LABEL') }}
          </label>
          <Input
            v-model="state.pageTitle"
            :placeholder="
              t('HELP_CENTER.PORTAL_SETTINGS.FORM.PAGE_TITLE.PLACEHOLDER')
            "
            custom-input-class="!bg-transparent dark:!bg-transparent"
          />
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap text-n-slate-12 py-2.5"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.HOME_PAGE_LINK.LABEL') }}
          </label>
          <Input
            v-model="state.homePageLink"
            :placeholder="
              t('HELP_CENTER.PORTAL_SETTINGS.FORM.HOME_PAGE_LINK.PLACEHOLDER')
            "
            :message-type="homePageLinkError ? 'error' : 'info'"
            :message="homePageLinkError"
            custom-input-class="!bg-transparent dark:!bg-transparent"
            @input="v$.homePageLink.$touch()"
            @blur="v$.homePageLink.$touch()"
          />
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.SLUG.LABEL') }}
          </label>
          <Input
            v-model="state.slug"
            :placeholder="
              t('HELP_CENTER.PORTAL_SETTINGS.FORM.SLUG.PLACEHOLDER')
            "
            :message-type="slugError ? 'error' : 'info'"
            :message="slugError || buildPortalURL(state.slug)"
            custom-input-class="!bg-transparent dark:!bg-transparent"
            @input="v$.slug.$touch()"
            @blur="v$.slug.$touch()"
          />
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.LIVE_CHAT_WIDGET.LABEL') }}
          </label>
          <ComboBox
            v-model="state.liveChatWidgetInboxId"
            :options="liveChatWidgets"
            :placeholder="
              t('HELP_CENTER.PORTAL_SETTINGS.FORM.LIVE_CHAT_WIDGET.PLACEHOLDER')
            "
            :message="
              t('HELP_CENTER.PORTAL_SETTINGS.FORM.LIVE_CHAT_WIDGET.HELP_TEXT')
            "
            class="[&>div>button:not(.focused)]:!outline-n-weak"
          />
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.BRAND_COLOR.LABEL') }}
          </label>
          <div class="w-full max-w-[432px] justify-start">
            <ColorPicker v-model="state.widgetColor" />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.HEADER_BG_COLOR.LABEL') }}
          </label>
          <div class="w-full max-w-[432px] justify-start">
            <ColorPicker v-model="state.headerBgColor" />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.HEADER_TEXT_COLOR.LABEL') }}
          </label>
          <div class="w-full max-w-[432px] justify-start">
            <ColorPicker v-model="state.headerTextColor" />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.HOME_BG_COLOR.LABEL') }}
          </label>
          <div class="w-full max-w-[432px] justify-start">
            <ColorPicker v-model="state.homeBgColor" />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_BG_COLOR.LABEL') }}
          </label>
          <div class="w-full max-w-[432px] justify-start">
            <ColorPicker v-model="state.heroBgColor" />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_TITLE_COLOR.LABEL') }}
          </label>
          <div class="w-full max-w-[432px] justify-start">
            <ColorPicker v-model="state.heroTitleColor" />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{
              t('HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_SUBTITLE_COLOR.LABEL')
            }}
          </label>
          <div class="w-full max-w-[432px] justify-start">
            <ColorPicker v-model="state.heroSubtitleColor" />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_BG_COLOR.LABEL') }}
          </label>
          <div class="w-full max-w-[432px] justify-start">
            <ColorPicker v-model="state.cardBgColor" />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_BORDER_COLOR.LABEL') }}
          </label>
          <div class="w-full max-w-[432px] justify-start">
            <ColorPicker v-model="state.cardBorderColor" />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_TITLE_COLOR.LABEL') }}
          </label>
          <div class="w-full max-w-[432px] justify-start">
            <ColorPicker v-model="state.cardTitleColor" />
          </div>
        </div>
        <div
          class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
        >
          <label
            class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
          >
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_TEXT_COLOR.LABEL') }}
          </label>
          <div class="w-full max-w-[432px] justify-start">
            <ColorPicker v-model="state.cardTextColor" />
          </div>
        </div>
        <div class="w-full pt-2 xl:hidden">
          <div class="flex flex-col gap-3">
            <p class="text-sm font-medium text-n-slate-12">
              {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.LABEL') }}
            </p>
            <div class="rounded-xl border border-n-weak bg-n-alpha-2 p-3">
              <div
                class="mx-auto rounded-xl border border-n-weak bg-n-solid-1"
                :class="[
                  previewWidthClass,
                  previewTypographyClass,
                  previewDensityClasses.cardPadding,
                  previewTextAlignClass,
                ]"
              >
                <div class="mb-2">
                  <h4 class="text-base font-semibold text-n-slate-12">
                    {{
                      t(
                        'HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.HERO_TITLE_SAMPLE'
                      )
                    }}
                  </h4>
                  <p class="text-sm text-n-slate-11">
                    {{
                      t(
                        'HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.HERO_SUBTITLE_SAMPLE'
                      )
                    }}
                  </p>
                </div>
                <div class="space-y-2">
                  <div
                    class="px-3"
                    :class="[
                      previewDensityClasses.itemPadding,
                      previewCardStyleClass,
                      state.textAlign === 'center'
                        ? 'text-center'
                        : 'text-left',
                    ]"
                  >
                    <p class="text-sm font-medium text-n-slate-12">
                      {{
                        t(
                          'HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.CARD_TITLE_SAMPLE'
                        )
                      }}
                    </p>
                    <p class="text-xs text-n-slate-11">
                      {{
                        t(
                          'HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.CARD_TEXT_SAMPLE'
                        )
                      }}
                    </p>
                  </div>
                </div>
              </div>
              <div class="grid grid-cols-1 gap-2 mt-3 md:grid-cols-2">
                <div class="rounded-lg border border-n-weak bg-n-solid-1 p-2">
                  <p class="text-xs font-medium text-n-slate-12">
                    {{
                      t('HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.HERO_COLORS')
                    }}
                  </p>
                  <p class="mt-1 text-xs text-n-slate-11">
                    {{
                      colorPreviewLabel(
                        'HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_BG_COLOR.LABEL',
                        state.heroBgColor
                      )
                    }}
                  </p>
                  <p class="text-xs text-n-slate-11">
                    {{
                      colorPreviewLabel(
                        'HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_TITLE_COLOR.LABEL',
                        state.heroTitleColor
                      )
                    }}
                  </p>
                  <p class="text-xs text-n-slate-11">
                    {{
                      colorPreviewLabel(
                        'HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_SUBTITLE_COLOR.LABEL',
                        state.heroSubtitleColor
                      )
                    }}
                  </p>
                </div>
                <div class="rounded-lg border border-n-weak bg-n-solid-1 p-2">
                  <p class="text-xs font-medium text-n-slate-12">
                    {{
                      t('HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.CARD_COLORS')
                    }}
                  </p>
                  <p class="mt-1 text-xs text-n-slate-11">
                    {{
                      colorPreviewLabel(
                        'HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_BG_COLOR.LABEL',
                        state.cardBgColor
                      )
                    }}
                  </p>
                  <p class="text-xs text-n-slate-11">
                    {{
                      colorPreviewLabel(
                        'HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_BORDER_COLOR.LABEL',
                        state.cardBorderColor
                      )
                    }}
                  </p>
                  <p class="text-xs text-n-slate-11">
                    {{
                      colorPreviewLabel(
                        'HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_TITLE_COLOR.LABEL',
                        state.cardTitleColor
                      )
                    }}
                  </p>
                  <p class="text-xs text-n-slate-11">
                    {{
                      colorPreviewLabel(
                        'HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_TEXT_COLOR.LABEL',
                        state.cardTextColor
                      )
                    }}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div class="flex justify-end w-full gap-2">
          <Button
            :label="t('HELP_CENTER.PORTAL_SETTINGS.FORM.SAVE_CHANGES')"
            :disabled="!hasChanges || isUpdatingPortal || v$.$invalid"
            :is-loading="isUpdatingPortal"
            @click="handleUpdatePortal"
          />
        </div>
      </div>
      <div
        v-show="activeSettingsTab === 'articles'"
        class="flex flex-col w-full gap-4"
      >
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <p class="text-sm text-n-slate-11 mb-4">
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.ARTICLES_DESCRIPTION') }}
          </p>
          <div class="space-y-4">
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{
                  t('HELP_CENTER.PORTAL_SETTINGS.FORM.ARTICLE_BG_COLOR.LABEL')
                }}
              </label>
              <div class="w-full max-w-[432px] justify-start">
                <ColorPicker v-model="state.articleBgColor" />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{
                  t('HELP_CENTER.PORTAL_SETTINGS.FORM.ARTICLE_TEXT_COLOR.LABEL')
                }}
              </label>
              <div class="w-full max-w-[432px] justify-start">
                <ColorPicker v-model="state.articleTextColor" />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{
                  t(
                    'HELP_CENTER.PORTAL_SETTINGS.FORM.ARTICLE_TITLE_COLOR.LABEL'
                  )
                }}
              </label>
              <div class="w-full max-w-[432px] justify-start">
                <ColorPicker v-model="state.articleTitleColor" />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{
                  t(
                    'HELP_CENTER.PORTAL_SETTINGS.FORM.ARTICLE_TITLE_ALIGN.LABEL'
                  )
                }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.articleTitleAlign"
                  :options="articleTitleAlignOptions"
                  :placeholder="
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.ARTICLE_TITLE_ALIGN.PLACEHOLDER'
                    )
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{
                  t('HELP_CENTER.PORTAL_SETTINGS.FORM.TYPOGRAPHY_PRESET.LABEL')
                }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.typographyPreset"
                  :options="typographyPresetOptions"
                  :placeholder="
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.TYPOGRAPHY_PRESET.PLACEHOLDER'
                    )
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.CONTENT_WIDTH.LABEL') }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.contentWidth"
                  :options="contentWidthOptions"
                  :placeholder="
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.CONTENT_WIDTH.PLACEHOLDER'
                    )
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.DENSITY_MODE.LABEL') }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.densityMode"
                  :options="densityModeOptions"
                  :placeholder="
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.DENSITY_MODE.PLACEHOLDER'
                    )
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.TEXT_ALIGN.LABEL') }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.textAlign"
                  :options="textAlignOptions"
                  :placeholder="
                    t('HELP_CENTER.PORTAL_SETTINGS.FORM.TEXT_ALIGN.PLACEHOLDER')
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
          </div>
        </div>
        <div class="flex justify-end w-full gap-2">
          <Button
            :label="t('HELP_CENTER.PORTAL_SETTINGS.FORM.SAVE_CHANGES')"
            :disabled="!hasChanges || isUpdatingPortal || v$.$invalid"
            :is-loading="isUpdatingPortal"
            @click="handleUpdatePortal"
          />
        </div>
      </div>
      <div
        v-show="activeSettingsTab === 'advanced'"
        class="flex flex-col w-full gap-4"
      >
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <p class="text-sm text-n-slate-11 mb-4">
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.ADVANCED_DESCRIPTION') }}
          </p>
          <div class="space-y-4">
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{
                  t(
                    'HELP_CENTER.PORTAL_SETTINGS.FORM.ADVANCED_SECTION_SPACING.LABEL'
                  )
                }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.advancedSectionSpacing"
                  :options="advancedSectionSpacingOptions"
                  :placeholder="
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.ADVANCED_SECTION_SPACING.PLACEHOLDER'
                    )
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{
                  t(
                    'HELP_CENTER.PORTAL_SETTINGS.FORM.ADVANCED_CARD_RADIUS.LABEL'
                  )
                }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.advancedCardRadius"
                  :options="advancedCardRadiusOptions"
                  :placeholder="
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.ADVANCED_CARD_RADIUS.PLACEHOLDER'
                    )
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{
                  t(
                    'HELP_CENTER.PORTAL_SETTINGS.FORM.ADVANCED_SHADOW_STYLE.LABEL'
                  )
                }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.advancedShadowStyle"
                  :options="advancedShadowStyleOptions"
                  :placeholder="
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.ADVANCED_SHADOW_STYLE.PLACEHOLDER'
                    )
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.HEADER_STYLE.LABEL') }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.headerStyle"
                  :options="headerStyleOptions"
                  :placeholder="
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.HEADER_STYLE.PLACEHOLDER'
                    )
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
          </div>
        </div>
        <div class="flex justify-end w-full gap-2">
          <Button
            :label="t('HELP_CENTER.PORTAL_SETTINGS.FORM.SAVE_CHANGES')"
            :disabled="!hasChanges || isUpdatingPortal || v$.$invalid"
            :is-loading="isUpdatingPortal"
            @click="handleUpdatePortal"
          />
        </div>
      </div>
      <div
        v-show="activeSettingsTab === 'designer'"
        class="flex flex-col w-full gap-4"
      >
        <div class="rounded-xl border border-n-weak bg-n-solid-1 p-4">
          <p class="mb-4 text-sm text-n-slate-11">
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.DESIGNER_DESCRIPTION') }}
          </p>
          <div class="mb-5 space-y-2">
            <p class="text-sm font-medium text-n-slate-12">
              {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.DESIGNER_PRESET.LABEL') }}
            </p>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="option in designerPresetOptions"
                :key="option.value"
                type="button"
                class="inline-flex items-center rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors"
                :class="
                  selectedDesignerPreset === option.value
                    ? 'border-n-brand bg-n-brand/10 text-n-brand'
                    : 'border-n-weak bg-n-solid-1 text-n-slate-11 hover:bg-n-alpha-2'
                "
                @click="applyDesignerPreset(option.value)"
              >
                {{ option.label }}
              </button>
            </div>
          </div>
          <div class="space-y-4">
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_STYLE.LABEL') }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.heroStyle"
                  :options="heroStyleOptions"
                  :placeholder="
                    t('HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_STYLE.PLACEHOLDER')
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{
                  t('HELP_CENTER.PORTAL_SETTINGS.FORM.CATEGORY_COLUMNS.LABEL')
                }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.categoryColumns"
                  :options="categoryColumnsOptions"
                  :placeholder="
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.CATEGORY_COLUMNS.PLACEHOLDER'
                    )
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
            <div
              class="grid items-start justify-between w-full gap-2 md:grid-cols-[180px,minmax(0,1fr)]"
            >
              <label
                class="text-sm font-medium whitespace-nowrap py-2.5 text-n-slate-12"
              >
                {{
                  t('HELP_CENTER.PORTAL_SETTINGS.FORM.ARTICLE_LINK_STYLE.LABEL')
                }}
              </label>
              <div class="w-full max-w-[320px]">
                <ComboBox
                  v-model="state.articleLinkStyle"
                  :options="articleLinkStyleOptions"
                  :placeholder="
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.ARTICLE_LINK_STYLE.PLACEHOLDER'
                    )
                  "
                  class="[&>div>button:not(.focused)]:!outline-n-weak"
                />
              </div>
            </div>
          </div>
        </div>
        <div class="flex justify-end w-full gap-2">
          <Button
            :label="t('HELP_CENTER.PORTAL_SETTINGS.FORM.SAVE_CHANGES')"
            :disabled="!hasChanges || isUpdatingPortal || v$.$invalid"
            :is-loading="isUpdatingPortal"
            @click="handleUpdatePortal"
          />
        </div>
      </div>
      <div class="hidden xl:block xl:sticky xl:top-4">
        <div class="flex flex-col gap-3">
          <p class="text-sm font-medium text-n-slate-12">
            {{ t('HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.LABEL') }}
          </p>
          <div class="rounded-xl border border-n-weak bg-n-alpha-2 p-3">
            <div
              class="mx-auto rounded-xl border border-n-weak bg-n-solid-1"
              :class="[
                previewWidthClass,
                previewTypographyClass,
                previewDensityClasses.cardPadding,
                previewTextAlignClass,
              ]"
            >
              <div class="mb-2">
                <h4 class="text-base font-semibold text-n-slate-12">
                  {{
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.HERO_TITLE_SAMPLE'
                    )
                  }}
                </h4>
                <p class="text-sm text-n-slate-11">
                  {{
                    t(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.HERO_SUBTITLE_SAMPLE'
                    )
                  }}
                </p>
              </div>
              <div class="space-y-2">
                <div
                  class="px-3"
                  :class="[
                    previewDensityClasses.itemPadding,
                    previewCardStyleClass,
                    state.textAlign === 'center' ? 'text-center' : 'text-left',
                  ]"
                >
                  <p class="text-sm font-medium text-n-slate-12">
                    {{
                      t(
                        'HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.CARD_TITLE_SAMPLE'
                      )
                    }}
                  </p>
                  <p class="text-xs text-n-slate-11">
                    {{
                      t(
                        'HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.CARD_TEXT_SAMPLE'
                      )
                    }}
                  </p>
                </div>
              </div>
            </div>
            <div class="grid grid-cols-1 gap-2 mt-3">
              <div class="rounded-lg border border-n-weak bg-n-solid-1 p-2">
                <p class="text-xs font-medium text-n-slate-12">
                  {{
                    t('HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.HERO_COLORS')
                  }}
                </p>
                <p class="mt-1 text-xs text-n-slate-11">
                  {{
                    colorPreviewLabel(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_BG_COLOR.LABEL',
                      state.heroBgColor
                    )
                  }}
                </p>
                <p class="text-xs text-n-slate-11">
                  {{
                    colorPreviewLabel(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_TITLE_COLOR.LABEL',
                      state.heroTitleColor
                    )
                  }}
                </p>
                <p class="text-xs text-n-slate-11">
                  {{
                    colorPreviewLabel(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.HERO_SUBTITLE_COLOR.LABEL',
                      state.heroSubtitleColor
                    )
                  }}
                </p>
              </div>
              <div class="rounded-lg border border-n-weak bg-n-solid-1 p-2">
                <p class="text-xs font-medium text-n-slate-12">
                  {{
                    t('HELP_CENTER.PORTAL_SETTINGS.FORM.PREVIEW.CARD_COLORS')
                  }}
                </p>
                <p class="mt-1 text-xs text-n-slate-11">
                  {{
                    colorPreviewLabel(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_BG_COLOR.LABEL',
                      state.cardBgColor
                    )
                  }}
                </p>
                <p class="text-xs text-n-slate-11">
                  {{
                    colorPreviewLabel(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_BORDER_COLOR.LABEL',
                      state.cardBorderColor
                    )
                  }}
                </p>
                <p class="text-xs text-n-slate-11">
                  {{
                    colorPreviewLabel(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_TITLE_COLOR.LABEL',
                      state.cardTitleColor
                    )
                  }}
                </p>
                <p class="text-xs text-n-slate-11">
                  {{
                    colorPreviewLabel(
                      'HELP_CENTER.PORTAL_SETTINGS.FORM.CARD_TEXT_COLOR.LABEL',
                      state.cardTextColor
                    )
                  }}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
